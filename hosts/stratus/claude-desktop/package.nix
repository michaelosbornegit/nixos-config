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
    # Also on the system PATH (default.nix): Claude swaps its PATH for the
    # login shell's, so this copy is not the only xdg-open it may find.
    xdg-utils = import ./xdg-utils-clean-env.nix {inherit pkgs;};
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
