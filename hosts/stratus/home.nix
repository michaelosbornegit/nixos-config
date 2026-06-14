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
    discord = {
      desktopName = "Vesktop";
      comment = "Chat client with Linux screen sharing support";
      icon = "vesktop";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      execArg = "%U";
      binary = "vesktop";
      packageAttr = "vesktop";
    };
    google-chrome = {
      desktopName = "Google Chrome";
      comment = "Access the Internet";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      execArg = "%U";
      binary = "google-chrome-stable";
      packageAttr = "google-chrome";
    };
    prismlauncher = {
      desktopName = "Prism Launcher";
      comment = "Minecraft launcher";
      icon = "minecraft";
      categories = [
        "Game"
      ];
      execArg = "%U";
      packageAttr = "prismlauncher";
    };
    minecraft = {
      desktopName = "Minecraft";
      comment = "Minecraft launcher";
      icon = "minecraft";
      categories = [
        "Game"
      ];
      execArg = "%U";
      packageAttr = "minecraft";
    };
    xclicker = {
      desktopName = "XClicker";
      comment = "Fast GUI autoclicker";
      icon = "xclicker";
      categories = [
        "Utility"
      ];
      execArg = "%U";
      packageAttr = "xclicker";
    };
  };

  mkLazyCommand = command: cfg: let
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
    }
    // lib.optionalAttrs (cfg ? mimeType) {
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

  home.packages = with pkgs;
    [
      # packages
      gh
      esptool # for interacting with esp32 boards
      # apps
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
      gnomeExtensions.just-perfection
      gnomeExtensions.quick-settings-audio-panel
    ]
    ++ lib.mapAttrsToList mkLazyCommand lazyGuiApps;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";
    profiles.default.settings = {
      "media.ffmpeg.vaapi.enabled" = true;
      "media.hardware-video-decoding.force-enabled" = true;
      "media.rdd-ffmpeg.enabled" = true;
      # RTX 2080 Ti has NVDEC for H.264/VP9/HEVC, but not AV1.
      "media.av1.enabled" = false;
    };
  };

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
        icon = "beamng-drive";
        terminal = true;
        categories = [
          "Game"
        ];
      };
      firefox = {
        name = "Firefox";
        comment = "Access the Internet";
        exec = "env LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct MOZ_DISABLE_RDD_SANDBOX=1 MOZ_ENABLE_WAYLAND=1 ${pkgs.firefox}/bin/firefox %U";
        icon = "firefox";
        terminal = false;
        categories = [
          "Network"
          "WebBrowser"
        ];
        mimeType = [
          "text/html"
          "application/xhtml+xml"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ];
      };
    };

  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = [
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
