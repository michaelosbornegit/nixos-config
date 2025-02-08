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
    homeDirectory = "/home/${user}";
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

    initExtra = "source ~/.p10k-config";

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
    extensions = with pkgs.vscode-extensions; [
      bbenoist.nix
      ms-python.python
      ms-azuretools.vscode-docker
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers
      mechatroner.rainbow-csv
    ];
    userSettings = {
      "workbench.colorTheme" = "Default Light Modern";
      "terminal.integrated.defaultProfile.linux" = "zsh";
      "security.workspace.trust.untrustedFiles" = "open";
      "git.enableSmartCommit" = true;
      "git.autofetch" = true;
    };
  };

  programs.git = {
    enable = true;
    userEmail = "resonatortune@gmail.com";
    userName = "Michael Osborne";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
