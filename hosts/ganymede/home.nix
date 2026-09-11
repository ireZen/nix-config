{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./variables.nix

    # Programs
    ../../home/programs/btop
    ../../home/programs/alacritty
    ../../home/programs/git
    ../../home/programs/discord
    ../../home/programs/games
    ../../home/programs/starship

    # Scripts
    ../../home/scripts # All scripts

    # System (Desktop environment like stuff)
    ../../home/system/zathura

    # niri + noctalia own the compositor/shell surface (bar, notifications,
    # launcher, wallpaper, lock, power menu) -- see home/system/niri.
    ../../home/system/niri
  ];

  home = {
    inherit (config.var) username;
    inherit (config.var) homeDirectory;

    packages = with pkgs; [
      proton-pass
      protonmail-desktop
      vlc
      brave
      sublime4

      # Dev
      nixd
      alejandra
      nixfmt-rfc-style

      # Utils
      zip
      unzip
      glow
      optipng
      pfetch
      pandoc
      swappy
      imv
      dconf
      rocketchat-desktop
    ];

    # Import wallpapers into $HOME/wallpapers
    file."Pictures/wallpapers" = {
      recursive = true;
      source = ../../home/wallpapers;
    };

    # Don't touch this
    stateVersion = "24.05";
  };
  programs.home-manager.enable = true;
}
