{
  inputs,
  user,
  stateVersion,
  homeStateVersion,
  ...
}: {
  imports = [
    ../common.nix
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager = {
        # Share the system's nixpkgs (and its allowUnfree) instead of evaluating a
        # second one, and install user packages into the per-user system profile.
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        extraSpecialArgs = {
          inherit inputs user;
          stateVersion = homeStateVersion;
        };
        users.${user} = {
          imports = [
            ../home-common.nix
            ./home.nix
            ./vercel-ai-gateway.nix
            ./vercel-ai-gateway-toggle.nix
            ./agent-monitor.nix
          ];
        };
      };
    }
  ];

  users.users."${user}".home = "/Users/${user}";

  nixpkgs.config.allowUnfree = true;

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
