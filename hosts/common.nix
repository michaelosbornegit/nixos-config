{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  user,
  ...
}: {
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # # List packages installed in system profile. To search, run:
  # # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   home-manager
  # ];

  # Enable zsh
  programs.zsh.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
