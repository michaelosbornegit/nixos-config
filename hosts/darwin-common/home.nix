{
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";

  # Copy .app bundles instead of symlinking them so Spotlight/Launchpad index them
  # (copyApps only defaults on from stateVersion 25.11).
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;

  home.packages = with pkgs; [
    # utilities
    coreutils-prefixed
    gh
    scrcpy
    loopwm

    # apps
    # postman, firefox, raycast: Homebrew casks (hosts/darwin-common/homebrew.nix)
    # warp-terminal
    # windsurf
    ghostty-bin
    # use these through npm
    # codex
    # claude-code
  ];
}
