# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    inputs.slippi.homeManagerModules.default
    {
      # Point the launcher at your local Melee ISO; adjust if stored elsewhere.
      slippi-launcher.isoPath = "/home/${user}/Documents/Super Smash Bros. Melee (v1.02).iso";
    }
  ];

  home.homeDirectory = "/home/${user}";

  home.packages = with pkgs; [
    # packages
    gh
    jq # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    wireguard-tools # for Private Internet Access VPN https://github.com/pia-foss/manual-connections/
    esptool # for interacting with esp32 boards
    # apps
    microsoft-edge
    google-chrome
    discord
    scrcpy
    # prusa-slicer
    # mongodb-compass
    # code-cursor
    # windsurf
    appimage-run
    warp-terminal
    spotify
    # games/fun
    prismlauncher # for minecraft for fun
    parsec-bin
    # ollama-cuda # takes forever to install, so not included in normal builds
    vlc
    plex-desktop
    dolphin-emu
    ghostty
    gnomeExtensions.vitals
    gnomeExtensions.quick-settings-audio-panel
  ];

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  programs.vscode.profiles.default.extensions = pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    # MicroPico extension for esp32/pico w dev
    {
      name = "pico-w-go";
      publisher = "paulober";
      version = "4.2.1";
      sha256 = "sha256-0wa8nr/HVXe+y10u8HO1LU7+pT8iixoorUfchJP5uhw=";
    }
  ];

  # personal email
  programs.git.settings.user.email = "resonatortune@gmail.com";

  home.file = {
    ".config/mimeapps.list".source = ../../dotfiles/.config/mimeapps.list;
    ".config/mimeapps.list".force = true;
  };

  dconf.settings."org/gnome/shell" = {
    disable-user-extensions = false;
    enabled-extensions = [
      "Vitals@CoreCoding.com"
      "quick-settings-audio-panel@rayzeq.github.io"
    ];
  };

  dconf.settings."org/gnome/shell/keybindings" = {
    show-screenshot-ui = [
      "Print"
      "<Super><Shift>s"
    ];
  };

  dconf.settings."org/gnome/shell/extensions/vitals" = {
    show-temperature = false;
    show-voltage = false;
    show-fan = false;
    show-system = false;
    show-storage = false;
    show-network = false;
    show-battery = false;
    show-memory = true;
    show-processor = true;
    show-gpu = true;
    hot-sensors = [
      "_memory_usage_"
      "_processor_usage_"
      "_gpu#1_graphics_"
    ];
  };

  programs.zsh.shellAliases = {
    beammp = "${inputs.beammp.apps.${pkgs.system}.beammp.program}";
    beammp-doctor = "${inputs.beammp.apps.${pkgs.system}.beammp-doctor.program}";
    beammp-link = "${inputs.beammp.apps.${pkgs.system}.beammp-link.program}";
    beammp-proton = "${inputs.beammp.apps.${pkgs.system}.beammp-proton.program}";
    melee = "nix run github:lytedev/slippi-nix#slippi-launcher";
    roblox = "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
              flatpak install flathub org.vinegarhq.Sober && \
              flatpak update && \
              flatpak run org.vinegarhq.Sober";
    gopher64 = "flatpak install -y flathub io.github.gopher64.gopher64 && \
                flatpak run io.github.gopher64.gopher64";
  };
}
