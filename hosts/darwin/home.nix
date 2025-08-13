{
  outputs,
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";
  # work email
  programs.git.userEmail = "mosborne@wblankmetal.ai";

  home.file = {
    ".p10k-config".source = ../../dotfiles/.p10k-config;
  };

  home.sessionVariables = {
    CLAUDE_CODE_USE_BEDROCK = "1";
  };

  home.packages = [
    # pkgs.microsoft-edge If this is ever available for arm64 darwin
    pkgs.slack
    pkgs.claude-code
    pkgs.awscli2
    pkgs.postman
    pkgs.scrcpy
    pkgs.code-cursor
    pkgs.windsurf
    pkgs.warp-terminal
  ];
}
