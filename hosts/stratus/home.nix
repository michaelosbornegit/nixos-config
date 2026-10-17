# Home Manager configuration for stratus. The lazy GUI app launchers live in
# lazy-apps.nix and the Roblox launchers in roblox.nix.
{
  inputs,
  pkgs,
  user,
  ...
}: let
  gamemoderun = "${pkgs.gamemode}/bin/gamemoderun";
in {
  imports = [
    inputs.slippi.homeManagerModules.default
    {
      # Point the launcher at your local Melee ISO; adjust if stored elsewhere.
      slippi-launcher.isoPath = "/home/${user}/Documents/Super Smash Bros. Melee (v1.02).iso";
    }
    ./lazy-apps.nix
    ./roblox.nix
  ];

  home = {
    homeDirectory = "/home/${user}";

    packages = with pkgs; [
      # packages
      gh
      esptool # for interacting with esp32 boards
      sox # audio recording for Claude Code's /voice mode
      # apps
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
    ];

    file = {
      ".config/mimeapps.list".source = ../../dotfiles/.config/mimeapps.list;
      ".config/mimeapps.list".force = true;
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs = {
    firefox = {
      enable = true;
      configPath = ".mozilla/firefox";
      profiles.default.settings = {
        # Keep Firefox tabs out of GNOME's MPRIS media controls. Publishing every
        # player here caused desktop-wide stalls when tracks changed.
        "media.hardwaremediakeys.enabled" = false;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;
        # RTX 2080 Ti has NVDEC for H.264/VP9/HEVC, but not AV1.
        "media.av1.enabled" = false;
      };
    };

    vscode.profiles.default.extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      # MicroPico extension for esp32/pico w dev
      {
        name = "pico-w-go";
        publisher = "paulober";
        version = "4.2.1";
        sha256 = "sha256-0wa8nr/HVXe+y10u8HO1LU7+pT8iixoorUfchJP5uhw=";
      }
    ];

    # personal email
    git.settings.user.email = "resonatortune@gmail.com";

    zsh.shellAliases = {
      melee = "${gamemoderun} nix run github:lytedev/slippi-nix#slippi-launcher";
      gopher64 = "flatpak install -y flathub io.github.gopher64.gopher64 && \
                  ${gamemoderun} flatpak run io.github.gopher64.gopher64";
    };
  };

  gtk = {
    enable = true;
    gtk4.theme = null;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus";
    };
  };

  xdg.desktopEntries.firefox = {
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

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        "just-perfection-desktop@just-perfection"
        # Retrying with upstream v103 after v102 triggered a GNOME Shell 50.2
        # libgvc crash. Remove this UUID first if the login crash returns.
        "quick-settings-audio-panel@rayzeq.github.io"
      ];
    };

    "org/gnome/shell/keybindings".show-screenshot-ui = [
      "Print"
      "<Super><Shift>s"
    ];

    "org/gnome/shell/extensions/just-perfection" = {
      animation = 4;
      double-super-to-appgrid = false;
    };

    "org/gnome/desktop/interface" = {
      enable-animations = true;
      icon-theme = "Papirus";
    };
  };
}
