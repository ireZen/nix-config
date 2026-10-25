# PLACEHOLDER so the flake evaluates before the machine is installed.
# During install, REPLACE this file with the one `nixos-generate-config`
# writes (/mnt/etc/nixos/hardware-configuration.nix). The labels below match
# the partitioning commands in docs/homelab-migration.md.
{modulesPath, ...}: {
  imports = [(modulesPath + "/installer/scan/not-detected.nix")];

  # Dell T440: the boot SSD sits behind the PERC (LSI MegaRAID SAS-3 3108).
  boot.initrd.availableKernelModules = ["ahci" "xhci_pci" "megaraid_sas" "usbhid" "usb_storage" "sd_mod"];
  boot.kernelModules = ["kvm-intel"];

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
