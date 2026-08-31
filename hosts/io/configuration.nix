{config, ...}: {
  imports = [
    ../modules/fonts.nix
    ../modules/noctalia-greeter.nix
    ../modules/auto-upgrade.nix
    ../modules/timezone.nix
    ../modules/usb.nix
    ../modules/systemd-boot-io.nix
    ../modules/users.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/nix.nix
    ../modules/network-manager.nix
    ../modules/home-manager.nix
    ../modules/utils.nix
    ../modules/yubikey.nix

    ./hardware-configuration.nix
    ./variables.nix
  ];

  home-manager.users."${config.var.username}" = import ./home.nix;

  # No nvidia.nix on io (integrated graphics) -- plasma6 previously pulled
  # this in as a side effect; niri needs it set explicitly.
  hardware.graphics.enable = true;

  # Installs niri, registers its session, and (per niri-flake) auto-forwards
  # programs.niri.settings to home-manager -- the actual config lives in
  # home/system/niri, imported via home.nix.
  programs.niri.enable = true;

  # Don't touch this
  system.stateVersion = "24.05";
}
