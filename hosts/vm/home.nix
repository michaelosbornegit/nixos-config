{
  inputs,
  outputs,
  pkgs,
  user,
  ...
}: {
  home.homeDirectory = "/home/${user}";

  home.packages = with pkgs; [
    # packages
    # jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    # esptool # for interacting with esp32 boards
    # # apps
    microsoft-edge
    # discord
    # prusa-slicer
    # mongodb-compass
    # # games/fun
    # prismlauncher # for minecraft for fun
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # personal email
  programs.git.settings.user.email = "resonatortune@gmail.com";

  home.file = {
    ".config/mimeapps.list".source = ../../dotfiles/.config/mimeapps.list;
    ".config/mimeapps.list".force = true;
  };
}
