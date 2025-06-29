{
  outputs,
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";
  # work email
  programs.git.userEmail = "mosborne@westmonroe.com";

  home.file = {
    ".p10k-config".source = ../../dotfiles/.p10k-config;
  };

  home.sessionVariables = {
    CLAUDE_CODE_USE_BEDROCK = "1";
  };

  home.packages = [
    pkgs.ollama
    pkgs.claude-code
    pkgs.awscli2
    pkgs.postman
    pkgs.scrcpy
    pkgs.code-cursor
    pkgs.windsurf
    pkgs.warp-terminal
  ];
}
