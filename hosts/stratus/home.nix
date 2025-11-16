# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    inputs.slippi.homeManagerModules.default
    {
      # Point the launcher at your local Melee ISO; adjust if stored elsewhere.
      slippi-launcher.isoPath = "/home/${user}/Documents/Super Smash Bros. Melee (v1.02).iso";
    }
  ];

  home.homeDirectory = "/home/${user}";

  home.packages = [
    # packages
    pkgs.jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    pkgs.wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    pkgs.esptool # for interacting with esp32 boards
    # apps
    pkgs.microsoft-edge
    pkgs.discord
    # pkgs.prusa-slicer
    # pkgs.mongodb-compass
    # pkgs.code-cursor
    # pkgs.windsurf
    pkgs.appimage-run
    pkgs.warp-terminal
    pkgs.spotify
    # games/fun
    pkgs.prismlauncher # for minecraft for fun
    pkgs.parsec-bin
    # pkgs.ollama-cuda # takes forever to install, so not included in normal builds
    pkgs.vlc
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.vscode.profiles.default.extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    # MicroPico extension for esp32/pico w dev
    {
      name = "pico-w-go";
      publisher = "paulober";
      version = "4.2.1";
      sha256 = "sha256-0wa8nr/HVXe+y10u8HO1LU7+pT8iixoorUfchJP5uhw=";
    }
  ];

  # personal email
  programs.git.settings.user.email = "resonatortune@gmail.com";

  home.file = {
    ".config/mimeapps.list".source = ../../dotfiles/.config/mimeapps.list;
    ".config/mimeapps.list".force = true;
  };

  programs.zsh.shellAliases = {
    melee = "nix run github:lytedev/slippi-nix#slippi-launcher";
    roblox = "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
              flatpak install flathub org.vinegarhq.Sober && \
              flatpak update && \
              flatpak run org.vinegarhq.Sober";
  };
}
