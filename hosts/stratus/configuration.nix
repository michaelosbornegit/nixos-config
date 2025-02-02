# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ../vm/hardware-configuration.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

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

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  networking.hostName = "stratus"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # MYEDIT Remove GNOME bloat, from https://nixos.wiki/wiki/GNOME
  environment.gnome.excludePackages = (with pkgs; [
    gnome.atomix # puzzle game
    gnome.cheese # webcam tool
    gnome.epiphany # web browser
    gnome.evince # document viewer
    gnome.geary # email reader
    # gedit # text editor MYEDIT keep
    gnome.gnome-characters
    gnome.gnome-music
    gnome-photos
    # gnome-terminal MYEDIT keep
    gnome-tour
    gnome.hitori # sudoku game
    gnome.iagno # go game
    gnome.tali # poker game
    # totem # video player MYEDIT keep
  ]);

  # MYEDIT speed up for gnome from https://discourse.nixos.org/t/overlays-seem-ignored-when-sudo-nixos-rebuild-switch-gnome-47-triple-buffering-compilation-errors/55434/12
  # UPDATE seems buggy
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     mutter = prev.mutter.overrideAttrs (oldAttrs: {
  #       # GNOME dynamic triple buffering (huge performance improvement)
  #       # See https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/1441
  #       src = final.fetchFromGitLab {
  #         domain = "gitlab.gnome.org";
  #         owner = "vanvugt";
  #         repo = "mutter";
  #         rev = "triple-buffering-v4-47";
  #         hash = "sha256-1VXEzKwzrqLCZby2oWxjclA08kPhxs/Om5N17qYeglM=";
  #       };

  #       preConfigure =
  #         let
  #           gvdb = final.fetchFromGitLab {
  #             domain = "gitlab.gnome.org";
  #             owner = "GNOME";
  #             repo = "gvdb";
  #             rev = "2b42fc75f09dbe1cd1057580b5782b08f2dcb400";
  #             hash = "sha256-CIdEwRbtxWCwgTb5HYHrixXi+G+qeE1APRaUeka3NWk=";
  #           };
  #         in
  #         ''
  #           cp -a "${gvdb}" ./subprojects/gvdb
  #         '';
  #     });
  #   })
  # ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.resonatortune = {
    isNormalUser = true;
    description = "mosborne";
    extraGroups = [ 
      "networkmanager" 
      "wheel"
      "docker" # MYEDIT docker group required for docker to work
      "dialout" # MYEDIT required to communicate with usb (e.g. micropico vscode extension)
    ];
    shell = pkgs.zsh;
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "resonatortune";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    # swtpm # for tpm emulation for windows vms
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # SERVICES
  # virt-manager for virtualization
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["resonatortune"];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  # for windows VMs, emulated tpm support
  # virtualisation.libvirtd.qemu.swtpm.enable = true;

  # Enable zsh
  programs.zsh.enable = true;

  # Enable docker
  virtualisation.docker.enable = true;

  # pathsToLink for zsh system package completion
  environment.pathsToLink = [ "/share/zsh" ];

  # # nvidia support from https://nixos.wiki/wiki/Nvidia
  # # Enable OpenGL
  # hardware.graphics = {
  #   enable = true;
  # };
  # # Load nvidia driver for Xorg and Wayland
  # services.xserver.videoDrivers = ["nvidia"];
  # hardware.nvidia = {
  #   # Modesetting is required.
  #   modesetting.enable = true;

  #   # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
  #   # Enable this if you have graphical corruption issues or application crashes after waking
  #   # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead 
  #   # of just the bare essentials.
  #   powerManagement.enable = false;

  #   # Fine-grained power management. Turns off GPU when not in use.
  #   # Experimental and only works on modern Nvidia GPUs (Turing or newer).
  #   powerManagement.finegrained = false;

  #   # Use the NVidia open source kernel module (not to be confused with the
  #   # independent third-party "nouveau" open source driver).
  #   # Support is limited to the Turing and later architectures. Full list of 
  #   # supported GPUs is at: 
  #   # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus 
  #   # Only available from driver 515.43.04+
  #   # Currently alpha-quality/buggy, so false is currently the recommended setting.
  #   open = false;

  #   # Enable the Nvidia settings menu,
	#   # accessible via `nvidia-settings`.
  #   nvidiaSettings = true;

  #   # Optionally, you may need to select the appropriate driver version for your specific GPU.
  #   package = config.boot.kernelPackages.nvidiaPackages.stable;
  # };


  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  # Enable dynamically linked executable execution for vscode remote ssh
  programs.nix-ld.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ 8822 8823 6600 6601 3000 3001 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
