# mackerel: work MacBook.
{user, ...}: {
  imports = [../darwin-common/configuration.nix];

  # No networking names here: IT names this Mac (Jamf Setup Manager template),
  # and renaming a managed machine is theirs to do. osupgrade finds this config
  # through ~/.config/nixos-config/host instead (see darwin-common/osupgrade.nix).

  system.defaults.dock.persistent-apps = [
    {app = "/Applications/Firefox.app";}
    {app = "/Applications/Slack.app";}
    {app = "/Applications/ChatGPT.app";}
    {app = "/Applications/Claude.app";}
    {app = "/Applications/Granola.app";}
    {app = "/Applications/Spotify.app";}
  ];

  # Work-only apps, on top of the shared casks in darwin-common/homebrew.nix
  # (same rule: self-updating casks only).
  homebrew.casks = ["notion"];

  home-manager.users.${user}.imports = [
    ./home.nix
    ./vercel-ai-gateway.nix
    ./vercel-ai-gateway-toggle.nix
  ];
}
