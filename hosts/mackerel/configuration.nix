# mackerel: work MacBook.
{user, ...}: {
  imports = [../darwin-common/configuration.nix];

  # No networking names here: IT names this Mac (Jamf Setup Manager template),
  # and renaming a managed machine is theirs to do. osupgrade finds this config
  # through ~/.config/nixos-config/host instead (see darwin-common/osupgrade.nix).

  home-manager.users.${user}.imports = [
    ./home.nix
    ./vercel-ai-gateway.nix
    ./vercel-ai-gateway-toggle.nix
  ];
}
