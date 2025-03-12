# nixos-config
My Nixos config files

Based on [nix-starter-configs by Misterio77](https://github.com/Misterio77/nix-starter-configs)

And inspired by [Baitinq's nixos-config](https://github.com/Baitinq/nixos-config)

```
// switch
sudo nixos-rebuild switch --flake .#stratus

// update
nix flake update

// clean old versions
sudo nix-collect-garbage -d
```
