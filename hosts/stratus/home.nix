# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  pkgs,
  user,
  ...
}: {
  home.homeDirectory = "/home/${user}";

  home.packages = [
    # packages
    pkgs.jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    pkgs.wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    pkgs.esptool # for interacting with esp32 boards
    # apps
    pkgs.microsoft-edge
    pkgs.discord
    pkgs.prusa-slicer
    pkgs.mongodb-compass
    # games/fun
    pkgs.prismlauncher # for minecraft for fun
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.vscode.extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    # MicroPico extension for esp32/pico w dev
    {
      name = "pico-w-go";
      publisher = "paulober";
      version = "4.2.1";
      sha256 = "sha256-0wa8nr/HVXe+y10u8HO1LU7+pT8iixoorUfchJP5uhw=";
    }
  ];

  # personal email
  programs.git.userEmail = "resonatortune@gmail.com";

  home.file = {
    ".p10k-config".source = ../../dotfiles/p10k-config;
  };
}
