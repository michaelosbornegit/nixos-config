{
  pkgs,
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
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Give Qt/KDE applications GNOME-aware theming and file dialog integration.
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita";
  };

  services.displayManager.gdm.autoSuspend = false;

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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Disable CUPS unless this host actually needs printing.
  services.printing.enable = false;

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

  # Enables automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  # flip the above to true and uncomment this to auto login
  services.displayManager.autoLogin.user = "${user}";
}
