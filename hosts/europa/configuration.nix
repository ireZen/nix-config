# europa: NAS replacing Unraid. Keeps the existing data disks and their data;
# mergerfs + SnapRAID take over from Unraid's array (see storage.nix and
# docs/homelab-migration.md).
{...}: {
  imports = [
    ../modules/server/base.nix

    ./hardware-configuration.nix
    ./variables.nix
    ./network.nix
    ./storage.nix
    ./shares.nix
  ];

  # Set this to whatever `nixos-generate-config` writes on the day you install,
  # then never change it.
  system.stateVersion = "26.11";
}
