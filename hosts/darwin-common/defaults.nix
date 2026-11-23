{user, ...}: {
  # Required for system.defaults: they apply to this user, not root.
  system.primaryUser = user;

  # Touch ID for sudo (also covers the osupgrade alias).
  security.pam.services.sudo_local.touchIdAuth = true;

  system.defaults = {
    NSGlobalDomain = {
      # Faster key repeat than the System Settings sliders allow.
      InitialKeyRepeat = 30;
      KeyRepeat = 12;
      # Natural scrolling off.
      "com.apple.swipescrolldirection" = false;
      # Light mode, never switching automatically (Light itself is set in
      # darwin-common/home.nix: this option can only turn Dark on).
      AppleInterfaceStyleSwitchesAutomatically = false;
    };

    # No dedicated nix-darwin options for these.
    CustomUserPreferences.NSGlobalDomain = {
      AppleMiniaturizeOnDoubleClick = false;
      # Appearance > Liquid Glass: Tinted.
      NSGlassTintAmount = 1;
      NSGlassBuddyTintAmount = 0.5;
    };

    dock = {
      autohide = true;
      tilesize = 47;
      mineffect = "scale";
      # persistent-apps is set per Mac, in each host's configuration.nix.
    };

    finder.FXPreferredViewStyle = "Nlsv"; # list view

    # Screenshots go to the clipboard instead of a file.
    screencapture.target = "clipboard";

    menuExtraClock = {
      ShowDayOfWeek = true;
      ShowAMPM = true;
      ShowDate = 0; # when space allows
    };
  };
}
