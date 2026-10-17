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

  # Give Qt/KDE applications GNOME-aware theming and file dialog integration.
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita";
  };

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
    # gnome-terminal MYEDIT keep
    gnome-tour
    hitori # sudoku game
    iagno # go game
    tali # poker game
    # totem # video player MYEDIT keep
  ];

  security.rtkit.enable = true;

  services = {
    # Enable the X11 windowing system.
    xserver = {
      enable = true;
      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };
      # Enable touchpad support (enabled default in most desktopManager).
      # libinput.enable = true;
    };

    # Enable the GNOME Desktop Environment.
    displayManager = {
      gdm = {
        enable = true;
        autoSuspend = false;
      };
      # Enables automatic login for the user.
      autoLogin = {
        enable = true;
        user = "${user}";
      };
    };
    desktopManager.gnome.enable = true;

    # Disable CUPS unless this host actually needs printing.
    printing.enable = false;

    # Enable sound with pipewire.
    pulseaudio.enable = false;
    pipewire = {
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
  };
}
