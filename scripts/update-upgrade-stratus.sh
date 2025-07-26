#!/bin/bash

# This script is used to update and upgrade the Stratus system.

# For sudo 
sudo echo hi

sudo nix-collect-garbage -d

nix flake update

sudo nixos-rebuild switch --flake .#stratus

sudo reboot
