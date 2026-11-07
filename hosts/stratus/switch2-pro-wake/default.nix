# Wake the Nintendo Switch 2 Pro Controller (USB 057e:2069) whenever it is
# plugged in. Over USB it sends no input until the host sends a vendor init
# sequence; once it has, the kernel's hid-generic driver exposes it as a
# normal evdev gamepad, so Firefox, Chrome and native games see it without
# WebUSB or Steam. The wake is a one-shot that releases the device again, so
# WebUSB, Steam and the Road Trip runtime can still open it afterwards.
# `switch2-pro-wake` is also on PATH to re-wake a pad by hand.
{pkgs, ...}: let
  wake = pkgs.writers.writePython3Bin "switch2-pro-wake" {
    libraries = [pkgs.python3Packages.pyusb];
  } (builtins.readFile ./wake.py);
in {
  environment.systemPackages = [wake];

  # %k is the USB device's sysfs name (e.g. 1-13.3); the service turns it back
  # into this plug-in's bus and device number. A unit rather than RUN+=, since
  # the wake may wait a few seconds for the pad to answer.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="057e", ATTR{idProduct}=="2069", TAG+="systemd", ENV{SYSTEMD_WANTS}+="switch2-pro-wake@%k.service"
  '';

  systemd.services."switch2-pro-wake@" = {
    description = "Wake Switch 2 Pro Controller on USB %i";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${wake}/bin/switch2-pro-wake %i";
      TimeoutStartSec = 30;
      # Root, so it works before anyone logs in, but with nothing beyond the
      # USB device nodes and a read-only view of the system.
      DevicePolicy = "closed";
      DeviceAllow = ["char-usb_device rw"];
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateNetwork = true;
      NoNewPrivileges = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK"];
    };
  };
}
