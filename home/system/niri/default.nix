{
  config,
  pkgs,
  inputs,
  ...
}:
let
  # playerctl guard so idle-suspend doesn't kill audio/video mid-playback;
  # ported from the old hypridle suspend script. Calls `noctalia` via PATH
  # rather than pkgs.noctalia, since noctalia isn't guaranteed to be
  # exposed as a plain nixpkgs attribute outside its own overlay.
  idleSuspend = pkgs.writeShellScript "idle-suspend" ''
    ${pkgs.playerctl}/bin/playerctl -a status | ${pkgs.ripgrep}/bin/rg Playing -q
    if [ $? == 1 ]; then
      noctalia msg session suspend
    fi
  '';
in {
  # programs.niri.enable lives at the NixOS level (each host's configuration.nix);
  # niri-flake auto-forwards programs.niri.settings here since home-manager is present.
  programs.noctalia = {
    enable = true;
    # recommendedServices.enable = true;
  };

  # Generic Wayland-compositor utilities (not niri-specific, just no longer
  # pulled in implicitly by a DE now that hyprland/plasma are gone).
  home.packages = with pkgs; [
    cliphist
    nautilus
    pamixer
    pavucontrol
    wlr-randr
    wl-clipboard
    brightnessctl
  ];

  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
  };

}
