{
  inputs,
  outputs,
  user,
  stateVersion,
  homeStateVersion,
  ...
}: {
  imports = [
    ../common.nix
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.backupFileExtension = "hm-bak";
      home-manager.extraSpecialArgs = {
        inherit inputs outputs user;
        stateVersion = homeStateVersion;
      };
      home-manager.users.${user} = {
        imports = [
          ../home-common.nix
          ./home.nix
        ];
      };
    }
  ];

  users.users."${user}".home = "/Users/${user}";

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [
    # pkgs.vim
  ];

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Enable Linux builder
  nix.linux-builder.enable = true;

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # The platform the configuration will be used on.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Set the nix-darwin system state version
  system.stateVersion = stateVersion;
}
