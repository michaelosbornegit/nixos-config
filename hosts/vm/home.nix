{...}: {
  home.homeDirectory = "/home/${user}";

  home.packages = [
    # packages
    # pkgs.jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # pkgs.wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # pkgs.esptool # for interacting with esp32 boards
    # # apps
    pkgs.microsoft-edge
    # pkgs.discord
    # pkgs.prusa-slicer
    # pkgs.mongodb-compass
    # # games/fun
    # pkgs.prismlauncher # for minecraft for fun
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # change gnome to my liking
  dconf.settings = {
    # IMPORTANT disable sleep, for some reason things break after sleep
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    # nautilus (file viewer) default to list mode
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
    # nautilus (file viewer) default zoom to small
    "org/gnome/nautilus/list-view" = {
      default-zoom-level = "small";
    };
    "org/gnome/desktop/interface" = {
      # hot corners (mouse in corner opens overview) is annoying
      enable-hot-corners = false;
      # disable animations cause fairly usually clumsy and slow, specifically smooth scroll animations
      enable-animations = false;
    };
    "org/gnome/desktop/sound" = {
      # disable annoying sounds
      event-sounds = false;
    };
    "org/gnome/mutter" = {
      # enable drag to sides of screen tiling like in windows and elsewhere
      edge-tiling = true;
      # Enable dynamic workspaces so I can have infinite workspaces (the default of 4 is odd)
      dynamic-workspaces = true;
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      # show hidden files in file chooser
      show-hidden = true;
    };
  };

  # personal email
  programs.git.userEmail = "resonatortune@gmail.com";

  home.file = {
    ".p10k-config".source = ../../dotfiles/p10k-config;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
