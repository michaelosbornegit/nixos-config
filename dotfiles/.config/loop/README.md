# Loop

`loop.plist` holds Loop's trigger key and window shortcuts. Each Mac's first
rebuild imports it if Loop has no shortcuts yet (see
`hosts/darwin-common/home.nix`); after that, Loop's own settings win.

After changing shortcuts in Loop, save them back here:

```bash
f=dotfiles/.config/loop/loop.plist
defaults export com.MrKai77.Loop "$f"
for k in $(plutil -convert json -o - "$f" | nix-shell -p jq --run "jq -r 'keys[] | select(. != \"keybinds\" and . != \"trigger\" and . != \"patchesApplied\")'"); do plutil -remove "$k" "$f"; done
plutil -convert xml1 "$f"
```
