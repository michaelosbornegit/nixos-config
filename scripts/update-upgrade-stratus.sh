#!/bin/bash

# This script is used to update and upgrade the Stratus system.

# For sudo 
sudo echo hi

# Clean anything up to make sure we have enough space 
sudo nix-collect-garbage -d

nix flake update

sudo nixos-rebuild switch --flake .#stratus

# Delete old generations and optimize the store
sudo nix-collect-garbage -d
sudo nix-store --optimize

sudo reboot
