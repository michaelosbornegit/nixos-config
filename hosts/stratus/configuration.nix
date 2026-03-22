{
  inputs,
  config,
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/default.nix
    ../gnome.nix
    inputs.slippi.nixosModules.default
  ];

  home-manager.users.${user}.imports = [
    ./home.nix
    ../gnome-home-conf.nix
  ];

  networking = {
    hostName = "stratus";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  users.users.${user} = {
    isNormalUser = true;
    description = user;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "dialout"
    ];
    shell = pkgs.zsh;
  };

  programs = {
    virt-manager.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    obs-studio = {
      enable = true;
      package = pkgs.obs-studio.override {
        cudaSupport = true;
      };
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-pipewire-audio-capture
        obs-gstreamer
        obs-vkcapture
      ];
    };
    nix-ld.enable = true;
  };

  users.groups.libvirtd.members = [user];

  virtualisation = {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
    docker.enable = true;
  };

  environment = {
    pathsToLink = ["/share/zsh"];
    systemPackages = with pkgs; [
      gnome-remote-desktop
      gnome-session
      xrdp
    ];
  };

  hardware = {
    graphics.enable = true;
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    xone.enable = true;
  };

  services = {
    xserver.videoDrivers = ["nvidia"];
    gnome.gnome-remote-desktop.enable = true;
    xrdp = {
      enable = true;
      openFirewall = true;
      defaultWindowManager = "gnome-session";
    };
    flatpak.enable = true;
    openssh.enable = true;
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
