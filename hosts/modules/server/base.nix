# Shared baseline for headless homelab servers (callisto, europa).
# Desktop-only modules (utils.nix, network-manager.nix, systemd-boot.nix, ...)
# are deliberately NOT imported here.
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../nix.nix
    ../timezone.nix
    ../users.nix
  ];

  # --- Boot -------------------------------------------------------------
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 10;
    };
    loader.efi.canTouchEfiVariables = true;
    tmp.cleanOnBoot = true;
    # Default (LTS-tracking) kernel on servers, not zen.
  };

  # timezone.nix sets this for dual-boot desktops; servers keep the RTC in UTC.
  time.hardwareClockInLocalTime = lib.mkForce false;

  # --- Networking ---------------------------------------------------------
  # Each host declares its interfaces in its own network.nix (systemd-networkd).
  networking = {
    hostName = config.var.hostname;
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = true;
  };
  systemd.network.enable = true;
  services.resolved.enable = true;

  # --- Remote access ------------------------------------------------------
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      # Stays on until you add a key to var.sshAuthorizedKeys, then turns off.
      PasswordAuthentication = config.var.sshAuthorizedKeys == [];
      KbdInteractiveAuthentication = false;
    };
  };
  users.users.${config.var.username}.openssh.authorizedKeys.keys = config.var.sshAuthorizedKeys;

  # --- Housekeeping -------------------------------------------------------
  services.smartd.enable = true; # disk health monitoring
  services.fstrim.enable = true;
  services.fwupd.enable = true;

  console.keyMap = config.var.keyboardLayout;

  documentation = {
    doc.enable = false;
    dev.enable = false;
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    btop
    tmux
    ncdu
    lsof
    pciutils
    usbutils
    smartmontools
    hdparm
    lm_sensors
    rsync
  ];
}
