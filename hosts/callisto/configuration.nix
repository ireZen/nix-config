# callisto: Incus hypervisor replacing Proxmox.
# Runs the existing Home Assistant OS, Docker and CubeCoders AMP VMs, moved
# over as disk images (see docs/homelab-migration.md).
{...}: {
  imports = [
    ../modules/server/base.nix
    ../modules/server/incus-host.nix

    ./hardware-configuration.nix
    ./variables.nix
    ./network.nix
  ];

  # Fill these in from `qm config <vmid>` on the Proxmox host (CHANGE ME).
  # Each VM is created once with:  sudo incus-vm-import <name> <image>
  homelab.incusVMs = {
    haos = {
      cpus = 2;
      memory = "4GiB";
      diskSize = "32GiB"; # HAOS images are 32GiB
      mac = null; # e.g. "bc:24:11:aa:bb:cc" from net0 (keeps the DHCP reservation)
      legacyBios = false; # HAOS needs UEFI
      autostartPriority = 10; # start first
      shutdownTimeout = 300; # let the recorder database close cleanly
      usb = {
        # Zigbee / Z-Wave / Bluetooth sticks; IDs from `lsusb` on callisto.
        # zigbee = { vendorid = "10c4"; productid = "ea60"; };
      };
    };

    docker = {
      cpus = 4;
      memory = "8GiB";
      diskSize = "64GiB"; # at least the Proxmox disk size
      mac = null;
      legacyBios = true; # Proxmox default is SeaBIOS; false if `qm config` shows bios: ovmf
      autostartPriority = 5;
    };

    amp = {
      cpus = 4;
      memory = "8GiB";
      diskSize = "64GiB";
      mac = null;
      legacyBios = true;
    };
  };

  # Set this to whatever `nixos-generate-config` writes on the day you install,
  # then never change it.
  system.stateVersion = "26.11";
}
