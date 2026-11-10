{
  description = "Michael's NixOS and nix-darwin configurations";

  inputs = {
    # Primary package set: unstable by default on every host.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    slippi = {
      url = "github:lytedev/slippi-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    beammp = {
      url = "github:michaelosbornegit/beammp-nixos-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Claude Desktop Linux beta, packaged for Nix. Pinned to the audited
    # commit: the flake auto-bumps hourly with no review, so update deliberately.
    claude-desktop = {
      url = "github:poeck/claude-desktop-nix-flake/55ba585546fe222bf18f391a98c1ee60f79684d2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI usage tracker (private). git+https so it's fetched with the user's own
    # git credentials; osupdate bumps it with everything else, and osupgrade
    # fetches the locked revision as the user before the root rebuild.
    aut = {
      url = "git+https://github.com/michaelosbornegit/aut?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TAM screen-time tracker (private; stratus only). Same git+https scheme as aut:
    # fetched with the user's git credentials by osupgrade's archive step. Provides
    # the tam-desktop daemon, the GNOME extension and the home-manager module.
    tam = {
      url = "git+https://github.com/michaelosbornegit/tam?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Track Home Manager master with nixos-unstable; release branches are only
    # for stable Nixpkgs channels.
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Darwin
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nix-darwin,
    ...
  } @ inputs: let
    systems = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Formatter for your nix files, available through 'nix fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations = {
      stratus = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          user = "resonatortune";
          stateVersion = "25.05";
        };
        modules = [
          ./hosts/stratus/configuration.nix
        ];
      };
      vm = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
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
          inherit inputs;
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
