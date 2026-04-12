_: {
  # change gnome to my liking
  dconf.settings = {
    # IMPORTANT disable sleep, for some reason things break after sleep
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    # nautilus (file viewer) default to list mode
    "org/gnome/nautilus/preferences" = {
      default-folder-viewer = "list-view";
    };
    # nautilus (file viewer) default zoom to small
    "org/gnome/nautilus/list-view" = {
      default-zoom-level = "small";
    };
    "org/gnome/desktop/interface" = {
      # hot corners (mouse in corner opens overview) is annoying
      enable-hot-corners = false;
      # disable animations cause fairly usually clumsy and slow, specifically smooth scroll animations
      enable-animations = false;
    };
    "org/gnome/desktop/sound" = {
      # disable annoying sounds
      event-sounds = false;
      # allow GNOME's volume controls, including per-app sliders, to amplify above 100%
      allow-volume-above-100-percent = true;
    };
    "org/gnome/mutter" = {
      # enable drag to sides of screen tiling like in windows and elsewhere
      edge-tiling = true;
      # Enable dynamic workspaces so I can have infinite workspaces (the default of 4 is odd)
      dynamic-workspaces = true;
    };
    "org/gtk/gtk4/settings/file-chooser" = {
      # show hidden files in file chooser
      show-hidden = true;
    };
  };
}
