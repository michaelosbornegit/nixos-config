{pkgs}: {
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

  blender = pkgs.blender.override { cudaSupport = true; };

  obs = (pkgs.wrapOBS.override { obs-studio = pkgs.obs-studio; }) {
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-gstreamer
      obs-vkcapture
    ];
  };

  kdenlive = pkgs.kdePackages.kdenlive;

  plex-desktop = pkgs.plex-desktop;

  prismlauncher = pkgs.prismlauncher;
}
