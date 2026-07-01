English | [中文](README.md)

# meta-alientek

Yocto board support layer (BSP) for the **ALIENTEK i.MX6U-MINI (i.MX6ULL)** board.

Based on the NXP EVK config (`imx6ullevk` from `meta-freescale`), it **only overlays the
board-specific differences** to produce reproducible firmware:
power on → auto-boot from SD → kernel 6.1 → on-board LED/KEY → working `eth0`.

## Target

- Board: ALIENTEK I.MX6U-MINI V2.2 (i.MX6ULL, 512MB DDR3, 8GB eMMC, PHY = SR8201F)
- Yocto: **kirkstone** (poky + meta-freescale)
- Layer deps: `core` (oe-core), `freescale-layer` (meta-freescale)

## What this layer does (deltas vs. the EVK)

| Component | File | Change |
|---|---|---|
| **MACHINE** | `conf/machine/imx6ull-alientek.conf` | `require imx6ullevk.conf`, only override `KERNEL_DEVICETREE=imx6ull-alientek.dtb` |
| **Kernel device tree** | `recipes-kernel/linux/linux-fslc_%.bbappend` + `files/imx6ull-alientek.dts` | `#include` the EVK dts, overlay board hardware |
| **U-Boot** | `recipes-bsp/u-boot/u-boot-fslc_%.bbappend` + `files/0001-default-boot-from-sd.patch` | Default boot from SD (mmcdev/mmcroot/fdt_file) |

### Device tree (`imx6ull-alientek.dts`) overlays

- **LED**: `myled` node (GPIO1_IO03, active-low) + `pinctrl_myled`
- **KEY**: `mykey` node (GPIO1_IO18 / UART1_CTS_B, active-low) + `pinctrl_mykey`
- **Disable tsc**: free GPIO1_IO03 for the LED
- **Ethernet** (SR8201F on ENET2):
  - `&fec2`: add `phy-reset-gpios=<&gpio5 8>` + `phy-reset-post-delay=150` (wait 150ms after reset)
  - `&iomuxc_snvs`: add `pinctrl_enet2_reset` (SNVS_TAMPER8 → GPIO5_IO08)
  - `&ethphy1`: switch to generic PHY (`ethernet-phy-ieee802.3-c22`)
  - **Disable `spi-4`**: free the reset GPIO occupied by the EVK's 74HC595 (its enable pin = GPIO5_IO8) — the key fix
  - Disable `fec1` (this board has a single port, ENET2 only)
  - Pure device-tree fix; no SION/C patch needed on 6.1

### U-Boot patch (`0001-default-boot-from-sd.patch`)

Edits the default env in `include/configs/mx6ullevk.h`: `mmcdev=0` (SD) /
`mmcroot=/dev/mmcblk0p2` / `fdt_file=imx6ull-alientek.dtb`, so U-Boot loads the kernel + dtb
from the SD card by default and boots on power-up.

## Usage

```bash
# 1. add the layer
bitbake-layers add-layer /path/to/meta-alientek

# 2. set MACHINE (build/conf/local.conf)
MACHINE = "imx6ull-alientek"

# 3. build
bitbake core-image-minimal

# 4. flash (full-disk image — double-check the SD device, don't clobber the wrong disk!)
gunzip -c tmp/deploy/images/imx6ull-alientek/core-image-minimal-imx6ull-alientek.wic.gz \
  | sudo dd of=/dev/mmcblkX bs=4M conv=fsync && sync
```

## Verified

- ✅ Auto-boots from SD to `imx6ull-alientek login:` (root, no password)
- ✅ `/proc/device-tree/` has the myled/mykey nodes
- ✅ `eth0: Link is Up - 100Mbps/Full`, LAN ping 0% loss
