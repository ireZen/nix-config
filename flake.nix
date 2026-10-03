{
  description = "angerZen's NixOS config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-citizen.url = "github:LovingMelody/nix-citizen";

    # Optional - updates underlying without waiting for nix-citizen to update
    nix-gaming.url = "github:fufexan/nix-gaming";
    nix-citizen.inputs.nix-gaming.follows = "nix-gaming";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Every host is a NixOS system with home-manager wired in the same way;
    # extraModules carries the flake-pinned modules a given host actually needs
    # (e.g. the niri/nix-citizen/noctalia NixOS modules) so their inputs are
    # honored instead of silently falling back to whatever nixpkgs bundles.
    mkHost = {
      hostname,
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules =
          [
            {nixpkgs.overlays = [inputs.nur.overlays.default];}

            inputs.home-manager.nixosModules.home-manager

            ./hosts/${hostname}/configuration.nix
          ]
          ++ extraModules;
      };
  in {
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations = {
      ganymede = mkHost {
        hostname = "ganymede";
        extraModules = [
          inputs.niri.nixosModules.niri
          inputs.noctalia.nixosModules.default
          inputs.noctalia-greeter.nixosModules.default
          inputs.nix-citizen.nixosModules
        ];
      };
      io = mkHost {
        hostname = "io";
        extraModules = [
          inputs.niri.nixosModules.niri
          inputs.noctalia.nixosModules.default
          inputs.noctalia-greeter.nixosModules.default
        ];
      };
    };
  };
}
