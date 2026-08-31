{
  config,
  pkgs,
  ...
}: let
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
    recommendedServices.enable = true;
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

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "noctalia msg session lock";
      }
      {
        timeout = 600;
        command = "${idleSuspend}";
      }
    ];
    beforeSleep = ["noctalia msg session lock"];
  };

  programs.niri.settings = {
    input = {
      keyboard.xkb.layout = config.var.keyboardLayout;
      touchpad.tap = true;
    };

    # Points noctalia's lock screen at the "noctalia" PAM service declared
    # in hosts/modules/yubikey.nix (u2fAuth + password fallback), instead of
    # whatever Quickshell's own default PAM service is.
    environment.NOCTALIA_PAM_SERVICE = "noctalia";

    # TODO: run `niri msg outputs` on each host once it boots into niri and
    # add the real connector name(s) here (ganymede was a 5120x2160@120
    # ultrawide under Hyprland's blanket monitor rule; niri configures
    # outputs per-connector, there's no "match any monitor" wildcard).
    # outputs."DP-1" = {
    #   mode = { width = 5120; height = 2160; refresh = 120.0; };
    #   scale = 1.0;
    # };

    layout = {
      gaps = 6;
      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#89b4fa";
        inactive.color = "#45475a";
      };
      preset-column-widths = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];
    };

    prefer-no-csd = true;

    spawn-at-startup = [
      {argv = ["noctalia"];}
      {argv = ["wl-paste" "--type" "text" "--watch" "cliphist" "store"];}
      {argv = ["wl-paste" "--type" "image" "--watch" "cliphist" "store"];}
    ];

    binds = {
      "Mod+T".action.spawn = "alacritty";
      "Mod+E".action.spawn = "nautilus";

      # No dedicated browser keybind: ganymede and io have different default
      # browsers (firefox vs vivaldi) -- use the noctalia launcher (Mod+R).

      # Noctalia owns the launcher/control-center/session/wallpaper UI now;
      # Mod+R and Mod+W keep their old hyprland-era muscle memory, Mod+S is
      # repurposed since hyprland's master-layout "swapwithmaster" has no
      # niri equivalent.
      "Mod+R".action.spawn = ["noctalia" "msg" "panel-toggle" "launcher"];
      "Mod+S".action.spawn = ["noctalia" "msg" "panel-toggle" "control-center"];
      "Mod+X".action.spawn = ["noctalia" "msg" "panel-toggle" "session"];
      "Mod+W".action.spawn = ["noctalia" "msg" "panel-toggle" "wallpaper"];
      "Mod+L".action.spawn = ["noctalia" "msg" "session" "lock"];

      "Mod+Q".action.close-window = [];
      "Mod+F".action.fullscreen-window = [];
      "Mod+Space".action.toggle-window-floating = [];

      "Mod+Left".action.focus-column-left = [];
      "Mod+Right".action.focus-column-right = [];
      "Mod+Up".action.focus-window-up = [];
      "Mod+Down".action.focus-window-down = [];

      "Mod+Shift+Left".action.move-column-left = [];
      "Mod+Shift+Right".action.move-column-right = [];
      "Mod+Shift+Up".action.move-window-up = [];
      "Mod+Shift+Down".action.move-window-down = [];

      "Mod+WheelScrollDown".action.focus-workspace-down = [];
      "Mod+WheelScrollUp".action.focus-workspace-up = [];

      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;
      "Mod+Shift+6".action.move-column-to-workspace = 6;
      "Mod+Shift+7".action.move-column-to-workspace = 7;
      "Mod+Shift+8".action.move-column-to-workspace = 8;
      "Mod+Shift+9".action.move-column-to-workspace = 9;

      "Print".action.spawn = ["noctalia" "msg" "screenshot-region"];
      "Shift+Print".action.spawn = ["noctalia" "msg" "screenshot-fullscreen"];
      "Alt+Print".action.spawn = ["noctalia" "msg" "screenshot-fullscreen" "pick"];

      "XF86AudioRaiseVolume".action.spawn = ["noctalia" "msg" "volume-up"];
      "XF86AudioLowerVolume".action.spawn = ["noctalia" "msg" "volume-down"];
      "XF86AudioMute".action.spawn = ["noctalia" "msg" "volume-mute"];
      "XF86MonBrightnessUp".action.spawn = ["noctalia" "msg" "brightness-up"];
      "XF86MonBrightnessDown".action.spawn = ["noctalia" "msg" "brightness-down"];

      "Mod+Shift+E".action.quit.skip-confirmation = true;
    };
  };
}
