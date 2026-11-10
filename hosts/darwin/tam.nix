# TAM menu-bar collector, built on this Mac from the private tam flake (Xcode/CLT
# swift, ad hoc signed, installed to ~/Applications). osupdate bumps the lock;
# osupgrade rebuilds and relaunches TAM.app when the pinned source changed.
{inputs, ...}: {
  imports = [inputs.tam.homeManagerModules.tam-macos];

  services.tam-macos.enable = true;
}
