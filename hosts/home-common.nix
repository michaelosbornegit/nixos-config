# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  pkgs,
  user,
  ...
}: {
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${user}";
    packages = [
      # packages
      pkgs.zsh-powerlevel10k # zsh theme
      pkgs.wget # for wgetting
    ];
  };

  # PROGRAMS
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # shellAliases = {
    #   osedit = "code /etc/nixos/configuration.nix";
    #   osupdate = "sudo nixos-rebuild switch";
    #   osupgrade = "sudo nixos-rebuild switch --upgrade";
    #   homeedit = "code ~/.config/home-manager/home.nix";
    #   homeupdate = "home-manager switch";
    #   homeupgrade = "sudo nix-channel --update && home-manager switch";
    # };

    initContent = "source ~/.p10k-config";

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    # to fix autocomplete in NixOS, from https://nixos.wiki/wiki/Zsh
    # turns out to maybe not be needed
    # initExtra = "bindkey "''${key[Up]}" up-line-or-search";
  };

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        ms-azuretools.vscode-docker
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-containers
        bbenoist.nix
        ms-python.python
        mechatroner.rainbow-csv
        github.vscode-pull-request-github
        github.copilot
      ];
      userSettings = {
        "workbench.colorTheme" = "Default Light Modern";
        "terminal.integrated.defaultProfile.linux" = "zsh";
        # trust all files
        "security.workspace.trust.untrustedFiles" = "open";
        # commit all changes when there are no staged changes
        "git.enableSmartCommit" = true;
        # periodically fetch
        "git.autofetch" = true;
        # no confirm dialog when clicking sync
        "git.confirmSync" = false;
        # format on save if possible
        "editor.formatOnSave" = true;
        # copilot settings
        "chat.agent.maxRequests" = 100;
        "chat.tools.autoApprove" = true;
        "mssql.connectionGroups" = [
          {
            "name" = "ROOT";
            "id" = "A6A67991-18BC-4473-9A4E-0BFB0B2F0F19";
          }
        ];
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "Michael Osborne";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.05";
}
