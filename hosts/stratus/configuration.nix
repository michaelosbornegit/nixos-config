{
  inputs,
  config,
  pkgs,
  user,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../nixos-common.nix
    ../desktop.nix
    inputs.slippi.nixosModules.default
    ./claude-desktop
    ./switch2-pro-wake
  ];

  # Proton 11 and Proton Experimental use ntsync automatically when
  # /dev/ntsync exists (it is world-accessible). The kernel ships it as a
  # module, but nothing loads it by default.
  boot.kernelModules = ["ntsync"];

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
    firewall = {
      enable = true;
      # libvirt NAT bridge: guests get DHCP and DNS from the host.
      trustedInterfaces = ["virbr0"];
    };
  };

  # Compressed in-RAM swap helps desktop responsiveness under memory pressure.
  zramSwap.enable = true;
  # Usual zram tuning: swapping to compressed RAM is cheap, so prefer it over
  # dropping page cache, and skip swap readahead, which only helps disks.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
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
    gamemode = {
      enable = true;
      # Without a renice value gamemode only switches the CPU governor, which
      # power-profiles-daemon already keeps at performance.
      settings.general.renice = 10;
    };
    gamescope.enable = true;
    virt-manager.enable = true;
    steam = {
      enable = true;
      # GE-Proton, selectable per game under Properties > Compatibility.
      extraCompatPackages = [pkgs.proton-ge-bin];
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    nix-ld.enable = true;
  };

  users.groups.libvirtd.members = [user];

  virtualisation = {
    libvirtd = {
      enable = true;
      # NixOS defaults to onBoot = "start" / onShutdown = "suspend", which
      # saves running guests at shutdown and resumes them at boot regardless
      # of the per-domain autostart flag.
      onBoot = "ignore";
      onShutdown = "shutdown";
    };
    spiceUSBRedirection.enable = true;
    docker = {
      enable = true;
      # Socket-activated: dockerd starts on the first docker command. At boot
      # it pulled NetworkManager-wait-online (~6s) into the path to the desktop.
      enableOnBoot = false;
    };
  };

  environment = {
    pathsToLink = ["/share/zsh"];
    sessionVariables = {
      # NVIDIA's shader disk cache (used by emulators and non-Steam games) sat
      # at its default size cap, so the driver evicted and recompiled shaders.
      __GL_SHADER_DISK_CACHE_SIZE = "12000000000";
      __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
    };
    systemPackages = with pkgs; [
      f3d
      kdiskmark
      mangohud
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
    gnome = {
      gnome-remote-desktop.enable = false;
      # The file indexer's background I/O and CPU bursts land mid-game. Costs
      # file-content results in Nautilus and Activities search.
      localsearch.enable = false;
    };
    flatpak.enable = true;
  };

  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
