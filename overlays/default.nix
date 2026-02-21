# This file defines overlays
{inputs, ...}: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs final.pkgs;

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev:
    # Temporary workaround:
    # microsoft-edge 145.0.3800.58 was removed upstream by Microsoft,
    # causing 404s in nixpkgs rev 0182a361324364ae3f436a63005877674cf45efb.
    # Upstream nixpkgs fix: https://github.com/NixOS/nixpkgs/pull/492598
    if prev ? microsoft-edge
    then let
      version = "145.0.3800.70";
    in {
      microsoft-edge = prev.microsoft-edge.overrideAttrs (_old: {
        inherit version;
        src = final.fetchurl {
          url = "https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/microsoft-edge-stable_${version}-1_amd64.deb";
          hash = "sha256-gUyh9AD1ntnZb2iLRwKLxy0PxY0Dist73oT9AC2pFQI=";
        };
      });
    }
    else {};

  # Optional fallback set for explicit stable package pinning.
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
