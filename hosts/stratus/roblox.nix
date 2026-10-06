# Roblox via Sober (Flatpak): one launcher command per experience, plus a
# generator that writes the matching .desktop entries and icons into
# ~/.local/share. The generator needs the network (Roblox thumbnail/game APIs),
# so it runs from a user timer rather than at activation; offline it falls back
# to the hard-coded names.
{
  lib,
  pkgs,
  user,
  ...
}: let
  flatpak = "${pkgs.flatpak}/bin/flatpak";
  # Flatpak 1.18 leaks NixOS's host PATH into flatpak-spawn subsandboxes.
  # Sober's glycin image loader expects FHS paths there, including /usr/bin.
  flatpakRun = "env PATH=/usr/bin:/bin ${flatpak}";
  robloxExperienceApplicationDir = "/home/${user}/.local/share/applications";
  robloxExperienceIconDir = "/home/${user}/.local/share/icons/hicolor/512x512/apps";
  robloxExperiences = {
    fishos = {
      command = "roblox-fishos";
      desktopId = "roblox-fishos";
      fallbackName = "FISH.OS";
      fallbackComment = "Launch FISH.OS in Sober";
      icon = "roblox-fishos";
      placeId = "123368132872113";
      keywords = [
        "fish"
        "fishos"
        "fish.os"
        "fishing"
        "roblox"
        "sober"
      ];
    };
    petSimulator = {
      command = "roblox-pet-simulator";
      desktopId = "roblox-pet-simulator";
      fallbackName = "Pet Simulator 99";
      fallbackComment = "Launch Pet Simulator 99 in Sober";
      icon = "roblox-pet-simulator";
      placeId = "8737899170";
      keywords = [
        "pets"
        "pet simulator"
        "pet sim"
        "ps99"
        "roblox"
        "sober"
      ];
    };
  };
  robloxExperiencePlaceIds =
    lib.concatStringsSep ","
    (map (experience: experience.placeId) (lib.attrValues robloxExperiences));
  robloxExperienceUpdater = pkgs.writeShellApplication {
    name = "roblox-refresh-experiences";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gnused
      jq
    ];
    text = ''
      application_dir=${lib.escapeShellArg robloxExperienceApplicationDir}
      icon_dir=${lib.escapeShellArg robloxExperienceIconDir}
      mkdir -p "$application_dir"
      mkdir -p "$icon_dir"
      rm -f "$application_dir/roblox-pets.desktop"

      desktop_escape() {
        printf '%s' "$1" \
          | tr '\r\n' '  ' \
          | sed 's/[[:cntrl:]]//g; s/\\/\\\\/g'
      }

      thumbnail_response="$(
        curl --fail --silent --show-error --location \
          ${lib.escapeShellArg "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=${robloxExperiencePlaceIds}&size=512x512&format=Png&isCircular=false"} \
          || true
      )"

      universe_ids=""
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: experience: ''
          universe_id="$(
            curl --fail --silent --show-error --location \
              ${lib.escapeShellArg "https://apis.roblox.com/universes/v1/places/${experience.placeId}/universe"} \
              | jq --raw-output '.universeId // empty' \
              || true
          )"
          if [ -n "$universe_id" ]; then
            if [ -n "$universe_ids" ]; then
              universe_ids="$universe_ids,$universe_id"
            else
              universe_ids="$universe_id"
            fi
          fi
        '')
        robloxExperiences)}

      games_response='{"data":[]}'
      if [ -n "$universe_ids" ]; then
        games_response="$(
          curl --fail --silent --show-error --location \
            "https://games.roblox.com/v1/games?universeIds=$universe_ids" \
            || printf '{"data":[]}'
        )"
      fi

      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (_: experience: ''
          image_url="$(
            printf '%s' "$thumbnail_response" \
              | jq --raw-output --arg target ${lib.escapeShellArg experience.placeId} \
                '.data[] | select((.targetId | tostring) == $target) | select(.state == "Completed") | .imageUrl' \
              | head -n 1 \
              || true
          )"
          if [ -n "$image_url" ] && [ "$image_url" != "null" ]; then
            tmp="$icon_dir/${experience.icon}.png.tmp"
            if curl --fail --silent --show-error --location "$image_url" --output "$tmp"; then
              mv "$tmp" "$icon_dir/${experience.icon}.png"
            else
              rm -f "$tmp"
            fi
          fi

          raw_name="$(
            printf '%s' "$games_response" \
              | jq --raw-output --arg place ${lib.escapeShellArg experience.placeId} \
                '.data[] | select((.rootPlaceId | tostring) == $place) | .name // empty' \
              | head -n 1 \
              || true
          )"
          if [ -z "$raw_name" ] || [ "$raw_name" = "null" ]; then
            raw_name=${lib.escapeShellArg experience.fallbackName}
          fi

          name="$(desktop_escape "$raw_name")"
          comment="$(desktop_escape ${lib.escapeShellArg experience.fallbackComment})"
          keywords=${lib.escapeShellArg (lib.concatStringsSep ";" experience.keywords + ";")}

          {
            printf '%s\n' '[Desktop Entry]'
            printf '%s\n' 'Type=Application'
            printf '%s\n' 'Version=1.5'
            printf 'Name=%s\n' "$name"
            printf 'Comment=%s\n' "$comment"
            printf '%s\n' 'Exec=${experience.command}'
            printf '%s\n' 'Icon=${experience.icon}'
            printf '%s\n' 'Terminal=false'
            printf '%s\n' 'Categories=Game;'
            printf '%s\n' 'StartupNotify=true'
            printf '%s\n' 'PrefersNonDefaultGPU=true'
            printf 'Keywords=%s\n' "$keywords"
          } >"$application_dir/${experience.desktopId}.desktop"
        '')
        robloxExperiences)}
    '';
  };
  robloxSoberLaunchScript = experience: ''
    ${robloxExperienceUpdater}/bin/roblox-refresh-experiences >/dev/null 2>&1 || true
    ${flatpak} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ${flatpak} install -y flathub org.vinegarhq.Sober
    exec ${flatpakRun} run --command=sober org.vinegarhq.Sober ${lib.escapeShellArg "roblox://placeId=${experience.placeId}"}
  '';
in {
  home.packages =
    [robloxExperienceUpdater]
    ++ lib.mapAttrsToList (_: experience: pkgs.writeShellScriptBin experience.command (robloxSoberLaunchScript experience)) robloxExperiences;

  # Refresh a minute after login, then weekly. When a switch adds or changes the
  # timer, it fires right away (the startup delay has already elapsed), so that
  # refresh runs in the background instead of blocking the switch on the network.
  systemd.user.services.roblox-refresh-experiences = {
    Unit.Description = "Refresh Roblox experience launchers (names and icons)";
    Service = {
      Type = "oneshot";
      ExecStart = "${robloxExperienceUpdater}/bin/roblox-refresh-experiences";
    };
  };
  systemd.user.timers.roblox-refresh-experiences = {
    Unit.Description = "Refresh Roblox experience launchers weekly";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "1w";
    };
    Install.WantedBy = ["timers.target"];
  };

  programs.zsh.shellAliases.roblox = "${flatpak} remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
              ${flatpak} install flathub org.vinegarhq.Sober && \
              ${flatpak} update && \
              ${flatpakRun} run org.vinegarhq.Sober";
}
