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
    # pkgs.jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # pkgs.wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # pkgs.esptool # for interacting with esp32 boards
    # # apps
    pkgs.microsoft-edge
    # pkgs.discord
    # pkgs.prusa-slicer
    # pkgs.mongodb-compass
    # # games/fun
    # pkgs.prismlauncher # for minecraft for fun
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # work email
  programs.git.userEmail = "mosborne@westmonroe.com";

  home.file = {
    ".p10k-config".source = ../../dotfiles/p10k-config;
  };
}
