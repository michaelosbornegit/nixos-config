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
    networkmanager = {
      enable = true;
      plugins = with pkgs; [networkmanager-openvpn];
    };
    firewall.enable = false;
  };

  # Compressed in-RAM swap helps desktop responsiveness under memory pressure.
  zramSwap.enable = true;

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
      f3d
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
    gnome.gnome-remote-desktop.enable = false;
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
