{
  lib,
  pkgs,
  user,
  ...
}: {
  # overwrite some things for darwin
  home.homeDirectory = "/Users/${user}";

  # Copy .app bundles instead of symlinking them so Spotlight/Launchpad index them
  # (copyApps only defaults on from stateVersion 25.11).
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps.enable = true;

  home.activation = {
    # Free Cmd-Space for Raycast (set Raycast's own hotkey to it in Raycast).
    # Done here rather than in system.defaults: nix-darwin would rewrite the
    # whole AppleSymbolicHotKeys dict and wipe every other shortcut change.
    spotlightShortcutOff = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
        '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
      run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    # Seed Loop's trigger key and window shortcuts on a Mac that has none yet.
    # Only once: later changes made in Loop's settings aren't overwritten. To
    # save new shortcuts back to the repo, re-export with the command in
    # dotfiles/.config/loop/README.md.
    loopShortcuts = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if ! /usr/bin/defaults read com.MrKai77.Loop keybinds >/dev/null 2>&1; then
        run /usr/bin/defaults import com.MrKai77.Loop ${../../dotfiles/.config/loop/loop.plist}
      fi
    '';
  };

  home.packages = with pkgs; [
    # utilities
    coreutils-prefixed
    gh
    scrcpy

    # apps
    # ghostty, loop, postman, firefox, raycast: Homebrew casks (hosts/darwin-common/homebrew.nix)
    # warp-terminal
    # windsurf
    # use these through npm
    # codex
    # claude-code
  ];
}
