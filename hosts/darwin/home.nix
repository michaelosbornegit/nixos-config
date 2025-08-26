{
  outputs,
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";
  # work email
  programs.git.userEmail = "mosborne@blankmetal.ai";

  programs.firefox.enable = true;

  home.file = {
    ".p10k-config".source = ../../dotfiles/.p10k-config;
  };

  home.packages = [
    # pkgs.microsoft-edge If this is ever available for arm64 darwin
    # productivity
    pkgs.slack
    pkgs.notion-app

    # utilities
    pkgs.coreutils-prefixed
    pkgs.scrcpy
    pkgs.awscli2
    pkgs.claude-code
    
    # apps
    pkgs.postman
    pkgs.code-cursor
    pkgs.windsurf
    pkgs.warp-terminal
  ];
}
