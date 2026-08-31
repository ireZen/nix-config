{pkgs, ...}: {
  # Provides pamu2fcfg for enrolling keys; see the README note this repo's
  # summary points at for the one-time `pamu2fcfg > ~/.config/Yubico/u2f_keys`
  # step you have to run on the real machine with the key in hand.
  environment.systemPackages = [pkgs.pam_u2f];

  security.pam.u2f = {
    enable = true;
    # sufficient: try the YubiKey first, fall back to password if it's not
    # present or the touch times out -- keeps the account usable if the key
    # is lost, damaged, or left at home.
    control = "sufficient";
    settings.cue = true;
  };

  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.greetd.u2fAuth = true;
  # Matches NOCTALIA_PAM_SERVICE set in home/system/niri's niri environment
  # block. Quickshell/noctalia otherwise authenticates against whatever its
  # own default PAM service is, which this repo doesn't declare/control.
  security.pam.services.noctalia.u2fAuth = true;

  # Lock every session the instant the YubiKey is unplugged. Uses
  # ENV{ID_VENDOR_ID} rather than ATTR{idVendor}: sysfs attributes are gone
  # by the time a "remove" rule fires, but udev's cached ID_* properties
  # from when the device was added are still there. 1050 is Yubico's USB
  # vendor ID (covers all YubiKey models).
  services.udev.extraRules = ''
    ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="1050", RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"
  '';
}
