{
  pkgs,
  beammp ? null,
  codexDesktopLinux,
}: let
  system = pkgs.stdenv.hostPlatform.system;
  beammpApps =
    if beammp == null
    then throw "BeamMP lazy packages require the beammp flake input"
    else beammp.apps.${system};
  codexDesktopPackage = codexDesktopLinux.packages.${system}.codex-desktop;
  codexCliForApp = pkgs.writeShellScriptBin "codex-cli-for-app" ''
    exec ${pkgs.nodejs}/bin/npx --yes @openai/codex@latest "$@"
  '';
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
    exec ${pkgs.retroarch.withCores (cores:
      with cores; [
        snes9x
      ])}/bin/retroarch "$@"
  '';

  snes = pkgs.writeShellScriptBin "snes" ''
    exec ${pkgs.retroarch.withCores (cores:
      with cores; [
        snes9x
      ])}/bin/retroarch "$@"
  '';

  parsec = pkgs.writeShellScriptBin "parsec" ''
    exec ${pkgs.parsec-bin}/bin/parsecd "$@"
  '';

  gamecube = pkgs.writeShellScriptBin "gamecube" ''
    exec ${pkgs.dolphin-emu}/bin/dolphin-emu "$@"
  '';

  kdiskmark = pkgs.writeShellScriptBin "kdiskmark" ''
    exec ${pkgs.kdiskmark}/bin/kdiskmark "$@"
  '';

  bottles = pkgs.bottles;

  blender = pkgs.blender.override {cudaSupport = true;};

  obs = (pkgs.wrapOBS.override {obs-studio = pkgs.obs-studio;}) {
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

  plex-desktop = pkgs.plex-desktop;

  vesktop = pkgs.vesktop;

  google-chrome = pkgs.google-chrome;

  scrcpy = pkgs.scrcpy;

  prismlauncher = pkgs.prismlauncher;

  minecraft = pkgs.writeShellScriptBin "minecraft" ''
    export PATH="${pkgs.lib.makeBinPath [pkgs.ffmpeg]}:$PATH"
    exec ${pkgs.prismlauncher}/bin/prismlauncher "$@"
  '';

  runelite = pkgs.runelite;

  codex-app = pkgs.writeShellScriptBin "codex-app" ''
    export CODEX_CLI_PATH="${codexCliForApp}/bin/codex-cli-for-app"
    exec ${codexDesktopPackage}/bin/codex-desktop "$@"
  '';

  xclicker = pkgs.xclicker;
}
