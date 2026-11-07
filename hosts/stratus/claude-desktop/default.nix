# Claude Desktop that keeps itself current. The `claude-desktop` command (and
# the desktop entry) launches the newest build available right away, then
# checks Anthropic's signed apt repo in the background and builds any newer
# release for the next launch. See launcher.sh for the verification chain.
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  pinned = import ./package.nix {
    inherit pkgs;
    claudeDesktopSrc = inputs.claude-desktop;
  };
  inherit (pinned.passthru.sources.${system}) debArch;

  # Built by the launcher at runtime: same nixpkgs and recipe as the pinned
  # package, so only the .deb differs.
  updateExpr = pkgs.writeText "claude-desktop-update.nix" ''
    {version, sha256}:
    import ${./package.nix} {
      pkgs = import ${inputs.nixpkgs} {
        system = "${system}";
        config.allowUnfree = true;
      };
      claudeDesktopSrc = ${inputs.claude-desktop};
      inherit version sha256;
    }
  '';

  keyring = pkgs.runCommand "anthropic-release-keyring.gpg" {nativeBuildInputs = [pkgs.gnupg];} ''
    gpg --dearmor < ${./anthropic-release-key.asc} > $out
  '';

  launcher = pkgs.writeShellApplication {
    name = "claude-desktop";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
      gnupg
      libnotify
      nix
      util-linux
    ];
    runtimeEnv = {
      PINNED_PACKAGE = "${pinned}";
      PINNED_VERSION = pinned.version;
      UPDATE_EXPR = "${updateExpr}";
      KEYRING = "${keyring}";
      DEB_ARCH = debArch;
    };
    text = builtins.readFile ./launcher.sh;
  };
in {
  imports = [inputs.claude-desktop.nixosModules.default];

  programs.claude-desktop = {
    enable = true;
    # The pinned package with bin/ and the desktop entry pointed at the
    # launcher instead of the package's own wrapper.
    package = pkgs.symlinkJoin {
      name = "claude-desktop-auto-update-${pinned.version}";
      paths = [pinned];
      postBuild = ''
        rm $out/bin/claude-desktop
        ln -s ${lib.getExe launcher} $out/bin/claude-desktop
        desktop=share/applications/com.anthropic.Claude.desktop
        rm $out/$desktop
        substitute ${pinned}/$desktop $out/$desktop \
          --replace-fail "${pinned}/bin/claude-desktop" "$out/bin/claude-desktop"
      '';
    };
  };
}
