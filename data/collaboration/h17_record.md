# 任务：准备 Zynq-7045 + AD9361 的 Linux SD 卡启动文件

## 一、工程目录与已知信息

主工程根目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa`

已知工程线索：

- Vivado 工程：`dma_project\dma_project.xpr`
- 顶层模块：`system_top`
- OpenWiFi BD：`ow\board\src\system.bd`
- 约束文件：`board.xdc`、`openwifi_timing.xdc`
- OpenWiFi IP：`ow\board\src\ip\`
- Vivado 版本：2022.2
- 本轮时序整改实现：`dma_project\dma_project.runs\impl_txiq_cdc_1708\`
- 独立构建及验证报告目录：`F:\2026fpga\openwifi_timing_fix_20261027_1708`

已有报告显示，`impl_txiq_cdc_1708` 已完成综合、布局布线，内部建立时间检查通过。本轮优先复用该实现结果，不重新跑布局布线。

用户目前已经有 `uImage` 和 `uEnv.txt`，具体位置需要从现有工作区确认。

## 二、本轮目标

只完成 Linux SD 卡启动文件准备，不开发 DOA、不修改 FPGA 时序、不开展新的硬件调试。

重点准备：

1. 与当前硬件设计匹配的设备树源文件及编译后的 `system.dtb`。
2. 启动所需的 `BOOT.BIN`。
3. 复用并核对现有 `uImage`、`uEnv.txt`、U-Boot、FSBL。
4. 整理可直接复制到 SD 卡的启动文件目录和部署说明。

## 三、执行步骤

### 1. 检查现有文件

只检查本轮需要的工程和启动文件，不做全面仓库审计。

确认以下文件是否存在、版本是否匹配：

- 当前硬件设计导出的 XSA，或其他能够生成匹配硬件描述的现有产物。
- 已完成布局布线的 `system_top_routed.dcp`。
- 对应的 `.bit` 文件。
- FSBL、U-Boot、`uImage`、`uEnv.txt`。
- 现有设备树源文件、DTB、根文件系统及启动脚本（如果有）。

### 2. 准备 Bitstream

优先使用：

`dma_project\dma_project.runs\impl_txiq_cdc_1708\`

如果其中已有与本次整改一致的有效 `.bit`，直接复用。

如果没有 `.bit`，检查已有 routed DCP，在不重新综合、不重新布局布线的前提下，尝试生成 Bitstream。

不要误用旧实现的 Bitstream，也不要覆盖唯一可用的旧版本。

### 3. 生成设备树

从当前 Vivado 工程导出与实际硬件设计匹配的 XSA；如果已有对应 XSA 且确认一致，则直接复用。

使用与现有 Vitis/Vivado 2022.2 环境兼容的设备树生成工具，生成基础设备树，再按实际硬件补充必要配置。

重点核对：

- DDR 地址和容量。
- PS UART、SD 控制器及实际启动设备。
- FPGA 中 AXI 外设、DMA 和中断。
- AD9361 相关硬件接口及其实际连接。
- Linux 所需的设备树节点与驱动兼容性。

不要凭空编造地址、时钟、IRQ 或 GPIO。缺少依据时，指出具体缺项。

输出设备树源文件和编译后的 `system.dtb`。

### 4. 生成 BOOT.BIN

根据当前 Zynq-7000 启动方式及已有 U-Boot 配置，确认实际需要的启动镜像组成。

如果采用常见的 Zynq FSBL 启动流程，通常需要将匹配的 FSBL、Bitstream 和 U-Boot 按正确顺序打包；最终组成以现有启动设计为准。

优先复用现有 FSBL 和 U-Boot。只有缺少或不匹配时才重新生成。

不要把 `uImage` 和 DTB 默认塞进 BOOT.BIN；先检查现有 U-Boot、`uEnv.txt` 和启动命令，确认它们是从 SD 卡独立加载，还是采用其他启动方式。

### 5. 整理 SD 卡文件

根据实际启动流程准备一个清晰的部署目录，包含所需的：

- `BOOT.BIN`
- `uImage`
- `system.dtb`
- `uEnv.txt`
- 根文件系统或其他确实必需的文件

给出 SD 卡分区要求、文件放置位置和部署顺序。没有必要的文件不要强行添加。

本轮只准备文件，不要求自动操作物理 SD 卡，也不要求上板启动测试。

## 四、执行限制

- 复用现有工程和产物，优先补齐缺失文件。
- 不重新综合、不重新布局布线、不重新排查时序。
- 不修改无关 RTL、XDC 或 DOA 算法。
- 不写过多防御性代码，不进行全面仓库审计，不反复构建。
- 只做必要的文件检查、设备树生成、镜像打包和结果核验。
- 如果缺少关键工具或输入文件，明确指出缺什么、在哪里受阻，不要编造成功结果。
- 不执行 Git add、commit、push，不上传远端仓库。

## 五、交付

将本轮工作报告续写到当前工作报告文件末尾，不另建重复报告。

报告简要列出：

1. 复用了哪些已有文件及其来源。
2. 新生成的设备树、DTB 和 BOOT.BIN 的实际路径。
3. 每个文件的用途及匹配依据。
4. SD 卡文件目录和具体部署步骤。
5. 尚未解决的问题，以及上板启动时需要观察的串口信息。

完成启动文件准备后停止，等待用户上板验证。

---

## 执行报告（2026-10-27）

### 1. 本轮结论

已完成 Linux SD 卡启动文件准备，交付目录为：

`F:\2026fpga\openwifi_linux_boot_20261027_2220\sd_card`

该目录只包含 `BOOT.BIN`、`uImage`、`system.dtb`、`uEnv.txt` 四个启动分区文件，清单、大小和 SHA-256 校验全部通过。当前状态为“文件已准备、等待实板启动验证”，不是“已经上板启动成功”。工作区内没有找到可交付的根文件系统镜像，因此还必须使用与现有 uImage 匹配的 ext4 第二分区。

本轮未重新综合、未重新布局布线，也未修改 RTL、XDC 或 DOA 算法。Bitstream 直接从已完成布线的 `impl_txiq_cdc_1708/system_top_routed.dcp` 生成。该实现报告为 WNS=0.559 ns、TNS=0、WHS=0.053 ns、THS=0，时序约束满足。

### 2. 硬件产物

- Bitstream：`F:\2026fpga\openwifi_linux_boot_20261027_2220\hardware\system_top.bit`
  - 6,393,892 bytes
  - SHA-256：`779E57B8342AE4AF5E33DDE7D00AE31EDF57AAB16FDCFA55EB3DAE7616D7578D`
- XSA：`F:\2026fpga\openwifi_linux_boot_20261027_2220\hardware\system_top_txiq_cdc_1708.xsa`
  - 389,226 bytes
  - SHA-256：`EAFEC5384678220756EB22DAA1DA0F4D636659731D10D86CA1CBD6D2F8F644B3`

Vivado 的直接 `write_bitstream` 已成功。由于从 routed DCP 直接写 bit 不会把运行调度状态更新为 “Bitstream Complete”，`write_hw_platform -include_bit` 被 Vivado 拒绝；随后导出了不内嵌 bit 的固定 XSA。实际 BOOT.BIN 使用上面独立且经过哈希确认的 bit 文件，不受此限制影响。

### 3. 设备树

- 源文件：`F:\2026fpga\openwifi_linux_boot_20261027_2220\device_tree\system.dts`
- 编译文件：`F:\2026fpga\openwifi_linux_boot_20261027_2220\device_tree\system.dtb`
- DTB SHA-256：`BA25360085B1597E0283E09D595F37720768208EB38A63689431E8ACEB485E6B`

Vitis 2022.2 自带 System Device Tree 生成器只正式支持 ZynqMP/Versal，其 Cortex-A9 路径先后在 `get_sw_cores` 和软件 OS 对象处失败，没有把空目录当作成功结果。最终以仓库内 OpenWiFi `zc706_fmcs2/devicetree.dts` 为完整、可追溯基线，再按当前 XSA 和已有定制片段逐项收敛：

- DDR：`0x00000000` 起始、`0x40000000` 大小，即 1 GiB。
- UART1：`0xE0001000`，MIO 48..49，115200。
- SD0：`0xE0100000`，MIO 40..45；SPI0：`0xE0006000`，EMIO；QSPI 保持启用。
- 当前 XSA 中禁用的 SPI1、USB0 在设备树中也改为 disabled。
- TX DMA：`0x80400000`，IRQ 35/36；RX DMA：`0x80410000`，IRQ 31/32；两者 `xlnx,sg-length-width=<23>`。
- `tx_intf`/`rx_intf`/`openofdm_tx`/`openofdm_rx`/`xpu`/`side_ch` 地址分别为 `0x83C00000`、`0x83C20000`、`0x83C10000`、`0x83C30000`、`0x83C40000`、`0x83C50000`。
- AD9361 保留已知 40 MHz 参考时钟、2RX2TX、LVDS、EMIO GPIO 98..102，并按定制片段设置 2.437 GHz 和 MGC。
- 与当前硬件不匹配的 ZC706 I2C 外设、按键/LED、AXI DMA test、MathWorks 节点和 HDMI 音频节点均禁用。

环境原先没有 `dtc`，因此从官方 Device Tree Compiler 仓库浅克隆源码到本任务目录并本地构建。`system.dtb` 已再次反编译为 `system.roundtrip.dts`，上述关键属性均在 DTB 回读结果中确认。编译只有源基线遗留的结构/数字 phandle 告警，没有语法错误，DTB 正常生成。

### 4. BOOT.BIN 组成与复用依据

- FSBL：复用 `baremetal_iq/workspace/iq_hw/export/iq_hw/sw/iq_hw/boot/fsbl.elf`。
  - 当前 XSA 与生成该 FSBL 的 `system_top_iq.xsa` 中 `ps7_init.c`、`ps7_init.h`、`ps7_init.tcl`、`ps7_init_gpl.c`、`ps7_init_gpl.h` 五项 SHA-256 全部一致，证明 DDR/MIO/PS 初始化未变化。
- Bitstream：使用本轮从 `impl_txiq_cdc_1708` routed DCP 生成的 `system_top.bit`。
- U-Boot：复用 `upstream/openwifi/kernel_boot/boards/zc706_fmcs2/u-boot.elf`，版本为 `U-Boot 2018.01-21439-gd244ce5`。
  - 该 ELF 明确包含 ADI 的 `uenvboot`、`kernel_image=uImage`、`devicetree_image=devicetree.dtb` 和 SD 加载流程；本轮 `uEnv.txt` 显式把 DTB 名称改为 `system.dtb`。
  - 没有选用 `linux_boot_custom/u-boot.elf`，因为它是通用 U-Boot 2022.01 distro-boot 配置，未发现与现有 ADI `uEnv.txt` 相同的默认 `uenvboot` 流程。

Bootgen 2022.2 生成：

`F:\2026fpga\openwifi_linux_boot_20261027_2220\sd_card\BOOT.BIN`

- 7,033,168 bytes
- SHA-256：`411DC2E0927D25E84B2B79839F4D4A82FE2E312A2F12EA78B9111FFBF6E93833`
- Bootgen 回读确认三个镜像顺序为 `fsbl.elf`、`system_top.bit`、`u-boot.elf`。
- 生成时出现 FSBL 与 bitstream memory range overlap 告警；bitstream 分区属于配置数据且 Bootgen 仍成功生成，回读出的三个 partition header 完整。

### 5. 现有 uImage 与 uEnv.txt

- `uImage` 来源：`F:\2026fpga\linux_boot_custom\uImage`
- uImage SHA-256：`031D37724655B4A96AADB5AEAAFCD720BAF6D728ACEA92A523CF439FCAEE9C81`
- uImage 头部：magic `0x27051956`，ARM Linux，名称 `Linux-5.15.0-175919-g427c94e8faa`，载入和入口地址均为 `0x00008000`，声明数据长度与文件实际 payload 一致。
- `uEnv.txt` 基于 `F:\2026fpga\tf_linux\first\uEnv.txt`，保留原 ADI 启动逻辑，并显式指定 `uImage`、`system.dtb`、FAT 分区 `mmc 0:1` 与 ext4 根分区 `/dev/mmcblk0p2`。

目录中不放置 ramdisk。`uramdisk.image.gz` 加载失败后，脚本按预期执行 `bootm 0x3000000 - 0x2A00000`，由内核挂载第二分区根文件系统。

### 6. SD 卡部署步骤

1. 第一分区使用 FAT32；第二分区使用 ext4。
2. 将 `F:\2026fpga\openwifi_linux_boot_20261027_2220\sd_card` 内四个文件原样复制到 FAT32 第一分区根目录，不改名，不需要 `boot.scr`。
3. 第二分区必须已有与 Linux 5.15.0-175919-g427c94e8faa 匹配的根文件系统；如果 OpenWiFi 驱动为模块，还必须有匹配该内核 ABI 的模块。
4. 板卡设置为 SD 启动，UART1 使用 115200 8N1，随后上电观察。

详细部署说明：`F:\2026fpga\openwifi_linux_boot_20261027_2220\README.md`；完整文件大小、哈希和验证状态：`F:\2026fpga\openwifi_linux_boot_20261027_2220\boot_manifest.json`。

### 7. 尚未解决、需上板观察

- 工作区没有根文件系统镜像，无法在本轮证明第二分区的用户态和内核模块 ABI 匹配。
- GEM0 在当前 XSA 中已启用，但外部 PHY 地址、复位连接和 RGMII 板级时序没有充分证据；本轮保留 OpenWiFi/ZC706 基线配置，但不能宣称以太网已验证。
- AD9361 的数字接口延迟与 PN 调谐仍需实板确认。
- 上板时依次观察：U-Boot 是否识别 `mmc 0`、是否导入 `uEnv.txt`、两个 `fatload` 是否成功、内核是否显示定制 model 和约 1 GiB DDR、`mmcblk0p2` 是否挂载、AD9361 与两路 AXI DMA/OpenWiFi 节点是否成功 probe。

启动文件准备到此停止，等待用户进行物理 SD 卡复制和上板验证。
