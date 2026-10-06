{
  pkgs,
  config,
  ...
}: {
  imports = [
    ./variables.nix

    # Programs
    ../../home/programs/btop
    ../../home/programs/kitty
    ../../home/programs/git
    ../../home/programs/discord
    ../../home/programs/games
    ../../home/programs/starship
    ../../home/programs/vscodium
    ../../home/programs/unity

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

      # Dev
      nixd
      alejandra
      nixfmt
      (with dotnetCorePackages; combinePackages [sdk_8_0 sdk_9_0])
      (python3.withPackages (ps: with ps; [pyyaml requests]))
      uv
      go
      android-tools

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
      dnsutils
    ];

    # Import wallpapers into $HOME/wallpapers
    file = {
      "Pictures/wallpapers" = {
        recursive = true;
        source = ../../home/wallpapers;
      };
      ".config/niri/".source = 
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/Projects/nix-config/home/system/niri";
    };
    
    sessionVariables = {
      DOTNET_ROOT = "${pkgs.dotnetCorePackages.sdk_8_0}";
      GOPATH = "$HOME/go";
    };

    # Don't touch this
    stateVersion = "24.05";
  };
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";   # or "https"
  };
  programs.home-manager.enable = true;
}
