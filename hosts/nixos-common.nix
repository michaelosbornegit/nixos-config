{
  inputs,
  lib,
  user,
  stateVersion,
  ...
}: let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in {
  imports = [
    ./common.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    # Share the system's nixpkgs (and its allowUnfree) instead of evaluating a
    # second one, and install user packages into the per-user system profile.
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    extraSpecialArgs = {inherit inputs user stateVersion;};
    users.${user}.imports = [
      ./home-common.nix
    ];
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      flake-registry = "";
      nix-path = lib.mapAttrsToList (name: _: "${name}=flake:${name}") flakeInputs;
      extra-substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    channel.enable = false;
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
  };

  nixpkgs.config.allowUnfree = true;
}
