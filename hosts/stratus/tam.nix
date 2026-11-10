{inputs, ...}: {
  imports = [inputs.tam.homeManagerModules.default];

  services.tam-desktop.enable = true;
}
