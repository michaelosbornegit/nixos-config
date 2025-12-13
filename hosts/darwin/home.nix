{
  outputs,
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";
  # work email
  programs.git.settings.user.email = "mosborne@blankmetal.ai";

  # Erroring and usually unneeded, will install separately if needed
  # programs.firefox.enable = true;

  home.packages = [
    # pkgs.microsoft-edge If this is ever available for aarch64 darwin

    # utilities
    pkgs.coreutils-prefixed
    pkgs.scrcpy
    pkgs.raycast
    pkgs.loopwm
    pkgs.nodejs

    # apps
    pkgs.postman
    pkgs.code-cursor
    # pkgs.warp-terminal
    # pkgs.windsurf
    pkgs.ghostty-bin
    # use these through npm
    # pkgs.codex
    # pkgs.claude-code
  ];
}
