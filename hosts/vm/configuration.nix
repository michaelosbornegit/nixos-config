{
  user,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/default.nix
    ../gnome.nix
  ];

  home-manager.users.${user}.imports = [
    ./home.nix
    ../gnome-home-conf.nix
  ];

  networking.hostName = "vm";

  users.users.${user} = {
    isNormalUser = true;
    description = user;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  services = {
    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
  };
}
