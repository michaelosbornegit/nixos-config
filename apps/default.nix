{pkgs}: let
  ps2Pkg = pkgs.writeShellScriptBin "ps2" ''
    exec ${pkgs.pcsx2}/bin/pcsx2-qt "$@"
  '';

  retroarchPkg = pkgs.writeShellScriptBin "retroarch" ''
    exec ${pkgs.retroarch.withCores (cores:
      with cores; [
        snes9x
      ])}/bin/retroarch "$@"
  '';
in {
  apps = {
    ps2 = {
      type = "app";
      program = "${ps2Pkg}/bin/ps2";
    };

    retroarch = {
      type = "app";
      program = "${retroarchPkg}/bin/retroarch";
    };

    snes = {
      type = "app";
      program = "${retroarchPkg}/bin/retroarch";
    };
  };
}
