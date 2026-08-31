{inputs, ...}: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs;};
    # Modules that should apply to every home-manager user on this host,
    # regardless of whether they're pulled in via home.nix. Makes
    # programs.noctalia available to home/system/niri even though it isn't
    # imported by every host (io stays plain KDE).
    sharedModules = [inputs.noctalia.homeModules.default];
    # Fixed suffix so home-manager backs up conflicting dotfiles instead of
    # refusing to activate. A timestamp here (as before) forces a fresh
    # eval-time build on every rebuild just to name the suffix, which is
    # both slow and pointless since only one suffix is ever live at a time.
    backupFileExtension = "hm-backup";
  };
}
