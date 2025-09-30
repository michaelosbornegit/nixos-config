#!/bin/bash

# This script is used to update and upgrade the darwin system.

# For sudo 
sudo echo hi

sudo nix-collect-garbage -d

nix flake update

sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#darwin

sudo nix-collect-garbage -d
sudo nix-store --optimize

sudo reboot
