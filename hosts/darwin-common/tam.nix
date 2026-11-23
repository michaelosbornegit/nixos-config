{inputs, ...}: {
  imports = [inputs.tam.homeManagerModules.tam-macos];

  services.tam-macos.enable = true;
}
