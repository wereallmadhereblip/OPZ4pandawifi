#!/usr/bin/env bash
set -euo pipefail

# Must be run as root
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run this script as root (e.g., sudo bash $0)"
  exit 1
fi

echo "[1/6] Enabling non-free-firmware repository and installing firmware-mediatek..."
if [[ -f /etc/apt/sources.list ]]; then
  sed -i -E 's/^(deb\s+.*\s+trixie[^\s]*\s+main)$/\1 non-free-firmware/' /etc/apt/sources.list
fi
if ls /etc/apt/sources.list.d/*.sources >/dev/null 2>&1; then
  sed -i -E 's/^(Components:\s*main)$/\1 non-free-firmware/' /etc/apt/sources.list.d/*.sources
fi

apt-get update -qq
apt-get install -y firmware-mediatek iw network-manager

echo "[2/6] Verifying MediaTek MT7662 firmware files..."
if [[ ! -e /lib/firmware/mt7662.bin || ! -e /lib/firmware/mt7662_rom_patch.bin ]]; then
  echo "ERROR: /lib/firmware/mt7662* firmware files were not found after installing firmware-mediatek."
  exit 1
fi

echo "[3/6] Configuring mt76x2u kernel module to auto-load at boot..."
echo "mt76x2u" > /etc/modules-load.d/mt76x2u.conf

echo "[4/6] Creating systemd service to force USB 2.0 mode (fixes Allwinner xHCI -110 timeout)..."
cat << 'EOF' > /etc/systemd/system/mt76x2u-usb2.service
[Unit]
Description=Force USB 2.0 mode on USB3 root port for MediaTek MT7612U
DefaultDependencies=no
Before=systemd-udev-trigger.service systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for p in /sys/bus/usb/devices/usb2/2-0:1.0/usb2-port*/disable; do [ -e "$p" ] && echo 1 > "$p"; done'
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

systemctl daemon-reload
systemctl enable mt76x2u-usb2.service

echo "[5/6] Creating udev rule to permanently rename MediaTek MT7612U interface to wlan1..."
cat << 'EOF' > /etc/udev/rules.d/70-mt7612u-wlan1.rules
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="mt76x2u", NAME="wlan1"
EOF
udevadm control --reload-rules

echo "[6/6] Applying USB 2.0 fallback, reloading mt76x2u, and renaming interface to wlan1..."
for p in /sys/bus/usb/devices/usb2/2-0:1.0/usb2-port*/disable; do
  if [[ -e "$p" ]]; then
    echo 1 > "$p"
  fi
done
sleep 2

modprobe -r mt76x2u 2>/dev/null || true
modprobe mt76x2u
sleep 2

# If udev still assigned a wlx* name to the mt76x2u interface, rename it to wlan1 right now
for iface in /sys/class/net/wlx*; do
  if [[ -e "$iface/device/driver" ]] && [[ "$(basename "$(readlink -f "$iface/device/driver")")" == "mt76x2u" ]]; then
    OLD_NAME="$(basename "$iface")"
    echo "Renaming $OLD_NAME to wlan1..."
    ip link set "$OLD_NAME" down
    ip link set "$OLD_NAME" name wlan1
    ip link set wlan1 up
  fi
done

echo "=== Setup Complete ==="
iw dev
