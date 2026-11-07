# xdg-utils whose xdg-open drops LD_LIBRARY_PATH. Claude's package wrapper
# exports a Nix LD_LIBRARY_PATH, and xdg-open would pass it on to the browser;
# Firefox then loads Claude's older libnss3 and dies, so link clicks (OAuth,
# connectors, chat links) silently do nothing.
{pkgs}:
pkgs.symlinkJoin {
  name = "xdg-utils-clean-env";
  paths = [pkgs.xdg-utils];
  nativeBuildInputs = [pkgs.makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/xdg-open --unset LD_LIBRARY_PATH
  '';
}
