# OPZ4pandawifi

Make the Panda PAU0D wifi adapter (MT76x2U) work on Orange Pi Zero 4 with Debian Trixie Server.

## Installation

These steps target Debian GNU/Linux 13 (Trixie) arm64. Check that the board is running a 64-bit OS:

```bash
uname -m
dpkg --print-architecture
```

Expected results are `aarch64` and `arm64`. Install and setup the driver:

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/wereallmadhereblip/OPZ4pandawifi.git ~/OPZ4pandawifi
cd ~/OPZ4pandawifi
sudo bash setup-mt7612u.sh
```

The setup script installs the necessary build tools and kernel headers, then compiles and installs the MT7612U driver for the Panda wifi adapter.

After installation completes, reboot the board:

```bash
sudo reboot
```

Once rebooted, check that the wifi adapter is recognized:

```bash
lsusb | grep Panda
iwconfig
```

## Troubleshooting

If the driver does not load after reboot:

- Check the kernel logs:
  ```bash
  dmesg | grep -i mt76
  ```

- Verify the driver was installed:
  ```bash
  sudo find /lib/modules -name "*mt7612u*"
  ```

- Reinstall the driver:
  ```bash
  cd ~/OPZ4pandawifi
  sudo bash setup-mt7612u.sh
  sudo reboot
  ```
