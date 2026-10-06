{
  pkgs,
  beammp,
  # Launchers built before codex-desktop-linux was removed still pass
  # codexDesktopLinux; accept and ignore it so they keep working until rebuilt.
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  beammpApps = beammp.apps.${system};
  retroarchSnes = pkgs.retroarch.withCores (cores: [cores.snes9x]);
in {
  beammp = pkgs.writeShellScriptBin "beammp" ''
    exec ${beammpApps.beammp.program} "$@"
  '';

  beammp-doctor = pkgs.writeShellScriptBin "beammp-doctor" ''
    exec ${beammpApps.beammp-doctor.program} "$@"
  '';

  beammp-link = pkgs.writeShellScriptBin "beammp-link" ''
    exec ${beammpApps.beammp-link.program} "$@"
  '';

  beammp-proton = pkgs.writeShellScriptBin "beammp-proton" ''
    exec ${beammpApps.beammp-proton.program} "$@"
  '';

  ps2 = pkgs.writeShellScriptBin "ps2" ''
    exec ${pkgs.pcsx2}/bin/pcsx2-qt "$@"
  '';

  retroarch = pkgs.writeShellScriptBin "retroarch" ''
    exec ${retroarchSnes}/bin/retroarch "$@"
  '';

  snes = pkgs.writeShellScriptBin "snes" ''
    exec ${retroarchSnes}/bin/retroarch "$@"
  '';

  parsec = pkgs.writeShellScriptBin "parsec" ''
    exec ${pkgs.parsec-bin}/bin/parsecd "$@"
  '';

  gamecube = pkgs.writeShellScriptBin "gamecube" ''
    exec ${pkgs.dolphin-emu}/bin/dolphin-emu "$@"
  '';

  blender = pkgs.blender.override {cudaSupport = true;};

  obs = pkgs.wrapOBS {
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };

  kdenlive = pkgs.writeShellScriptBin "kdenlive" ''
    exec env QT_QPA_PLATFORM=xcb QT_QPA_PLATFORMTHEME=gnome ${pkgs.kdePackages.kdenlive}/bin/kdenlive "$@"
  '';

  minecraft = pkgs.writeShellScriptBin "minecraft" ''
    export PATH="${pkgs.lib.makeBinPath [pkgs.ffmpeg]}:$PATH"
    exec ${pkgs.prismlauncher}/bin/prismlauncher "$@"
  '';

  inherit
    (pkgs)
    bottles
    discord
    google-chrome
    plex-desktop
    prismlauncher
    runelite
    scrcpy
    vesktop
    xclicker
    ;
}
