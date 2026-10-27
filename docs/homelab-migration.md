# Homelab migration: Proxmox → NixOS (callisto), Unraid → NixOS (europa)

This runbook goes with the `callisto` and `europa` hosts in this flake.

- **Part A** replaces Proxmox. The Home Assistant, Docker and AMP VMs are copied from their Proxmox disks into Incus VMs on the same ZFS pool.
- **Part B** replaces Unraid. The data disks are kept untouched, mergerfs pools them at `/mnt/user`, and SnapRAID takes over parity.

The two parts are independent. Do Part A first, so the hypervisor is settled before the NAS changes. Every value you still need to fill in is marked `CHANGE ME` in the config.

---

## 0. Before anything

- [ ] **Home Assistant:** Settings → System → Backups → create a full backup, then download it to your desktop.
- [ ] **Unraid flash backup:** Main → Flash → *Flash Backup*. Keep the USB stick itself too; it is your rollback for Part B.
- [ ] **Unraid Main tab:** take a screenshot of it. You need each slot (Parity, Disk 1…N, Cache) with its **serial number**, size and filesystem.
- [ ] **Unraid shares:** write down every share name, whether it is on SMB and/or NFS, and which shares are cache-only (appdata, system, domains…).
- [ ] **Unraid network:** note its IP address. NixOS reuses it, so clients don't notice the change.
- [ ] **Unraid Docker/VMs:** if Unraid itself runs containers or VMs, note them. This plan does not carry them over.
- [ ] **Encryption:** if any Unraid disk shows `xfs-encrypted` or `btrfs-encrypted`, stop and plan LUKS unlocking first. The config assumes unencrypted disks.

---

## Part A: Proxmox → callisto

callisto is the Dell PowerEdge T440 that runs Proxmox today as `pve` (10.0.0.16). It runs [Incus](https://linuxcontainers.org/incus/) instead, and `hosts/callisto/` is already filled in from the Proxmox config export of 2026-10-25:

| | Proxmox | callisto |
|---|---|---|
| Boot disk | `sda`, Samsung PM863 480 GB, serial **S3BUNX0K804302**, LVM | the same disk, wiped and reinstalled |
| VM storage | ZFS pool `ZedPool` | the same pool, untouched; Incus VMs go in `ZedPool/incus` |
| Network | `vmbr0` on `nic0` (X710 port 1), 10.0.0.16/22 | `br0` on the same port, with the same IP and MAC |
| Home Assistant | VM 100: 2 vCPU, 4 GiB, OVMF, CH340 USB adapter | `haos`, with the same settings and the same MAC |
| AMP | VM 101: 16 vCPU, 32 GiB, SeaBIOS | `amp`, with the same settings and the same MAC |
| Docker | VM 102: 16 vCPU, 32 GiB, OVMF, Quadro P4000 passthrough | `docker`, with the same settings, the same MAC and the same GPU |

The VM disks never leave the machine. NixOS goes on the boot disk only. `ZedPool` is imported as it is, and `incus-vm-import` copies each Proxmox disk into a new Incus VM on the same pool. The Proxmox disks stay where they are until you delete them, so a rollback is always possible.

### A1. Prepare the Docker and AMP guests. This step is required.

Both guests run Arch Linux. Do the two steps below in each one while it still runs on Proxmox. Home Assistant OS needs no changes.

#### Network: match the card by MAC address

Incus lays out the virtual hardware differently from Proxmox, so each guest's network card gets a new name (for example `enp5s0` instead of `ens18`). A guest whose network config names `ens18` comes up with no network. Change it to match the card by MAC address instead:

- **Docker VM:** MAC `bc:24:11:33:84:06`
- **AMP VM:** MAC `bc:24:11:38:67:42`

First find out which network manager the guest uses:

```bash
systemctl list-unit-files --state=enabled | grep -e networkd -e NetworkManager -e dhcpcd -e netctl
grep -rl ens18 /etc/systemd/network /etc/NetworkManager /etc/netctl /etc/dhcpcd.conf 2>/dev/null
```

Then fix whichever one it is (the examples use the Docker VM's MAC):

- **systemd-networkd:** in the `/etc/systemd/network/*.network` file, replace `Name=ens18` in the `[Match]` section with:
  ```ini
  [Match]
  MACAddress=bc:24:11:33:84:06
  ```
  Then run `sudo networkctl reload` and check that `networkctl status` still shows the address.
- **NetworkManager:** `sudo nmcli connection modify "<connection>" connection.interface-name "" 802-3-ethernet.mac-address bc:24:11:33:84:06`
- **dhcpcd:** if `dhcpcd@ens18.service` is enabled, run `sudo systemctl enable --now dhcpcd.service && sudo systemctl disable dhcpcd@ens18.service`. Plain `dhcpcd.service` handles every interface. Also remove any `interface ens18` line from `/etc/dhcpcd.conf`.
- **netctl:** netctl profiles always name an interface, so move the guest to systemd-networkd. Create `/etc/systemd/network/20-lan.network` with the `[Match]` section above plus `[Network]` and `DHCP=yes` (or the static `Address=`/`Gateway=`/`DNS=` from the netctl profile). Then run `sudo netctl disable <profile> && sudo systemctl enable --now systemd-networkd systemd-resolved`.

#### Initramfs: include the virtio drivers

mkinitcpio's `autodetect` hook only puts the drivers the guest uses right now into the initramfs. If the Proxmox disk controller is something other than the virtio-scsi controller that Incus uses, the guest can't find its root disk after the move. Add the drivers explicitly. In `/etc/mkinitcpio.conf`:

```bash
MODULES=(virtio_pci virtio_scsi virtio_blk)
```

Keep any modules already on that line (`nvidia …` on the Docker VM, for example). Then run `sudo mkinitcpio -P`.

Don't run `pacman -Syu` in the guests between now and A7, so that nothing changes underneath the migration.

### A2. Save what lives only on the boot disk

Everything on `sda` is erased. On the Proxmox host:

```bash
ls /var/lib/vz/template/iso /var/lib/vz/dump   # ISOs and backups on "local"; copy off anything you want to keep
mkdir -p /root/pve-backup && cp /etc/pve/qemu-server/*.conf /root/pve-backup/
```

Copy `/root/pve-backup/` to your desktop with `scp -r root@10.0.0.16:/root/pve-backup .`. Those three files are your Proxmox rollback.

### A3. Stop the VMs and release the pool

```bash
qm shutdown 100 && qm shutdown 101 && qm shutdown 102
qm list                     # all three "stopped"
zpool export ZedPool        # hand the pool over cleanly
```

Exporting means NixOS can import the pool on first boot without forcing it.

### A4. Fill in what's left

- `hosts/callisto/variables.nix`: your SSH public key(s).

Everything else in `hosts/callisto/` already matches the export. Commit and push.

### A5. Install NixOS on the boot disk only

Three of the ZFS disks are the **same model** as the boot disk (Samsung MZ7KM480). Use the boot disk's serial number, never `/dev/sdX`.

Boot the NixOS minimal ISO, then confirm that this disk is the one holding Proxmox's LVM:

```bash
lsblk -o NAME,SIZE,FSTYPE,MODEL,SERIAL     # the S3BUNX0K804302 disk shows LVM2_member partitions
DISK=/dev/disk/by-id/ata-MZ7KM480HMHQ0D3_S3BUNX0K804302
ls -l $DISK                                # if this doesn't exist, check `ls /dev/disk/by-id | grep S3BUNX0K804302`
```

Then wipe and partition that disk:

```bash
vgchange -an pve                           # release Proxmox's LVM so the disk can be wiped
wipefs -a ${DISK}-part3 ${DISK}-part2 $DISK
parted -s $DISK -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB set 1 esp on \
  mkpart root ext4 1GiB 100%
udevadm settle
mkfs.fat -F 32 -n BOOT ${DISK}-part1
mkfs.ext4 -L nixos ${DISK}-part2
mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/BOOT /mnt/boot

nixos-generate-config --root /mnt
nix-shell -p git --run 'git clone https://github.com/ireZen/nix-config /mnt/root/nix-config'
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/root/nix-config/hosts/callisto/
grep stateVersion /mnt/etc/nixos/configuration.nix  # copy this value into hosts/callisto/configuration.nix

cd /mnt/root/nix-config && git add -A
nixos-install --flake .#callisto        # asks for a root password
nixos-enter --root /mnt -c 'passwd angerzen'
reboot
```

Afterwards, commit the real `hardware-configuration.nix` from the server and push it.

### A6. First boot checks

SSH in with `ssh angerzen@10.0.0.16`, then run:

```bash
zpool status ZedPool                         # ONLINE, all 10 disks
zfs list -r ZedPool                          # old vm-10x disks, plus a new empty ZedPool/incus
ip -br addr show br0                         # 10.0.0.16/22
lspci -nnk -s af:00                          # "Kernel driver in use: vfio-pci" on both functions
incus storage list                           # "default", zfs, ZedPool/incus
```

If `ZedPool` isn't imported (because the export in A3 was skipped), import it once by hand with `sudo zpool import -f ZedPool`, then run `sudo systemctl restart incus`.

### A7. Import the VMs

Each command creates the VM with the settings from `hosts/callisto/configuration.nix`, then copies the Proxmox disk into it. The copy stays on the same pool, so it takes minutes, not hours.

```bash
sudo incus-vm-import haos   /dev/zvol/ZedPool/vm-100-disk-0
sudo incus-vm-import amp    /dev/zvol/ZedPool/vm-101-disk-0
sudo incus-vm-import docker /dev/zvol/ZedPool/vm-102-disk-1   # disk-1! disk-0 is only Proxmox's EFI vars

incus start haos docker amp
incus list
```

`incus-vm-import` refuses to touch a VM that already exists, and it stops if the old disk is bigger than the new one.

From now on, the VMs start automatically with the host (Home Assistant first) and shut down cleanly with it. To watch one boot, run `incus console haos --type=vga`, or use the web UI.

**Web UI:** open `https://10.0.0.16:8443` and accept the self-signed certificate. The UI walks you through creating a browser certificate; trust it on callisto with `incus config trust add-certificate <file>`.

**Changing a VM later:** rebuilding doesn't modify VMs that already exist. Change them with `incus config set <vm> limits.memory=8GiB` (or in the UI), then update `homelab.incusVMs` to match, so the repo records what's running.

### A8. Check

- Home Assistant opens at its old address, and the device on the CH340 adapter works (Settings → System → Hardware).
- The Docker VM has its old IP, `nvidia-smi` inside it shows the Quadro P4000, and its containers are up.
- AMP's panel works and players can join.

**Troubleshooting**

- *No network in a guest:* the guest still matches `ens18`. Fix it as in A1 from `incus console <vm>`. `ip -br link` shows the new name of the card.
- *Docker VM drops to the UEFI shell:* its boot entry lived in Proxmox's EFI vars disk (`vm-102-disk-0`). Arch doesn't use shim, so start the bootloader directly. In the shell, run `FS0:\EFI\GRUB\grubx64.efi` for GRUB or `FS0:\EFI\systemd\systemd-bootx64.efi` for systemd-boot (`ls FS0:\EFI` shows which one is there). Once it has booted, install the bootloader to the fallback path `\EFI\BOOT\BOOTX64.EFI` so it no longer needs that entry:
  - GRUB: `sudo grub-install --target=x86_64-efi --efi-directory=/boot --removable`. Use `/efi` or `/boot/efi` instead if that's where the ESP is mounted (`findmnt -t vfat`).
  - systemd-boot: `sudo bootctl install`. It already writes the fallback path.
- *Arch guest stops at "waiting for root device" or drops to an emergency shell:* the initramfs is missing the virtio drivers (see A1). Pick the `fallback` initramfs entry in the boot menu, which has every driver. Then add the modules to `/etc/mkinitcpio.conf` and run `sudo mkinitcpio -P`.
- *AMP doesn't boot:* check that it uses legacy BIOS with `incus config get amp security.csm` (should be `true`).
- *Docker VM won't start because of the GPU:* run `incus info docker --show-log` and `sudo dmesg | grep -i -e vfio -e iommu`. Both card functions must use `vfio-pci` (see A6).
- *Want to redo an import:* `incus delete <vm>`, then run `incus-vm-import` again. The Proxmox disk is never modified.

### A9. Clean up, once everything has run well for a while

```bash
sudo zfs destroy ZedPool/vm-100-disk-0
sudo zfs destroy ZedPool/vm-101-disk-0
sudo zfs destroy ZedPool/vm-102-disk-0
sudo zfs destroy ZedPool/vm-102-disk-1
```

Until you run these, a rollback is possible: reinstall Proxmox on the boot disk, run `zpool import -f ZedPool`, copy the saved `.conf` files back into `/etc/pve/qemu-server/`, and start the VMs.

---

## Part B: Unraid → europa

### How the new layout matches Unraid

| Unraid | NixOS |
|---|---|
| `/mnt/disk1…N` (XFS) | the same disks, mounted as-is at `/mnt/disk1…N` |
| `/mnt/user` | mergerfs pool of the data disks at `/mnt/user` |
| Parity (real-time) | SnapRAID parity, synced nightly at 03:00 |
| Cache pool | mounted at `/mnt/cache`, outside the pool |
| Shares owned `nobody:users` (99:100) | user `share` with uid 99 and group `users`, so ownership is unchanged |
| SMB / NFS shares | the same names and paths, served by Samba / nfsd |

**What changes:** SnapRAID protects data **as of the last sync**. Files written since the last sync are not protected, and a large accidental delete followed by a sync makes it permanent. Run `snapraid diff` if something looks off before the nightly sync runs.

### B0. What you need

- **A new boot drive** (a small SSD; NVMe or SATA). NixOS cannot boot from the array disks, and booting from the Unraid USB stick is a bad idea.
- **A parity disk at least as large as your largest data disk.** The parity disk gets reformatted. SnapRAID's parity file is slightly larger than the data on the fullest disk, so if the parity disk is exactly the same size as a nearly-full data disk, the sync can run out of room. Leave some free space on the fullest data disk.

### B1. Prepare Unraid

1. Run the mover so "cache: yes" shares are fully on the array: Main → *Move*. Wait for it to finish.
2. Stop Unraid's Docker and VM services, if you use them.
3. **Stop the array, then shut down from the GUI.** A clean shutdown matters: after an unclean one, XFS replays its log on the next mount and writes to the disk even when you mount it read-only.

### B2. Install the boot drive and boot the NixOS ISO

Leave the Unraid USB stick out and keep it safe. Then match the disks to your screenshot:

```bash
lsblk -o NAME,SIZE,SERIAL,FSTYPE,LABEL,UUID
```

Do not run any partitioning tool on the data disks. To confirm one, mount it read-only and look:

```bash
mount -o ro /dev/sdb1 /mnt && ls /mnt && umount /mnt
```

### B3. Reformat the parity disk(s)

Do this only after triple-checking the serial number against the screenshot:

```bash
P=/dev/sdX                                   # CHANGE ME: the PARITY disk
wipefs -a $P
parted -s $P -- mklabel gpt mkpart parity1 ext4 1MiB 100%
mkfs.ext4 -m 0 -T largefile4 -L parity1 ${P}1  # -m 0 / largefile4: maximum space for the parity file
```

For dual parity, repeat with `parity2`.

### B4. Fill in the config

- `hosts/europa/storage.nix`: one `diskN` entry per data disk, with the UUID of its **partition** (`/dev/sdX1`) and its filesystem. Fill in the parity UUIDs (new, from B3) and the cache pool UUID (or set `cache = null`). Leave `dataReadOnly = true`.
- `hosts/europa/shares.nix`: your share names, NFS shares, and allowed networks.
- `hosts/europa/network.nix`: NIC name and **Unraid's old IP address**.
- `hosts/europa/variables.nix`: SSH keys.

### B5. Install

Install as in A5, but on the **new boot SSD**, with `hosts/europa/` and `nixos-install --flake .#europa`.

### B6. First boot: everything read-only

```bash
findmnt -t xfs,btrfs,ext4,fuse.mergerfs     # all disks plus /mnt/user mounted?
df -h /mnt/disk* /mnt/user
ls -ln /mnt/user/media | head                # owner should show 99 100
sudo tmux new -s sync 'snapraid sync'        # builds parity from scratch; hours to days
```

Detach from tmux with `Ctrl-b d` and reattach with `sudo tmux attach -t sync`. When the sync is done, `sudo snapraid status` should report no errors.

### B7. Go read-write

1. Set `dataReadOnly = false;` in `storage.nix`, commit, then run `sudo nixos-rebuild switch --flake .#europa`.
2. Set Samba passwords: `sudo smbpasswd -a angerzen`, and do the same for anyone else who used Unraid's SMB.
3. From the Docker VM, remount its NFS/SMB shares (`sudo mount -a`, or reboot it). The IP and paths are unchanged.
4. Run `sudo snapraid sync` once more. This also writes content files to the data disks.

### B8. Rollback

As long as you haven't written to the data disks, you can go back to Unraid: put the USB stick back and boot. Unraid will see the parity disk as invalid. Use *Tools → New Config*, keeping all assignments, start the array, and let it **rebuild parity**. Your data disks are untouched. Rollback still works after going read-write, but it always needs that parity rebuild.

---

## After both parts

- Nothing sends alerts yet: no SMART, SnapRAID-sync or VM-down notifications. The article's ntfy approach is a good next step.
- If you want deploys from git as in the article, add [comin](https://github.com/nlewo/comin) to both servers.
