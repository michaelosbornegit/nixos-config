# fractus: personal MacBook.
{user, ...}: {
  imports = [../darwin-common/configuration.nix];

  networking = {
    hostName = "fractus";
    computerName = "fractus";
    localHostName = "fractus";
  };

  # Personal Dock. Apps not installed by this config (casks in
  # darwin-common/homebrew.nix) need installing by hand first.
  system.defaults.dock.persistent-apps = [
    {app = "/Applications/Firefox.app";}
    {app = "/Applications/ChatGPT.app";}
    {app = "/Applications/Claude.app";}
    {app = "/Applications/Spotify.app";}
  ];

  home-manager.users.${user}.imports = [./home.nix];
}
