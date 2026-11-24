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
    {app = "/Applications/Discord.app";}
    {app = "/Applications/Ghostty.app";}
  ];

  # Personal-only apps, on top of the shared casks in darwin-common/homebrew.nix
  # (same rule: self-updating casks only).
  homebrew.casks = [
    "discord"
    "prismlauncher"
    "steam"
  ];

  home-manager.users.${user}.imports = [./home.nix];
}
