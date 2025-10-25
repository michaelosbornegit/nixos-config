#!/bin/bash

# This script is used to update and upgrade the Stratus system.
# if on a clean install you will need to append --extra-experimental-features nix-command --extra-experimental-features flakes
# NOTE MAKE SURE TO UPDATE hardware-configuration.nix ON A FRESH INSTALL

# For sudo 
sudo echo hi

# Clean anything up to make sure we have enough space 
sudo nix-collect-garbage -d

nix flake update

sudo nixos-rebuild switch --flake .#stratus

# Delete old generations and optimize the store
sudo nix-collect-garbage -d

# only needed occasionally to save space
# sudo nix-store --optimize

sudo reboot
