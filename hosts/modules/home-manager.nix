{config, pkgs, inputs, lib, ...}:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [inputs.noctalia.homeModules.default];
    backupFileExtension = "bkup-home-manager-${toString inputs.self.lastModifiedDate }";
  };
}
