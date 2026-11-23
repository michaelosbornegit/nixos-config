# osupgrade for Macs. A Mac's hostname can't be relied on to name its flake
# target (IT names the work Mac), so each Mac's config records its own target
# in ~/.config/nixos-config/host and osupgrade builds whatever that file says.
#
# The file only exists after a Mac's first switch, so osupgrade falls back to
# the LocalHostName, and if neither names a config it stops before sudo and
# says which targets exist and how to pick one: `osupgrade <target>`.
{
  config,
  pkgs,
  flakeHost,
  ...
}: let
  hostFile = "${config.xdg.configHome}/nixos-config/host";

  osupgrade = pkgs.writeShellApplication {
    name = "osupgrade";
    text = ''
      repo="$HOME/development/repos/nixos-config"
      host_file="${hostFile}"

      if [ "$#" -gt 1 ]; then
        echo "usage: osupgrade [target]" >&2
        exit 2
      fi

      if [ "$#" -eq 1 ]; then
        host="$1"
        from="the command line"
      elif [ -s "$host_file" ]; then
        host="$(tr -d '[:space:]' < "$host_file")"
        from="$host_file"
      else
        host="$(/usr/sbin/scutil --get LocalHostName)"
        from="this Mac's LocalHostName ($host_file doesn't exist yet)"
      fi

      cd "$repo"

      # Check the target before asking for sudo, so a wrong guess costs nothing.
      targets="$(nix eval --raw .#darwinConfigurations --apply 'c: builtins.concatStringsSep " " (builtins.attrNames c)')"
      case " $targets " in
        *" $host "*) ;;
        *)
          {
            echo "osupgrade: no Mac config named \"$host\" (from $from)."
            echo "This flake has: $targets"
            echo
            echo "Build the one for this Mac once and osupgrade will remember it:"
            echo "  osupgrade <target>"
          } >&2
          exit 1
          ;;
      esac

      # Fetch the locked inputs as you first: aut is a private repo and the root
      # rebuild has no git credentials. Offline, carry on with what's in the store.
      nix flake archive --no-update-lock-file >/dev/null || true
      sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#$host"
    '';
  };
in {
  xdg.configFile."nixos-config/host".text = "${flakeHost}\n";
  home.packages = [osupgrade];
}
