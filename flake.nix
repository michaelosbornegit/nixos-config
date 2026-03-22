{
  description = "Your new nix config";

  inputs = {
    # Primary package set: unstable by default on every host.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # Optional fallback set for explicit per-package pinning.
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";

    slippi.url = "github:lytedev/slippi-nix";
    slippi.inputs.nixpkgs.follows = "nixpkgs";

    beammp.url = "github:michaelosbornegit/beammp-nixos-flake";
    beammp.inputs.nixpkgs.follows = "nixpkgs";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Darwin
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nix-darwin,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    customAppsFor = system:
      import ./apps {
        pkgs = pkgsFor system;
      };
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages =
      forAllSystems (system:
        (import ./pkgs (pkgsFor system))
        {
          dolphin-emu = (pkgsFor system).dolphin-emu;
          kdiskmark = (pkgsFor system).kdiskmark;
          parsec-bin = (pkgsFor system).parsec-bin;
        });
    apps = forAllSystems (system:
      nixpkgs.lib.optionalAttrs (builtins.hasAttr system inputs.beammp.apps) {
        beammp = inputs.beammp.apps.${system}.beammp;
        beammp-doctor = inputs.beammp.apps.${system}.beammp-doctor;
        beammp-link = inputs.beammp.apps.${system}.beammp-link;
        beammp-proton = inputs.beammp.apps.${system}.beammp-proton;
      }
      // (customAppsFor system).apps);
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    nixosConfigurations = {
      stratus = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          user = "resonatortune";
          stateVersion = "25.05";
        };
        modules = [
          ./hosts/stratus/configuration.nix
        ];
      };
      vm = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          user = "resonatortune";
          stateVersion = "25.05";
        };
        modules = [
          ./hosts/vm/configuration.nix
        ];
      };
    };

    darwinConfigurations = {
      darwin = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs outputs;
          user = "mosborne";
          stateVersion = 6;
          homeStateVersion = "25.05";
        };
        modules = [
          ./hosts/darwin/configuration.nix
        ];
      };
    };
  };
}
