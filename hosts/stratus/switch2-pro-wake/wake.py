"""Wake a Nintendo Switch 2 Pro Controller (USB 057e:2069) once and exit.

Over USB the pad sends no input until the host sends a vendor init sequence
on its bulk interface 1. The sequence is SDL3's (SDL_hidapi_switch2.c, zlib
licence), except that it asks for report format 9: the report the pad's HID
descriptor describes, so the kernel's hid-generic driver turns it into a
normal evdev gamepad that browsers and games can read. The init lasts until
the pad is unplugged.

Usage: switch2-pro-wake [SYSFS_NAME...]   e.g. switch2-pro-wake 1-13.3
With no names it wakes every Switch 2 Pro Controller it finds. It claims
interface 1 only for the length of the sequence, then releases it and closes
the device, so Chrome's WebUSB wake, Steam or the Road Trip runtime can open
it afterwards. Re-sending the sequence to a pad that is already awake is
harmless.
"""

import sys
import time

import usb.core
import usb.util

VENDOR = 0x057E
PRODUCT = 0x2069
INTERFACE = 1
REPORT_FORMAT_HID_GAMEPAD = 0x09
# How long to keep trying after the pad enumerates: it can take a moment
# before it is found, can be claimed, or answers on the bulk endpoint.
DEADLINE_S = 10.0
RETRY_S = 0.5
ACK_TIMEOUT_MS = 250

# Each command is cmd[5] + 8 bytes; the pad acks each on the bulk IN endpoint.
INIT_SEQUENCE = [
    [0x07, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
    # feature output bit mask
    [0x0C, 0x91, 0x00, 0x02, 0x00, 0x04, 0x00, 0x00, 0x27, 0x00, 0x00, 0x00],
    [0x11, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
    [0x0A, 0x91, 0x00, 0x08, 0x00, 0x14, 0x00, 0x00, 0x01,
     0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
     0x35, 0x00, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
    # enable feature output
    [0x0C, 0x91, 0x00, 0x04, 0x00, 0x04, 0x00, 0x00, 0x27, 0x00, 0x00, 0x00],
    [0x01, 0x91, 0x00, 0x0C, 0x00, 0x00, 0x00, 0x00],
    [0x01, 0x91, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00],
    # grip buttons
    [0x08, 0x91, 0x00, 0x02, 0x00, 0x04, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00],
    # report format
    [0x03, 0x91, 0x00, 0x0A, 0x00, 0x04, 0x00, 0x00,
     REPORT_FORMAT_HID_GAMEPAD, 0x00, 0x00, 0x00],
    # start output
    [0x03, 0x91, 0x00, 0x0D, 0x00, 0x08, 0x00, 0x00,
     0x01, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF],
    # player 1 light, so the LEDs stop flashing
    [0x09, 0x91, 0x00, 0x07, 0x00, 0x08, 0x00, 0x00,
     0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
]


def log(msg):
    print(f"switch2-pro-wake: {msg}", file=sys.stderr, flush=True)


def sysfs_address(name):
    """Bus and device number of /sys/bus/usb/devices/NAME."""
    base = f"/sys/bus/usb/devices/{name}"
    with open(f"{base}/busnum") as b, open(f"{base}/devnum") as d:
        return int(b.read()), int(d.read())


def find(name):
    if name is None:
        return list(usb.core.find(find_all=True,
                                  idVendor=VENDOR, idProduct=PRODUCT))
    try:
        bus, addr = sysfs_address(name)
    except OSError:
        return []
    dev = usb.core.find(idVendor=VENDOR, idProduct=PRODUCT,
                        bus=bus, address=addr)
    return [dev] if dev is not None else []


def endpoints(dev):
    """Bulk OUT and IN endpoint addresses of the vendor interface."""
    out_ep, in_ep = 0x02, 0x82
    try:
        intf = dev.get_active_configuration()[(INTERFACE, 0)]
        for ep in intf:
            attr = usb.util.endpoint_type(ep.bmAttributes)
            if attr != usb.util.ENDPOINT_TYPE_BULK:
                continue
            if usb.util.endpoint_direction(ep.bEndpointAddress) \
                    == usb.util.ENDPOINT_IN:
                in_ep = ep.bEndpointAddress
            else:
                out_ep = ep.bEndpointAddress
    except (usb.core.USBError, KeyError, IndexError):
        pass
    return out_ep, in_ep


def wake(dev):
    """Send the init sequence once. Returns the number of acks seen."""
    detached = False
    claimed = False
    try:
        if dev.is_kernel_driver_active(INTERFACE):
            dev.detach_kernel_driver(INTERFACE)
            detached = True
        out_ep, in_ep = endpoints(dev)
        usb.util.claim_interface(dev, INTERFACE)
        claimed = True
        acks = 0
        for cmd in INIT_SEQUENCE:
            dev.write(out_ep, bytes(cmd[: cmd[5] + 8]), timeout=1000)
            try:
                dev.read(in_ep, 64, timeout=ACK_TIMEOUT_MS)
                acks += 1
            except usb.core.USBTimeoutError:
                pass
        return acks
    finally:
        if claimed:
            try:
                usb.util.release_interface(dev, INTERFACE)
            except usb.core.USBError:
                pass
        if detached:
            try:
                dev.attach_kernel_driver(INTERFACE)
            except usb.core.USBError:
                pass
        usb.util.dispose_resources(dev)


def wake_target(name):
    label = name or "057e:2069"
    deadline = time.monotonic() + DEADLINE_S
    last_error = "not found"
    while True:
        devs = find(name)
        if devs:
            failed = 0
            for dev in devs:
                where = f"bus {dev.bus} device {dev.address}"
                try:
                    acks = wake(dev)
                except usb.core.USBError as e:
                    last_error = f"{where}: {e}"
                    failed += 1
                    continue
                if acks == 0:
                    # Written but never answered: not ready yet.
                    last_error = f"{where}: no acks"
                    failed += 1
                    continue
                n = len(INIT_SEQUENCE)
                log(f"woke {label} ({where}, {acks}/{n} acks)")
            if failed == 0:
                return True
        if time.monotonic() >= deadline:
            log(f"could not wake {label}: {last_error}")
            return False
        time.sleep(RETRY_S)


def main():
    names = sys.argv[1:] or [None]
    ok = all([wake_target(n) for n in names])
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
