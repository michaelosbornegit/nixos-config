# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: let
  repoFlake = "/home/${user}/development/repos/nixos-config";
  hostLazyPackagesPath = "${repoFlake}/hosts/stratus/lazy-packages.nix";
  mkHostLazyPackageExpr = packageAttr:
    lib.escapeShellArg ''
      let
        flake = builtins.getFlake "${repoFlake}";
        pkgs = import flake.inputs.nixpkgs {
          system = builtins.currentSystem;
          config.allowUnfree = true;
        };
      in
      (import "${hostLazyPackagesPath}" { inherit pkgs; }).${packageAttr}
    '';
  lazyGuiApps = {
    ps2 = {
      desktopName = "PlayStation 2";
      comment = "PlayStation 2 emulator";
      icon = "pcsx2";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "ps2";
    };
    retroarch = {
      desktopName = "RetroArch";
      comment = "Frontend for emulators and game engines";
      icon = "com.libretro.RetroArch";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "retroarch";
    };
    snes = {
      desktopName = "Super Nintendo";
      comment = "SNES emulator launcher";
      icon = "com.libretro.RetroArch";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "snes";
    };
    parsec = {
      desktopName = "Parsec";
      comment = "Remote desktop and game streaming";
      icon = "parsec";
      categories = [
        "Network"
        "RemoteAccess"
      ];
      execArg = "%U";
      packageAttr = "parsec";
    };
    gamecube = {
      desktopName = "GameCube";
      comment = "GameCube and Wii emulator";
      icon = "dolphin-emu";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "gamecube";
    };
    kdiskmark = {
      desktopName = "KDiskMark";
      comment = "Disk benchmark tool";
      icon = "kdiskmark";
      categories = [
        "System"
        "Utility"
      ];
      execArg = "%U";
      packageAttr = "kdiskmark";
    };
    bottles = {
      desktopName = "Bottles";
      comment = "Run Windows software and games";
      icon = "com.usebottles.bottles";
      categories = [
        "Utility"
      ];
      execArg = "%U";
      packageAttr = "bottles";
    };
    blender = {
      desktopName = "Blender";
      comment = "3D creation suite";
      icon = "blender";
      categories = [
        "Graphics"
        "3DGraphics"
      ];
      execArg = "%F";
      mimeType = [
        "application/x-blender"
      ];
      packageAttr = "blender";
    };
    obs = {
      desktopName = "OBS Studio";
      comment = "Streaming and recording software";
      icon = "com.obsproject.Studio";
      categories = [
        "AudioVideo"
        "Recorder"
      ];
      execArg = "%U";
      packageAttr = "obs";
    };
    kdenlive = {
      desktopName = "Kdenlive";
      comment = "Video editor";
      icon = "kdenlive";
      categories = [
        "AudioVideo"
        "Video"
        "AudioVideoEditing"
      ];
      execArg = "%U";
      packageAttr = "kdenlive";
    };
    plex-desktop = {
      desktopName = "Plex";
      comment = "Plex desktop client";
      icon = "plex";
      categories = [
        "AudioVideo"
        "Video"
      ];
      execArg = "%U";
      packageAttr = "plex-desktop";
    };
    prismlauncher = {
      desktopName = "Prism Launcher";
      comment = "Minecraft launcher";
      icon = "prismlauncher";
      categories = [
        "Game"
      ];
      execArg = "%U";
      packageAttr = "prismlauncher";
    };
  };

  mkLazyCommand = command: cfg:
    let
      hostLazyPackageExpr = mkHostLazyPackageExpr cfg.packageAttr;
    in
      pkgs.writeShellScriptBin command (
        if cfg ? packageAttr
        then ''
          result="$(nix build --impure --no-link --print-out-paths --expr ${hostLazyPackageExpr})"
          exec "$result/bin/${cfg.binary or command}" "$@"
        ''
        else if cfg ? execScript
        then cfg.execScript
        else ''
          exec nix run ${repoFlake}#${cfg.target} -- "$@"
        ''
      );

  mkDesktopEntry = command: cfg:
    {
      name = cfg.desktopName;
      comment = cfg.comment;
      exec = "${command} ${cfg.execArg}";
      icon = cfg.icon;
      terminal = false;
      categories = cfg.categories;
    } // lib.optionalAttrs (cfg ? mimeType) {
      mimeType = cfg.mimeType;
    };
in {
  imports = [
    inputs.slippi.homeManagerModules.default
    {
      # Point the launcher at your local Melee ISO; adjust if stored elsewhere.
      slippi-launcher.isoPath = "/home/${user}/Documents/Super Smash Bros. Melee (v1.02).iso";
    }
  ];

  home.homeDirectory = "/home/${user}";

  home.packages = with pkgs; [
    # packages
    gh
    esptool # for interacting with esp32 boards
    # apps
    microsoft-edge
    google-chrome
    discord
    scrcpy
    # prusa-slicer
    # mongodb-compass
    # code-cursor
    # windsurf
    appimage-run
    # games/fun
    # ollama-cuda # takes forever to install, so not included in normal builds
    vlc
    ghostty
    gnomeExtensions.vitals
    gnomeExtensions.just-perfection
    gnomeExtensions.quick-settings-audio-panel
  ] ++ lib.mapAttrsToList mkLazyCommand lazyGuiApps;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.vscode.profiles.default.extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    # MicroPico extension for esp32/pico w dev
    {
      name = "pico-w-go";
      publisher = "paulober";
      version = "4.2.1";
      sha256 = "sha256-0wa8nr/HVXe+y10u8HO1LU7+pT8iixoorUfchJP5uhw=";
    }
  ];

  # personal email
  programs.git.settings.user.email = "resonatortune@gmail.com";

  home.file = {
    ".config/mimeapps.list".source = ../../dotfiles/.config/mimeapps.list;
    ".config/mimeapps.list".force = true;
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus";
    };
  };

  xdg.desktopEntries =
    lib.mapAttrs mkDesktopEntry lazyGuiApps
    // {
      beammp = {
        name = "BeamMP";
        comment = "Launch BeamMP in a terminal";
        exec = inputs.beammp.apps.${pkgs.stdenv.hostPlatform.system}.beammp.program;
        icon = "utilities-terminal";
        terminal = true;
        categories = [
          "Game"
        ];
      };
    };

  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = [
      "Vitals@CoreCoding.com"
      "just-perfection-desktop@just-perfection"
      "quick-settings-audio-panel@rayzeq.github.io"
    ];
  };

  dconf.settings."org/gnome/shell/keybindings" = {
    show-screenshot-ui = [
      "Print"
      "<Super><Shift>s"
    ];
  };

  dconf.settings."org/gnome/shell/extensions/vitals" = {
    show-temperature = false;
    show-voltage = false;
    show-fan = false;
    show-system = false;
    show-storage = false;
    show-network = false;
    show-battery = false;
    show-memory = true;
    show-processor = true;
    show-gpu = true;
    hot-sensors = [
      "_memory_usage_"
      "_processor_usage_"
      "_gpu#1_graphics_"
    ];
  };

  dconf.settings."org/gnome/shell/extensions/just-perfection" = {
    animation = 4;
    double-super-to-appgrid = false;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    enable-animations = true;
    icon-theme = "Papirus";
  };

  programs.zsh.shellAliases = {
    beammp = "${inputs.beammp.apps.${pkgs.stdenv.hostPlatform.system}.beammp.program}";
    beammp-doctor = "${inputs.beammp.apps.${pkgs.stdenv.hostPlatform.system}.beammp-doctor.program}";
    beammp-link = "${inputs.beammp.apps.${pkgs.stdenv.hostPlatform.system}.beammp-link.program}";
    beammp-proton = "${inputs.beammp.apps.${pkgs.stdenv.hostPlatform.system}.beammp-proton.program}";
    melee = "nix run github:lytedev/slippi-nix#slippi-launcher";
    roblox = "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
              flatpak install flathub org.vinegarhq.Sober && \
              flatpak update && \
              flatpak run org.vinegarhq.Sober";
    gopher64 = "flatpak install -y flathub io.github.gopher64.gopher64 && \
                flatpak run io.github.gopher64.gopher64";
  };
}
