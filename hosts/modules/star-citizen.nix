{...}: {
  # Star Citizen via nix-citizen (github:LovingMelody/nix-citizen), wired in
  # through flake.nix's nixosModules import. Disabled by default -- flip to
  # true when you actually want it installed. See the upstream README for
  # the rest of the programs.rsi-launcher.* options (wine/umu/gamescope
  # selection, EAC, udev rules for joysticks, etc).
  programs.rsi-launcher.enable = false;
}
