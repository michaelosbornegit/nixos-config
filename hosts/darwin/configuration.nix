{
  self,
  inputs,
  outputs,
  pkgs,
  user,
  stateVersion,
  ...
}: {
  imports = [
    ../common.nix
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager.users.${user} = {
        imports = [
          (import ../home-common.nix {inherit inputs outputs pkgs user stateVersion;})
          (import ./home.nix {inherit inputs outputs pkgs user;})
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
      outputs.overlays.stable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
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
}
