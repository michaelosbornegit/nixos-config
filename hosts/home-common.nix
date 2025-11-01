# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  pkgs,
  user,
  stateVersion,
  ...
}: {
  nixpkgs.config.allowUnfree = true;

  home = {
    username = "${user}";

    file = {
      ".p10k-config".source = ../dotfiles/.p10k-config;
    };

    packages = [
      pkgs.zsh-powerlevel10k # zsh theme
      pkgs.zsh-forgit # zsh forgit integration
      pkgs.zsh-fzf-tab # zsh fzf tab completion
      pkgs.ripgrep-all # for searching
      pkgs.fd # for file finding
      pkgs.bat # for file previewing
      pkgs.wget # for wgetting
      # Open Search and open files by contents in VSCode
      (pkgs.writeShellApplication {
        name = "textsearch";
        runtimeInputs = [pkgs.ripgrep-all pkgs.fzf pkgs.bat pkgs.vscode];
        text = ''
          RG_PREFIX="rga --column --line-number --no-heading --color=always --smart-case"
          INITIAL_QUERY="''${*:-}"
          fzf --ansi --disabled --query "$INITIAL_QUERY" \
              --bind "start:reload:$RG_PREFIX {q}" \
              --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" \
              --delimiter : \
              --preview 'bat --color=always {1} --highlight-line {2}' \
              --preview-window 'right,50%,border-left,+{2}+3/3,~3' \
              --bind 'enter:become(code --goto {1}:{2})'
        '';
      })
      # Search and open files by name in VSCode
      (pkgs.writeShellApplication {
        name = "filesearch";
        runtimeInputs = [pkgs.fd pkgs.fzf pkgs.vscode];
        text = ''
          result=$(fd "$@" | fzf)
          if [ -n "$result" ]; then
            code "$result"
          fi
        '';
      })
    ];
  };

  # PROGRAMS
  programs.zsh = {
    enable = true;
    # enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      osupdate = "nix flake update";
      osupgrade =
        if pkgs.stdenv.isDarwin
        then "sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#darwin"
        else "sudo nixos-rebuild switch --flake .#$(hostname)";
    };

    # Set ZSH_FZF_HISTORY_SEARCH_BIND before plugins load (mkOrder 550 runs before completion init)
    # This ensures the zsh-fzf-history-search plugin uses our custom up arrow binding instead of ^r
    initContent = lib.mkMerge [
      (lib.mkOrder 550 (
        if pkgs.stdenv.isDarwin
        then "ZSH_FZF_HISTORY_SEARCH_BIND='^[[A'"
        else ''
          if [[ -n ''${terminfo[kcuu1]} ]]; then
            ZSH_FZF_HISTORY_SEARCH_BIND=''${terminfo[kcuu1]}
          else
            ZSH_FZF_HISTORY_SEARCH_BIND=$'\e[A'
          fi
        ''
      ))
      ''
        ZSH_FZF_HISTORY_SEARCH_END_OF_LINE='true'
        source ~/.p10k-config
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.zsh
        source ${pkgs.zsh-forgit}/share/zsh/zsh-forgit/forgit.plugin.zsh
      ''
    ];

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];

    zplug = {
      enable = true;
      plugins = [
        {name = "joshskidmore/zsh-fzf-history-search";}
      ];
    };
  };

  programs.fzf.enable = true;

  programs.zoxide = {
    enable = true;
    options = ["--cmd cd"];
  };

  programs.eza = {
    enable = true;
    colors = "always";
    icons = "auto";
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
        "terminal.integrated.fontFamily" = "MesloLGS NF";
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
      };
    };
  };

  programs.git = {
    enable = true;
    settings.user.name = "Michael Osborne";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = stateVersion;
}
