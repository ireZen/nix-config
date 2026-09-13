{config, pkgs, inputs, lib, ...}:
let
  SymLink = config.lib.mkOutOfStoreSymlink;
  # Option 1
  niri_path = "/home/angerzen/Config/nix-config/home/system/niri/";

  # Option 2
  # cfg_path_2 = "${config.home.homeDirectory}/nixos_config/configs";

  # Option 3
  #   inputs.self is from the root flake.nix
  #   According to https://nix.dev/manual/nix/2.28/command-ref/new-cli/nix3-flake#flake-inputs
  #   > The special input named self refers to the outputs and source tree of *this* flake.
  # cfg_path_3 = "${inputs.self}/configs";

  ### cfg_path_1, cfg_path_2 are equal
  ###  You will be able to edit files (both .cfg and example_) and see result immediately
  ###  
  ### cfg_path_3 is different
  ###  you will need to rebuild the flake to see result after editing 3.cfg (example_3 is read only)
in
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [inputs.noctalia.homeModules.default];
    backupFileExtension = "bkup-home-manager-${toString inputs.self.lastModifiedDate }";
    file = {
      ".config/niri/config.kdl".source = SymLink "$niri_path/config.kdl";
      ".config/niri/autostart.kdl".source = SymLink "$niri_path/autostart.kdl";
      ".config/niri/animation.kdl".source = SymLink "$niri_path/animation.kdl";
      ".config/niri/display.kdl".source = SymLink "$niri_path/display.kdl";
      ".config/niri/input.kdl".source = SymLink "$niri_path/input.kdl";
      ".config/niri/keybinds.kdl".source = SymLink "$niri_path/keybinds.kdl";
      ".config/niri/layout.kdl".source = SymLink "$niri_path/layout.kdl";
      ".config/niri/misc.kdl".source = SymLink "$niri_path/misc.kdl";
      ".config/niri/rules.kdl".source = SymLink "$niri_path/rules.kdl";
    };
  };
}
