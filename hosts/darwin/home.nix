{ outputs, pkgs, user, ... }: {
    # overwrite some things for darwin
    home.homeDirectory = "/Users/${user}";
    # work email
    programs.git.userEmail = "mosborne@westmonroe.com";

    home.file = {
      ".p10k-config".source = ../../dotfiles/p10k-config;
    };

    home.packages = [
      pkgs.ollama
    ];
}
