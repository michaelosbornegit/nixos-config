# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/home-manager):
    # outputs.homeManagerModules.example

    # Or modules exported from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModules.default

    # You can also split up your configuration and import pieces of it here:
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    username = "resonatortune";
    homeDirectory = "/home/resonatortune";
    packages = [
      # packages
      pkgs.zsh-powerlevel10k # zsh theme
      pkgs.jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
      pkgs.wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
      pkgs.wget # for wgetting
      pkgs.esptool # for interacting with esp32 boards
      # apps
      pkgs.microsoft-edge
      pkgs.discord
      pkgs.prusa-slicer
      pkgs.mongodb-compass
      # games/fun
      pkgs.prismlauncher # for minecraft for fun
      # # Adds the 'hello' command to your environment. It prints a friendly
      # # "Hello, world!" when run.
      # pkgs.hello

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
    ];
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

    # change gnome to my liking
  dconf.settings = {
      # IMPORTANT disable sleep, for some reason things break after sleep
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
      # nautilus (file viewer) default to list mode
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
      # nautilus (file viewer) default zoom to small
    "org/gnome/nautilus/list-view" = {
      default-zoom-level = "small";
    };
    "org/gnome/desktop/interface" = {
      # hot corners (mouse in corner opens overview) is annoying
      enable-hot-corners = false;
      # disable animations cause fairly usually clumsy and slow, specifically smooth scroll animations
      enable-animations = false;
    };
    "org/gnome/desktop/sound" = {
      # disable annoying sounds
      event-sounds = false;
    };
    "org/gnome/mutter" = {
      # enable drag to sides of screen tiling like in windows and elsewhere
      edge-tiling = true;
      # Enable dynamic workspaces so I can have infinite workspaces (the default of 4 is odd)
      dynamic-workspaces = true;
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      # show hidden files in file chooser
      show-hidden = true;
    };
  };

  # PROGRAMS
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      osedit = "code /etc/nixos/configuration.nix";
      osupdate = "sudo nixos-rebuild switch";
      osupgrade = "sudo nixos-rebuild switch --upgrade";
      homeedit = "code ~/.config/home-manager/home.nix";
      homeupdate = "home-manager switch";
      homeupgrade = "sudo nix-channel --update && home-manager switch";
    };

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
    enable=true;
    userEmail="resonatortune@gmail.com";
    userName="Michael Osborne";
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    ".p10k-config".source = dotfiles/p10k-config;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/resonatortune/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.11";
}
