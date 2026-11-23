# mackerel: work MacBook.
{user, ...}: {
  imports = [../darwin-common/configuration.nix];

  networking = {
    hostName = "mackerel";
    computerName = "mackerel";
    localHostName = "mackerel";
  };

  home-manager.users.${user}.imports = [
    ./home.nix
    ./vercel-ai-gateway.nix
    ./vercel-ai-gateway-toggle.nix
  ];
}
