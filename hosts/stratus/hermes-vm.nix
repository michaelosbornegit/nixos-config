{
  lib,
  pkgs,
  ...
}: let
  domain = "ubuntu26 hermes";
  phoneVendor = "04e8";
  phoneProduct = "6860";
  phoneUsb = pkgs.writeText "hermes-phone-usb.xml" ''
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source startupPolicy='optional'>
        <vendor id='0x${phoneVendor}'/>
        <product id='0x${phoneProduct}'/>
      </source>
    </hostdev>
  '';
  shellBase = ''
    domain=${lib.escapeShellArg domain}
    phone_vendor=${lib.escapeShellArg phoneVendor}
    phone_product=${lib.escapeShellArg phoneProduct}
    virsh_uri=qemu:///system

    phone_usb_node() {
      local usb_device busnum devnum

      for usb_device in /sys/bus/usb/devices/*; do
        if [[ -r "$usb_device/idVendor" \
          && -r "$usb_device/idProduct" \
          && "$(<"$usb_device/idVendor")" == "$phone_vendor" \
          && "$(<"$usb_device/idProduct")" == "$phone_product" ]]; then
          busnum="$(<"$usb_device/busnum")"
          devnum="$(<"$usb_device/devnum")"
          printf '/dev/bus/usb/%03d/%03d\n' "$busnum" "$devnum"
          return 0
        fi
      done

      return 1
    }
  '';
  domainHasPhoneUsb = ''
    domain_has_phone_usb() {
      virsh --connect "$virsh_uri" dumpxml "$@" | awk \
        -v vendor="<vendor id='0x$phone_vendor'/>" \
        -v product="<product id='0x$phone_product'/>" '
          /<hostdev / {
            in_hostdev = 1
            found_vendor = 0
            found_product = 0
          }
          in_hostdev && index($0, vendor) { found_vendor = 1 }
          in_hostdev && index($0, product) { found_product = 1 }
          in_hostdev && /<\/hostdev>/ {
            if (found_vendor && found_product) {
              found = 1
            }
            in_hostdev = 0
          }
          END { exit !found }
        '
    }
  '';
  phoneMtpUri = ''
    phone_mtp_uri() {
      local phone_device

      phone_device="$(phone_usb_node)" || return 1
      gio mount -li | awk -v device="$phone_device" '
        /^[^[:space:]]/ { matching_device = 0 }
        index($0, "unix-device: \047" device "\047") {
          matching_device = 1
          next
        }
        matching_device && /^[[:space:]]+activation_root=mtp:\/\// {
          sub(/^[[:space:]]*activation_root=/, "")
          print
          exit
        }
      '
    }
  '';
  vmUp = pkgs.writeShellApplication {
    name = "hermes-vm-up";
    runtimeInputs = with pkgs; [
      android-tools
      coreutils
      gawk
      glib
      gnugrep
      libvirt
    ];
    text = ''
      ${shellBase}
      ${domainHasPhoneUsb}
      ${phoneMtpUri}

      state="$(virsh --connect "$virsh_uri" domstate "$domain")"
      phone_uri="$(phone_mtp_uri || true)"

      if [[ -n "$phone_uri" ]] && gio mount -l | grep -Fq -- "$phone_uri"; then
        echo "Releasing the Samsung phone from the host..."
        gio mount --unmount "$phone_uri"
        sleep 1
      fi
      adb kill-server >/dev/null 2>&1 || true

      if ! domain_has_phone_usb --inactive "$domain"; then
        virsh --connect "$virsh_uri" attach-device "$domain" \
          "${phoneUsb}" --config
      fi

      case "$state" in
        running)
          echo "$domain is already running."
          ;;
        paused)
          virsh --connect "$virsh_uri" resume "$domain"
          ;;
        "shut off")
          virsh --connect "$virsh_uri" start "$domain"
          ;;
        *)
          echo "Cannot start $domain from state: $state" >&2
          exit 1
          ;;
      esac

      if phone_usb_node >/dev/null; then
        if ! domain_has_phone_usb "$domain"; then
          virsh --connect "$virsh_uri" attach-device "$domain" \
            "${phoneUsb}" --live
        fi
        echo "Samsung phone is attached directly to $domain."
      else
        echo "$domain is running; the Samsung phone is not connected."
      fi
    '';
  };
  vmDown = pkgs.writeShellApplication {
    name = "hermes-vm-down";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      glib
      gnugrep
      libvirt
    ];
    text = ''
      ${shellBase}
      ${phoneMtpUri}

      state="$(virsh --connect "$virsh_uri" domstate "$domain")"

      case "$state" in
        "shut off")
          echo "$domain is already shut down."
          ;;
        running)
          virsh --connect "$virsh_uri" shutdown "$domain"
          ;;
        paused)
          virsh --connect "$virsh_uri" resume "$domain"
          virsh --connect "$virsh_uri" shutdown "$domain"
          ;;
        *)
          echo "Cannot gracefully stop $domain from state: $state" >&2
          exit 1
          ;;
      esac

      echo "Waiting up to 2 minutes for $domain to shut down gracefully..."
      for _ in $(seq 1 120); do
        state="$(virsh --connect "$virsh_uri" domstate "$domain")"
        if [[ "$state" == "shut off" ]]; then
          echo "$domain shut down cleanly."
          break
        fi
        sleep 1
      done

      if [[ "$state" != "shut off" ]]; then
        echo "$domain is still running; it was left alone to avoid data loss." >&2
        echo "Check the guest and retry instead of force-stopping it." >&2
        exit 1
      fi

      echo "Waiting up to 30 seconds for the Samsung phone to return to the host..."
      for _ in $(seq 1 30); do
        phone_uri="$(phone_mtp_uri || true)"
        if [[ -n "$phone_uri" ]]; then
          gio mount "$phone_uri" >/dev/null 2>&1 || true
          if gio mount -l | grep -Fq -- "$phone_uri"; then
            echo "Samsung phone is mounted on the host."
            exit 0
          fi
        fi
        sleep 1
      done

      echo "The VM stopped, but the Samsung phone did not mount on the host within 30 seconds." >&2
      exit 1
    '';
  };
in {
  environment.systemPackages = [
    vmDown
    vmUp
  ];

  systemd.services.hermes-vm-autostart = {
    description = "Enable autostart for the personal Hermes VM";
    wantedBy = ["multi-user.target"];
    after = ["libvirtd.service"];
    requires = ["libvirtd.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [
      coreutils
      gawk
      libvirt
    ];
    script = ''
      ${shellBase}
      ${domainHasPhoneUsb}

      virsh --connect "$virsh_uri" autostart "$domain"
      if ! domain_has_phone_usb --inactive "$domain"; then
        virsh --connect "$virsh_uri" attach-device "$domain" \
          "${phoneUsb}" --config
      fi
      if [[ "$(virsh --connect "$virsh_uri" domstate "$domain")" != "running" ]]; then
        virsh --connect "$virsh_uri" start "$domain"
      fi
      if phone_usb_node >/dev/null && ! domain_has_phone_usb "$domain"; then
        virsh --connect "$virsh_uri" attach-device "$domain" \
          "${phoneUsb}" --live
      fi
    '';
  };
}
