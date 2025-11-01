{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  stateVersion,
  ...
}: {
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # # List packages installed in system profile. To search, run:
  # # $ nix search wget
  # environment.systemPackages = with pkgs; [
  #   home-manager
  # ];

  # Enable zsh
  programs.zsh.enable = true;

  fonts.packages = with pkgs; [
    meslo-lgs-nf
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = stateVersion;
}
