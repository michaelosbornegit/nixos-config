# fractus: personal MacBook.
{user, ...}: {
  imports = [../darwin-common/configuration.nix];

  networking = {
    hostName = "fractus";
    computerName = "fractus";
    localHostName = "fractus";
  };

  home-manager.users.${user}.imports = [./home.nix];
}
