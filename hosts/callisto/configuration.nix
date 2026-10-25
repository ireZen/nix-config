# callisto: Incus hypervisor replacing Proxmox (Dell PowerEdge T440,
# formerly "pve" at 10.0.0.16). Runs the existing Home Assistant OS, Docker
# and CubeCoders AMP VMs, copied from their Proxmox disks on ZedPool
# (see docs/homelab-migration.md).
{...}: {
  imports = [
    ../modules/server/base.nix
    ../modules/server/incus-host.nix

    ./hardware-configuration.nix
    ./variables.nix
    ./network.nix
    ./storage.nix
    ./gpu-passthrough.nix
  ];

  # VMs live on the existing ZFS pool, next to the old Proxmox disks.
  homelab.incusStorage = {
    driver = "zfs";
    source = "ZedPool/incus";
  };

  # Settings taken from `qm config` on Proxmox (2026-10-25). Each VM is
  # created once from its old disk with:
  #   sudo incus-vm-import <name> /dev/zvol/ZedPool/vm-<id>-disk-<n>
  homelab.incusVMs = {
    # Proxmox VM 100 "HomeAssistant": OVMF, q35, ZedPool:vm-100-disk-0
    haos = {
      cpus = 2;
      memory = "4GiB";
      diskSize = "32GiB";
      mac = "bc:24:11:d3:64:55";
      legacyBios = false; # HAOS needs UEFI
      autostartPriority = 10; # start first
      shutdownTimeout = 300; # let the recorder database close cleanly
      usb = {
        # QinHeng CH340 USB-serial adapter (usb0: host=1a86:7523)
        ch340 = {
          vendorid = "1a86";
          productid = "7523";
        };
      };
    };

    # Proxmox VM 102 "DockerVM": OVMF, q35, ZedPool:vm-102-disk-1,
    # with the Quadro P4000 passed through (hostpci0: 0000:af:00).
    docker = {
      cpus = 16; # 2 sockets x 8 cores
      memory = "32GiB";
      diskSize = "500GiB";
      mac = "bc:24:11:33:84:06";
      legacyBios = false;
      autostartPriority = 5;
      pci = {
        gpu = "0000:af:00.0";
        gpu-audio = "0000:af:00.1";
      };
    };

    # Proxmox VM 101 "AMP": SeaBIOS, i440fx, ZedPool:vm-101-disk-0
    amp = {
      cpus = 16; # 2 sockets x 8 cores
      memory = "32GiB";
      diskSize = "500GiB";
      mac = "bc:24:11:38:67:42";
      legacyBios = true;
    };
  };

  # Set this to whatever `nixos-generate-config` writes on the day you install,
  # then never change it.
  system.stateVersion = "26.11";
}
