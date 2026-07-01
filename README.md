# meta-alientek

正点原子 **i.MX6U-MINI (i.MX6ULL)** 开发板的 Yocto 板级支持层 (BSP layer)。

基于 NXP EVK 配置 (`meta-freescale` 的 `imx6ullevk`)，**只叠加本板差异**，产出可复现固件：
上电从 SD 自动启动 → 内核 6.1 → 带板载 LED/KEY → 网卡 eth0 可用。

## 适用

- 板子：正点原子 I.MX6U-MINI V2.2（i.MX6ULL, 512MB DDR3, 8GB eMMC, PHY=SR8201F）
- Yocto：**kirkstone** (poky + meta-freescale)
- 依赖层：`core` (oe-core), `freescale-layer` (meta-freescale)

## 这个层做了什么（相对 EVK 的板级差异）

| 组件 | 文件 | 改动 |
|---|---|---|
| **MACHINE** | `conf/machine/imx6ull-alientek.conf` | `require imx6ullevk.conf`，只改 `KERNEL_DEVICETREE=imx6ull-alientek.dtb` |
| **内核设备树** | `recipes-kernel/linux/linux-fslc_%.bbappend` + `files/imx6ull-alientek.dts` | `#include` EVK dts，叠加本板硬件 |
| **U-Boot** | `recipes-bsp/u-boot/u-boot-fslc_%.bbappend` + `files/0001-default-boot-from-sd.patch` | 默认从 SD 启动（改 mmcdev/mmcroot/fdt_file） |

### 设备树 (`imx6ull-alientek.dts`) 叠加的内容

- **LED**：`myled` 节点 (GPIO1_IO03，低电平点亮) + `pinctrl_myled`
- **KEY**：`mykey` 节点 (GPIO1_IO18/UART1_CTS_B，按下接地) + `pinctrl_mykey`
- **禁 tsc**：让出 GPIO1_IO03 给 LED
- **网卡** (SR8201F on ENET2)：
  - `&fec2` 加 `phy-reset-gpios=<&gpio5 8>` + `phy-reset-post-delay=150`（复位后等 150ms）
  - `&iomuxc_snvs` 加 `pinctrl_enet2_reset`（SNVS_TAMPER8→GPIO5_IO08）
  - `&ethphy1` 改通用 PHY (`ethernet-phy-ieee802.3-c22`)
  - **禁 `spi-4`**：释放被 EVK 74HC595(使能脚=GPIO5_IO8) 占用的复位脚（关键）
  - 禁 `fec1`（本板单网口只用 ENET2）
  - 纯设备树修复，6.1 无需 SION/C 补丁

### U-Boot 补丁 (`0001-default-boot-from-sd.patch`)

改 `include/configs/mx6ullevk.h` 默认环境：`mmcdev=0`(SD) / `mmcroot=/dev/mmcblk0p2` /
`fdt_file=imx6ull-alientek.dtb`，让 u-boot 默认从 SD 加载内核+dtb，上电即跑。

## 用法

```bash
# 1. 加层
bitbake-layers add-layer /path/to/meta-alientek

# 2. 设 MACHINE (build/conf/local.conf)
MACHINE = "imx6ull-alientek"

# 3. 构建
bitbake core-image-minimal

# 4. 烧录 (整卡镜像, 认准SD卡别写错盘!)
gunzip -c tmp/deploy/images/imx6ull-alientek/core-image-minimal-imx6ull-alientek.wic.gz \
  | sudo dd of=/dev/mmcblkX bs=4M conv=fsync && sync
```

## 已实测

- ✅ 上电从 SD 自动启动到 `imx6ull-alientek login:`（root 无密码）
- ✅ `/proc/device-tree/` 有 myled/mykey 节点
- ✅ `eth0: Link is Up - 100Mbps/Full`，ping 局域网 0% 丢包
