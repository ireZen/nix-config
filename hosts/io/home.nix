{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./variables.nix

    # Programs
    ../../home/programs/btop
    ../../home/programs/vivaldi
    ../../home/programs/alacritty
    ../../home/programs/neofetch
    ../../home/programs/git
    ../../home/programs/vscode
    ../../home/programs/discord
    # ../../home/programs/games

    # Scripts
    ../../home/scripts # All scripts

    # System (Desktop environment like stuff)
    #../../home/system/gtk
    ../../home/system/zathura
    ../../home/system/udiskie

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
      pkgs.qt6Packages.qtstyleplugin-kvantum
      pkgs.qt6Packages.qt6ct
      pkgs.libsForQt5.qtstyleplugin-kvantum
      pkgs.libsForQt5.qt5ct
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
