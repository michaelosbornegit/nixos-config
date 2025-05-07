{
  pkgs,
  outputs,
  user,
  ...
}: {
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.displayManager.gdm.autoSuspend = false;

  # MYEDIT Remove GNOME bloat, from https://nixos.wiki/wiki/GNOME
  environment.gnome.excludePackages = with pkgs; [
    atomix # puzzle game
    cheese # webcam tool
    epiphany # web browser
    evince # document viewer
    geary # email reader
    # gedit # text editor MYEDIT keep
    gnome-characters
    gnome-music
    gnome-photos
    # gnome-terminal MYEDIT keep
    gnome-tour
    hitori # sudoku game
    iagno # go game
    tali # poker game
    # totem # video player MYEDIT keep
  ];

  # MYEDIT speed up for gnome from https://discourse.nixos.org/t/overlays-seem-ignored-when-sudo-nixos-rebuild-switch-gnome-47-triple-buffering-compilation-errors/55434/12
  # UPDATE seems buggy
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     mutter = prev.mutter.overrideAttrs (oldAttrs: {
  #       # GNOME dynamic triple buffering (huge performance improvement)
  #       # See https://gitlab.gnome.org/GNOME/mutter/-/merge_requests/1441
  #       src = final.fetchFromGitLab {
  #         domain = "gitlab.gnome.org";
  #         owner = "vanvugt";
  #         repo = "mutter";
  #         rev = "triple-buffering-v4-47";
  #         hash = "sha256-1VXEzKwzrqLCZby2oWxjclA08kPhxs/Om5N17qYeglM=";
  #       };

  #       preConfigure =
  #         let
  #           gvdb = final.fetchFromGitLab {
  #             domain = "gitlab.gnome.org";
  #             owner = "GNOME";
  #             repo = "gvdb";
  #             rev = "2b42fc75f09dbe1cd1057580b5782b08f2dcb400";
  #             hash = "sha256-CIdEwRbtxWCwgTb5HYHrixXi+G+qeE1APRaUeka3NWk=";
  #           };
  #         in
  #         ''
  #           cp -a "${gvdb}" ./subprojects/gvdb
  #         '';
  #     });
  #   })
  # ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Disables automatic login for the user.
  services.displayManager.autoLogin.enable = false;
  # flip the above to true and uncomment this to auto login
  # services.displayManager.autoLogin.user = "${user}";

  # # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;
}
