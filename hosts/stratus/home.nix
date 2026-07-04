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
  gamemoderun = "${pkgs.gamemode}/bin/gamemoderun";
  flatpak = "${pkgs.flatpak}/bin/flatpak";
  # Flatpak 1.18 leaks NixOS's host PATH into flatpak-spawn subsandboxes.
  # Sober's glycin image loader expects FHS paths there, including /usr/bin.
  flatpakRun = "env PATH=/usr/bin:/bin ${flatpak}";
  lazyNixBuild = pkgs.writeShellApplication {
    name = "lazy-nix-build";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      zenity
    ];
    text = builtins.readFile ./lazy-nix-build.sh;
  };
  robloxExperienceApplicationDir = "/home/${user}/.local/share/applications";
  robloxExperienceIconDir = "/home/${user}/.local/share/icons/hicolor/512x512/apps";
  robloxExperiences = {
    fishos = {
      command = "roblox-fishos";
      desktopId = "roblox-fishos";
      fallbackName = "FISH.OS";
      fallbackComment = "Launch FISH.OS in Sober";
      icon = "roblox-fishos";
      placeId = "123368132872113";
      keywords = [
        "fish"
        "fishos"
        "fish.os"
        "fishing"
        "roblox"
        "sober"
      ];
    };
    petSimulator = {
      command = "roblox-pet-simulator";
      desktopId = "roblox-pet-simulator";
      fallbackName = "Pet Simulator 99";
      fallbackComment = "Launch Pet Simulator 99 in Sober";
      icon = "roblox-pet-simulator";
      placeId = "8737899170";
      keywords = [
        "pets"
        "pet simulator"
        "pet sim"
        "ps99"
        "roblox"
        "sober"
      ];
    };
  };
  robloxExperiencePlaceIds =
    lib.concatStringsSep ","
    (map (experience: experience.placeId) (lib.attrValues robloxExperiences));
  robloxExperienceUpdater = pkgs.writeShellApplication {
    name = "roblox-refresh-experiences";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnused
      jq
    ];
    text = ''
      application_dir=${lib.escapeShellArg robloxExperienceApplicationDir}
      icon_dir=${lib.escapeShellArg robloxExperienceIconDir}
      mkdir -p "$application_dir"
      mkdir -p "$icon_dir"
      rm -f "$application_dir/roblox-pets.desktop"

      desktop_escape() {
        printf '%s' "$1" \
          | tr '\r\n' '  ' \
          | sed 's/[[:cntrl:]]//g; s/\\/\\\\/g'
      }

      thumbnail_response="$(
        curl --fail --silent --show-error --location \
          ${lib.escapeShellArg "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=${robloxExperiencePlaceIds}&size=512x512&format=Png&isCircular=false"} \
          || true
      )"

      universe_ids=""
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: experience: ''
          universe_id="$(
            curl --fail --silent --show-error --location \
              ${lib.escapeShellArg "https://apis.roblox.com/universes/v1/places/${experience.placeId}/universe"} \
              | jq --raw-output '.universeId // empty' \
              || true
          )"
          if [ -n "$universe_id" ]; then
            if [ -n "$universe_ids" ]; then
              universe_ids="$universe_ids,$universe_id"
            else
              universe_ids="$universe_id"
            fi
          fi
        '')
        robloxExperiences)}

      games_response='{"data":[]}'
      if [ -n "$universe_ids" ]; then
        games_response="$(
          curl --fail --silent --show-error --location \
            "https://games.roblox.com/v1/games?universeIds=$universe_ids" \
            || printf '{"data":[]}'
        )"
      fi

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: experience: ''
          image_url="$(
            printf '%s' "$thumbnail_response" \
              | jq --raw-output --arg target ${lib.escapeShellArg experience.placeId} \
                '.data[] | select((.targetId | tostring) == $target) | select(.state == "Completed") | .imageUrl' \
              | head -n 1 \
              || true
          )"
          if [ -n "$image_url" ] && [ "$image_url" != "null" ]; then
            tmp="$icon_dir/${experience.icon}.png.tmp"
            if curl --fail --silent --show-error --location "$image_url" --output "$tmp"; then
              mv "$tmp" "$icon_dir/${experience.icon}.png"
            else
              rm -f "$tmp"
            fi
          fi

          raw_name="$(
            printf '%s' "$games_response" \
              | jq --raw-output --arg place ${lib.escapeShellArg experience.placeId} \
                '.data[] | select((.rootPlaceId | tostring) == $place) | .name // empty' \
              | head -n 1 \
              || true
          )"
          if [ -z "$raw_name" ] || [ "$raw_name" = "null" ]; then
            raw_name=${lib.escapeShellArg experience.fallbackName}
          fi

          name="$(desktop_escape "$raw_name")"
          comment="$(desktop_escape ${lib.escapeShellArg experience.fallbackComment})"
          keywords=${lib.escapeShellArg (lib.concatStringsSep ";" experience.keywords + ";")}

          {
            printf '%s\n' '[Desktop Entry]'
            printf '%s\n' 'Type=Application'
            printf '%s\n' 'Version=1.5'
            printf 'Name=%s\n' "$name"
            printf 'Comment=%s\n' "$comment"
            printf '%s\n' 'Exec=${experience.command}'
            printf '%s\n' 'Icon=${experience.icon}'
            printf '%s\n' 'Terminal=false'
            printf '%s\n' 'Categories=Game;'
            printf '%s\n' 'StartupNotify=true'
            printf '%s\n' 'PrefersNonDefaultGPU=true'
            printf 'Keywords=%s\n' "$keywords"
          } >"$application_dir/${experience.desktopId}.desktop"
        '')
        robloxExperiences)}
    '';
  };
  robloxSoberLaunchScript = experience: ''
    ${robloxExperienceUpdater}/bin/roblox-refresh-experiences >/dev/null 2>&1 || true
    ${flatpak} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ${flatpak} install -y flathub org.vinegarhq.Sober
    exec ${flatpakRun} run --command=sober org.vinegarhq.Sober ${lib.escapeShellArg "roblox://placeId=${experience.placeId}"}
  '';
  mkHostLazyPackageExpr = packageAttr:
    lib.escapeShellArg ''
      let
        flake = builtins.getFlake "${repoFlake}";
        pkgs = import flake.inputs.nixpkgs {
          system = builtins.currentSystem;
          config.allowUnfree = true;
        };
        beammp = flake.inputs.beammp;
        codexDesktopLinux = flake.inputs.codex-desktop-linux;
      in
      (import "${hostLazyPackagesPath}" { inherit pkgs beammp codexDesktopLinux; }).${packageAttr}
    '';
  lazyGuiApps = {
    beammp = {
      desktopName = "BeamMP";
      comment = "Launch BeamMP in a terminal";
      icon = "beamng-drive";
      categories = [
        "Game"
      ];
      execArg = "";
      packageAttr = "beammp";
      gameMode = true;
      terminal = true;
    };
    beammp-doctor = {
      desktopName = "BeamMP Doctor";
      packageAttr = "beammp-doctor";
      desktopEntry = false;
    };
    beammp-link = {
      desktopName = "BeamMP Link";
      packageAttr = "beammp-link";
      desktopEntry = false;
    };
    beammp-proton = {
      desktopName = "BeamMP Proton";
      packageAttr = "beammp-proton";
      desktopEntry = false;
    };
    roblox-fishos = {
      desktopName = robloxExperiences.fishos.fallbackName;
      comment = robloxExperiences.fishos.fallbackComment;
      icon = robloxExperiences.fishos.icon;
      categories = [
        "Game"
      ];
      execArg = "";
      execScript = robloxSoberLaunchScript robloxExperiences.fishos;
      desktopEntry = false;
    };
    roblox-pet-simulator = {
      desktopName = robloxExperiences.petSimulator.fallbackName;
      comment = robloxExperiences.petSimulator.fallbackComment;
      icon = robloxExperiences.petSimulator.icon;
      categories = [
        "Game"
      ];
      execArg = "";
      execScript = robloxSoberLaunchScript robloxExperiences.petSimulator;
      desktopEntry = false;
    };
    ps2 = {
      desktopName = "PlayStation 2";
      comment = "PlayStation 2 emulator";
      icon = "PCSX2";
      desktopId = "PCSX2";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "ps2";
      gameMode = true;
    };
    retroarch = {
      desktopName = "RetroArch";
      comment = "Frontend for emulators and game engines";
      icon = "com.libretro.RetroArch";
      desktopId = "com.libretro.RetroArch";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "retroarch";
      gameMode = true;
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
      gameMode = true;
    };
    parsec = {
      desktopName = "Parsec";
      comment = "Remote desktop and game streaming";
      icon = "parsec";
      desktopId = "parsecd";
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
      desktopId = "org.DolphinEmu.dolphin-emu";
      categories = [
        "Game"
      ];
      execArg = "%F";
      packageAttr = "gamecube";
      gameMode = true;
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
      desktopId = "com.usebottles.bottles";
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
      desktopId = "com.obsproject.Studio";
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
      desktopId = "org.kde.kdenlive";
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
      icon = "plex-desktop";
      categories = [
        "AudioVideo"
        "Video"
      ];
      execArg = "%U";
      packageAttr = "plex-desktop";
      settings = {
        StartupWMClass = "Plex";
      };
    };
    discord = {
      desktopName = "Discord";
      comment = "Chat client";
      icon = "discord";
      desktopId = "discord";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      execArg = "%U";
      binary = "Discord";
      packageAttr = "discord";
      settings = {
        StartupWMClass = "discord";
      };
    };
    vesktop = {
      desktopName = "Vesktop";
      comment = "Chat client with Linux screen sharing support";
      icon = "vesktop";
      desktopId = "vesktop";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      execArg = "%U";
      binary = "vesktop";
      packageAttr = "vesktop";
      settings = {
        StartupWMClass = "Vesktop";
      };
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
    scrcpy = {
      desktopName = "scrcpy";
      comment = "Display and control your Android device";
      icon = "guiscrcpy";
      desktopId = "scrcpy";
      categories = [
        "Utility"
        "RemoteAccess"
      ];
      execArg = "";
      packageAttr = "scrcpy";
      startupNotify = false;
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
      desktopEntry = false;
    };
    minecraft = {
      desktopName = "Minecraft";
      comment = "Minecraft launcher";
      icon = "minecraft";
      desktopId = "org.prismlauncher.PrismLauncher";
      categories = [
        "Game"
      ];
      execArg = "%U";
      packageAttr = "minecraft";
      gameMode = true;
      settings = {
        StartupWMClass = "org.prismlauncher.PrismLauncher";
      };
    };
    osrs = {
      desktopName = "Old School RuneScape";
      comment = "RuneLite Old School RuneScape client";
      icon = "runelite";
      desktopId = "RuneLite";
      categories = [
        "Game"
      ];
      execArg = "%U";
      binary = "runelite";
      packageAttr = "runelite";
      gameMode = true;
      settings = {
        StartupWMClass = "net-runelite-client-RuneLite";
      };
    };
    codex-app = {
      desktopName = "Codex Desktop";
      comment = "Run Codex Desktop on Linux";
      icon = "codex-desktop";
      desktopId = "codex-desktop";
      categories = [
        "Development"
      ];
      execArg = "%U";
      packageAttr = "codex-app";
      startupNotify = true;
      settings = {
        StartupWMClass = "codex-desktop";
        X-GNOME-WMClass = "codex-desktop";
      };
      mimeType = [
        "x-scheme-handler/codex"
        "x-scheme-handler/codex-browser-sidebar"
      ];
      actions = {
        new-window = {
          name = "New Window";
          exec = "codex-app --new-instance";
        };
      };
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
        result="$(${lazyNixBuild}/bin/lazy-nix-build ${lib.escapeShellArg cfg.desktopName} ${hostLazyPackageExpr})" || exit $?
        exec ${lib.optionalString (cfg.gameMode or false) "${gamemoderun} "}"$result/bin/${cfg.binary or command}" "$@"
      ''
      else if cfg ? execScript
      then cfg.execScript
      else ''
        exec nix run ${repoFlake}#${cfg.target} -- "$@"
      ''
    );

  mkDesktopEntry = command: cfg:
    lib.nameValuePair (cfg.desktopId or command) (
      {
        name = cfg.desktopName;
        comment = cfg.comment;
        exec = "${command} ${cfg.execArg}";
        icon = cfg.icon;
        terminal = cfg.terminal or false;
        categories = cfg.categories;
      }
      // lib.optionalAttrs (cfg ? mimeType) {
        mimeType = cfg.mimeType;
      }
      // lib.optionalAttrs (cfg ? startupNotify) {
        startupNotify = cfg.startupNotify;
      }
      // lib.optionalAttrs (cfg ? noDisplay) {
        noDisplay = cfg.noDisplay;
      }
      // lib.optionalAttrs (cfg ? settings) {
        settings = cfg.settings;
      }
      // lib.optionalAttrs (cfg ? actions) {
        actions = cfg.actions;
      }
    );
  lazyDesktopEntries =
    lib.listToAttrs
    (lib.mapAttrsToList mkDesktopEntry
      (lib.filterAttrs (_: cfg: cfg.desktopEntry or true) lazyGuiApps));
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
      robloxExperienceUpdater
    ]
    ++ lib.mapAttrsToList mkLazyCommand lazyGuiApps;

  home.activation.updateRobloxExperienceLaunchers = lib.hm.dag.entryAfter ["writeBoundary"] ''
    ${robloxExperienceUpdater}/bin/roblox-refresh-experiences || true
  '';

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
    lazyDesktopEntries
    // {
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
      # Temporarily disabled after GNOME Shell 50.2 started crashing at login in
      # libgvc `_pa_context_get_card_info_by_index_cb`, which makes GNOME
      # disable all extensions and breaks Just Perfection animation speed.
      # Re-test after quick-settings-audio-panel or GNOME Shell updates.
      # "quick-settings-audio-panel@rayzeq.github.io"
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
    melee = "${gamemoderun} nix run github:lytedev/slippi-nix#slippi-launcher";
    roblox = "${flatpak} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
              ${flatpak} install flathub org.vinegarhq.Sober && \
              ${flatpak} update && \
              ${flatpakRun} run org.vinegarhq.Sober";
    gopher64 = "flatpak install -y flathub io.github.gopher64.gopher64 && \
                ${gamemoderun} flatpak run io.github.gopher64.gopher64";
  };
}
