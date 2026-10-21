# Homelab migration: Proxmox → NixOS (callisto), Unraid → NixOS (europa)

This runbook goes with the `callisto` and `europa` hosts in this flake.

- **Part A** replaces Proxmox. The Home Assistant, Docker and AMP VMs move over as disk images.
- **Part B** replaces Unraid. The data disks are kept untouched, mergerfs pools them at `/mnt/user`, and SnapRAID takes over parity.

Do Part A first. Unraid stays untouched during Part A, so it can hold the VM images while the hypervisor is reinstalled. Every value you need to fill in is marked `CHANGE ME` in the config.

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

### A1. Record each VM's settings

On the Proxmox host, run this for each VM:

```bash
qm list
qm config <vmid>
```

Copy the following values into `hosts/callisto/vms/<name>.xml`:

| `qm config` line | XML |
|---|---|
| `memory: 4096` | `<memory unit='MiB'>4096</memory>` |
| `cores: 2` (× sockets) | `<vcpu>2</vcpu>` |
| `net0: virtio=BC:24:11:AA:BB:CC,bridge=vmbr0` | `<mac address='BC:24:11:AA:BB:CC'/>`, the same MAC, so DHCP reservations and IPs stay the same |
| `bios: ovmf` | `<os firmware='efi'>` (haos.xml already has it) |
| no `bios` line | SeaBIOS; leave docker.xml/amp.xml as they are |
| `machine: q35` | `machine='q35'`, and delete the NIC's `<address …/>` line |
| `usb0: host=10c4:ea60` | uncomment the `<hostdev>` block in haos.xml with those IDs |
| `scsi0: local-lvm:vm-101-disk-1,…` | the disk you export in A3 |

### A2. Prepare the Linux guests (Docker, AMP)

On each guest, run `ip -br link`. Proxmox guests usually call the NIC `ens18`. The Docker and AMP templates keep the NIC in the same PCI slot, so the name should not change. To be safe, make the guest match its network config by MAC instead of by name. On Ubuntu, in `/etc/netplan/*.yaml`:

```yaml
ethernets:
  lan:
    match:
      macaddress: bc:24:11:aa:bb:cc
    set-name: ens18
    dhcp4: true
```

Optionally install the guest agent (`apt install qemu-guest-agent`), which makes host shutdowns cleaner.

### A3. Export the disks

Shut each VM down cleanly, then copy its disk to Unraid as qcow2:

```bash
mkdir -p /mnt/nas && mount -t nfs <unraid-ip>:/mnt/user/backups /mnt/nas
qm shutdown <vmid>

pvesm path local-lvm:vm-<vmid>-disk-1          # prints /dev/pve/vm-... (or /dev/zvol/...)
qemu-img convert -p -O qcow2 "$(pvesm path local-lvm:vm-<vmid>-disk-1)" /mnt/nas/haos.qcow2
qemu-img check /mnt/nas/haos.qcow2
```

- Export only the main disk (`scsi0`, `virtio0` or `sata0`). Skip `efidisk0`; libvirt makes its own.
- Name the files `haos.qcow2`, `docker.qcow2` and `amp.qcow2`, to match the XML.
- If a VM has more than one data disk, export each one and add a `<disk>` block for it (`target dev='sdb'`, and so on).
- If you can, put a second copy somewhere other than Unraid. Until Part A is finished, these images are your only copy of the VMs.

### A4. Fill in the config

- `hosts/callisto/network.nix`: NIC name, plus the Proxmox host's current IP, gateway and DNS.
- `hosts/callisto/variables.nix`: your SSH public key(s).
- The VM XMLs, from A1.

Commit and push.

### A5. Install NixOS (this wipes the Proxmox boot disk)

Boot the NixOS minimal ISO. Identify the disk with `lsblk -o NAME,SIZE,MODEL,SERIAL`, then partition it:

```bash
DISK=/dev/nvme0n1          # CHANGE ME (triple-check)
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 1GiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n BOOT ${DISK}p1        # use ${DISK}1 for /dev/sdX
mkfs.ext4 -L nixos ${DISK}p2
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

If the old Proxmox box had a separate disk for VM storage, add a `fileSystems."/var/lib/libvirt/images"` entry for it instead of keeping the images on the root disk.

### A6. Bring the VMs back

```bash
sudo mkdir -p /mnt/nas && sudo mount -t nfs <unraid-ip>:/mnt/user/backups /mnt/nas
sudo rsync -avP /mnt/nas/{haos,docker,amp}.qcow2 /var/lib/libvirt/images/
sudo systemctl restart libvirt-define-guests   # defines and starts all three VMs
virsh -c qemu:///system list --all
```

To watch the VMs from your desktop, use `virt-manager -c qemu+ssh://angerzen@callisto/system`. You can also open a serial console on callisto with `virsh console docker`.

### A7. Check

- Home Assistant opens at its old IP, and its USB radios work (Settings → System → Hardware).
- The Docker VM has its IP, its NAS mounts work, and its containers are up.
- AMP's panel works and players can join.

**Troubleshooting**

- *No network in a guest:* the interface was renamed. Fix netplan as in A2 over `virsh console`.
- *A UEFI Linux guest drops to the firmware shell:* its boot entry was in Proxmox's EFI disk. In the shell, run `FS0:\EFI\ubuntu\shimx64.efi` (or `grubx64.efi`). Once the guest has booted, run `sudo grub-install --removable` (or reinstall shim) so it boots without that entry.

**Rollback:** reinstall Proxmox, then `qemu-img convert` the qcow2 files back into VM disks.

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
