# Lazy GUI apps: each is a tiny launcher that builds the real package on first
# use (see lazy-packages.nix and lazy-nix-build.sh) instead of living in the
# Home Manager closure, which keeps `osupgrade` fast. Anything used all the
# time should be a normal package instead.
{
  lib,
  pkgs,
  user,
  ...
}: let
  repoFlake = "/home/${user}/development/repos/nixos-config";
  hostLazyPackagesPath = "${repoFlake}/hosts/stratus/lazy-packages.nix";
  gamemoderun = "${pkgs.gamemode}/bin/gamemoderun";
  lazyNixBuild = pkgs.writeShellApplication {
    name = "lazy-nix-build";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      zenity
    ];
    text = builtins.readFile ./lazy-nix-build.sh;
  };
  mkHostLazyPackageExpr = packageAttr:
    lib.escapeShellArg ''
      let
        flake = builtins.getFlake "${repoFlake}";
        pkgs = import flake.inputs.nixpkgs {
          system = builtins.currentSystem;
          config.allowUnfree = true;
        };
        beammp = flake.inputs.beammp;
      in
      (import "${hostLazyPackagesPath}" { inherit pkgs beammp; }).${packageAttr}
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

  mkLazyCommand = command: cfg:
    pkgs.writeShellScriptBin command ''
      result="$(${lazyNixBuild}/bin/lazy-nix-build ${lib.escapeShellArg cfg.desktopName} ${mkHostLazyPackageExpr cfg.packageAttr})" || exit $?
      exec ${lib.optionalString (cfg.gameMode or false) "${gamemoderun} "}"$result/bin/${cfg.binary or command}" "$@"
    '';

  mkDesktopEntry = command: cfg:
    lib.nameValuePair (cfg.desktopId or command) (
      {
        inherit (cfg) comment icon categories;
        name = cfg.desktopName;
        exec = "${command} ${cfg.execArg}";
        terminal = cfg.terminal or false;
      }
      // lib.optionalAttrs (cfg ? mimeType) {inherit (cfg) mimeType;}
      // lib.optionalAttrs (cfg ? startupNotify) {inherit (cfg) startupNotify;}
      // lib.optionalAttrs (cfg ? settings) {inherit (cfg) settings;}
    );
in {
  home.packages = lib.mapAttrsToList mkLazyCommand lazyGuiApps;

  xdg.desktopEntries =
    lib.mapAttrs' mkDesktopEntry
    (lib.filterAttrs (_: cfg: cfg.desktopEntry or true) lazyGuiApps);
}
