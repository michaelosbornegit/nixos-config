# TAM desktop collector, built locally from the private tam flake (same model as
# aut). osupdate bumps the lock, osupgrade builds the daemon and GNOME extension
# in the system closure; no GitHub release or signed manifest involved. The
# module installs tam-desktop on PATH, writes ~/.config/tam/config.toml and the
# user service, and enables the extension through programs.gnome-shell.
{inputs, ...}: {
  imports = [inputs.tam.homeManagerModules.default];

  services.tam-desktop.enable = true;
}
