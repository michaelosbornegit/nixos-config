{
  inputs,
  lib,
  user,
  ...
}: let
  # GUI apps that ship their own updater live here as casks instead of in
  # home.packages: a nix-store copy is read-only, so it can never update itself
  # and lags nixpkgs. Homebrew installs them once; the app keeps itself current.
  # Only self-updating casks are allowed; anything else belongs in nix.
  # Apps IT deploys through Jamf (root-owned in /Applications) stay out of this
  # list so Homebrew never fights the MDM.
  casks = [
    "chatgpt"
    "claude"
    "firefox"
    "google-gemini"
    "notion"
    "postman"
    "raycast"
    "spotify"
  ];

  caskFile = name: "${inputs.homebrew-cask}/Casks/${lib.substring 0 1 name}/${name}.rb";
  selfUpdates = name: let
    file = caskFile name;
  in
    builtins.pathExists file
    && builtins.match ".*\n[[:space:]]*auto_updates true\n.*" (builtins.readFile file) != null;
  notSelfUpdating = lib.filter (name: !selfUpdates name) casks;
in {
  imports = [inputs.nix-homebrew.darwinModules.nix-homebrew];

  assertions = [
    {
      assertion = notSelfUpdating == [];
      message = ''
        These Homebrew casks don't declare `auto_updates true`, so they would only
        update through `brew upgrade`: ${lib.concatStringsSep ", " notSelfUpdating}.
        Install them through nix instead, or check the name exists in homebrew-cask
        (run `nix flake update homebrew-cask` if the cask is new).
      '';
    }
  ];

  nix-homebrew = {
    enable = true;
    inherit user;
    # Take over a Homebrew install if one already exists.
    autoMigrate = true;
  };

  homebrew = {
    enable = true;
    onActivation = {
      # Remove casks/formulae that are no longer listed here (keeps app data;
      # "zap" would also delete it).
      cleanup = "uninstall";
    };
    inherit casks;
  };
}
