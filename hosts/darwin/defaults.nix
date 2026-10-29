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
    };

    # No dedicated nix-darwin option for this one.
    CustomUserPreferences.NSGlobalDomain.AppleMiniaturizeOnDoubleClick = false;

    dock = {
      autohide = true;
      tilesize = 47;
      mineffect = "scale";
      persistent-apps = [
        {app = "/Applications/Firefox.app";}
        {app = "/Applications/Slack.app";}
        {app = "/Applications/ChatGPT.app";}
        {app = "/Applications/Claude.app";}
        {app = "/Applications/Granola.app";}
        {app = "/Applications/Spotify.app";}
      ];
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
