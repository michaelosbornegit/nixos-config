{
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";
  # work email
  programs.git.settings.user.email = "mosborne@blankmetal.ai";

  # Drive the Desk Buddy OLED agent counter from aut's database.
  services.aut.deskbuddy.enable = true;

  # Erroring and usually unneeded, will install separately if needed
  # programs.firefox.enable = true;

  home.packages = with pkgs; [
    # utilities
    coreutils-prefixed
    gh
    scrcpy
    raycast
    loopwm

    # apps
    postman
    code-cursor
    # warp-terminal
    # windsurf
    ghostty-bin
    # use these through npm
    # codex
    # claude-code
  ];
}
