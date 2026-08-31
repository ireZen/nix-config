{pkgs, config, ...}: {
  imports = [
    ../modules/fonts.nix
    ../modules/nvidia.nix
    ../modules/noctalia-greeter.nix
    ../modules/auto-upgrade.nix
    ../modules/timezone.nix
    ../modules/usb.nix
    ../modules/systemd-boot.nix
    ../modules/users.nix
    ../modules/audio.nix
    ../modules/bluetooth.nix
    ../modules/nix.nix
    ../modules/network-manager.nix
    ../modules/home-manager.nix
    ../modules/utils.nix
    ../modules/steam.nix
    ../modules/star-citizen.nix
    ../modules/yubikey.nix

    ./hardware-configuration.nix
    ./variables.nix
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  home-manager.users."${config.var.username}" = import ./home.nix;

  # Installs niri, registers its session, and (per niri-flake) auto-forwards
  # programs.niri.settings to home-manager -- the actual config lives in
  # home/system/niri, imported via home.nix.
  programs.niri.enable = true;

  programs.coolercontrol = {
    enable = true;
    nvidiaSupport = true;
  };

  # Don't touch this
  system.stateVersion = "24.05";
}
