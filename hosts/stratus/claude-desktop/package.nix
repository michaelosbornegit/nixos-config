# Claude Desktop built from the pinned flake's recipe. With no version this is
# the pinned release; the launcher calls it again with a newer version and the
# SHA256 from Anthropic's signed apt index to build updates without a rebuild.
{
  pkgs,
  claudeDesktopSrc,
  version ? null,
  sha256 ? null,
}: let
  base = pkgs.callPackage "${claudeDesktopSrc}/pkgs/claude-desktop" {
    # The package wrapper exports a Nix LD_LIBRARY_PATH that xdg-open passes on
    # to the browser; Firefox then loads Claude's older libnss3 and dies, so
    # link clicks (OAuth, connectors) silently do nothing.
    xdg-utils = pkgs.symlinkJoin {
      name = "xdg-utils-clean-env";
      paths = [pkgs.xdg-utils];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/xdg-open --unset LD_LIBRARY_PATH
      '';
    };
  };
  # 3.x links libpipewire from a native module; the pinned recipe predates it.
  withPipewire = base.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [pkgs.pipewire];
  });
  inherit (base.passthru.sources.${pkgs.stdenv.hostPlatform.system}) debArch;
in
  if version == null
  then withPipewire
  else
    withPipewire.overrideAttrs {
      inherit version;
      src = pkgs.fetchurl {
        url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_${debArch}.deb";
        inherit sha256;
      };
    }
