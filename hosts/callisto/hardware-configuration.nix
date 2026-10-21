# PLACEHOLDER so the flake evaluates before the machine is installed.
# During install, REPLACE this file with the one `nixos-generate-config`
# writes (/mnt/etc/nixos/hardware-configuration.nix). The labels below match
# the partitioning commands in docs/homelab-migration.md.
{modulesPath, ...}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel" "kvm-amd"];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = ["fmask=0077" "dmask=0077"];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
}
