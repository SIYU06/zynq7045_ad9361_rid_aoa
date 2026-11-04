# 任务：打通 Zynq-7045 + AD9361 单设备 Linux 启动与 DOA 测向

## 一、工程位置与已有线索

工程根目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa`

上一轮报告提供的工程线索：

- Vivado 工程候选：`dma_project/dma_project.xpr`
- OpenWiFi BD 候选：`ow/board/src/system.bd`
- 顶层模块：`system_top`
- 约束文件线索：`board.xdc`、`openwifi_timing.xdc`
- OpenWiFi IP 配置目录：`ow/board/src/ip/`
- 已发现 IP 配置：`system_auto_pc_0.xci`、`system_auto_pc_1.xci`、`system_auto_pc_2.xci`、`system_auto_pc_3.xci`

这些路径仅作为定位线索。优先检查本轮任务实际需要的文件，不要重新全面审计整个仓库。

## 二、本轮唯一目标

**完成单台 Zynq-7045 + AD9361 设备的 Linux 启动环境，并在 Linux 上运行 DOA 测向程序，输出方向角。**

本轮不做双站 AOA 融合，不做电脑端数据融合，不接入之前规划的 Web 地面站。

整体链路：

```text
AD9361 双通道接收
        ↓
FPGA / DMA 数据通路
        ↓
PS 端 Linux 读取双通道 IQ
        ↓
IQ 数据整理与通道相位差估计
        ↓
DOA 方位角计算
        ↓
输出相位差、方向角及必要的信号质量指标
```

## 三、任务一：准备 Linux 启动环境

检查当前工程中已有的 Linux 内核、设备树、根文件系统、U-Boot、FSBL、硬件描述文件及启动脚本，只处理本轮启动所必需的部分。

重点完成：

1. 确认当前硬件平台与 Linux 启动所需的硬件描述文件匹配。
2. 检查并补齐必要的设备树配置，重点关注 DDR、串口、SD 启动、AD9361 相关外设及实际使用的 DMA/AXI 数据通路。
3. 复用现有 FSBL、U-Boot、内核及根文件系统，缺什么再补什么。
4. 按当前工程实际采用的启动方式，准备完整的启动文件及 SD 卡目录结构，包括必要的 `BOOT.BIN`、内核、设备树、根文件系统等文件。
5. 提供清晰的 SD 卡部署步骤、启动命令和串口日志观察方法。

不要默认所有文件都必须重新编译。如果现有产物可用，优先复用。

如果缺少必要的硬件描述文件、内核源码或板级参数，明确指出具体缺项，不要猜测配置值，也不要为了生成启动文件而随意修改 FPGA 设计。

## 四、 任务二：复用现有 IQ → DDR → PS 链路，在 Linux 上运行 DOA

现有工程已经完成 AD9361 双通道 IQ 采集、DMA 写入 DDR，以及裸机 PS 读取 DDR 的验证。本轮不得将这条链路视为从零开发。

先阅读现有裸机 IQ 采集工程及其 DMA 初始化、DDR 缓冲区、数据格式和地址配置，复用已有成果。

重点完成：

1. 确认现有 FPGA Bitstream、DMA 配置及 IQ 缓冲区地址。
2. 检查 Linux 启动后如何访问现有 DMA 数据通路，优先复用现有驱动或最小化补齐必要的 Linux DMA/内存映射接口。
3. 明确处理 DDR 缓冲区的内存映射、缓存一致性和 DMA 所有权，不要直接假设裸机地址可作为 Linux 指针使用。
4. 让 Linux 程序读取 RX1、RX2 的真实 IQ 数据，并调用已有 DOA 算法输出相位差和方位角。

不要重新编写已经完成的裸机采集程序，不要重新验证整条裸机链路，也不要为了 Linux 读取数据而无必要地修改 FPGA 硬件设计。

## 五、DOA 算法开发与交付

本轮目标是完成 DOA 算法开发，并准备好后续在 Linux 上运行的程序，**不要求本轮实际启动 Linux 或完成上板测向验证**。

1. 优先复用已有双通道 AOA 仿真、相位差估计和通道相位标定代码，只提取单设备 DOA 所需部分。
2. 读取现有 IQ 采集工程，确认 RX1、RX2 的数据格式、通道排列、采样率及 DDR 缓冲区组织方式。
3. 编写 Linux 下可运行的 DOA 程序，完成双通道 IQ 读取接口、相位差计算、方位角估计及结果输出。
4. 尽量复用现有 DMA 数据通路。若 Linux 端缺少必要的 DMA 驱动或内存映射接口，只补齐后续运行所必需的部分，不重写已经完成的裸机采集程序。
5. 输出必要的诊断指标：有效样本数、双通道幅度、相位差、相关性和方位角。
6. 可以使用已有仿真或少量已知数据验证算法的计算逻辑，但不要进行大量重复仿真，也不要把仿真结果描述为真实硬件测向结果。

交付时应明确标出需要真实 Linux 环境才能确认的部分，特别是 DMA 数据读取、缓存一致性及实际测向精度。

## 六、本轮工作边界

本轮只要求完成以下交付：

- Linux 启动所需的配置、设备树及必要文件准备。
- 可供用户部署到 SD 卡的启动文件及清晰的部署说明。
- Linux 下单设备 DOA 程序及其必要的数据读取接口。
- DOA 算法的必要验证、启动命令和输出格式说明。
- 一份简洁的工作报告，列明完成情况和上板后仍需验证的项目。

**本轮不要求 Codex 自动烧写 SD 卡、启动开发板、运行真实硬件测向或验证最终角度精度。** 这些操作由用户部署 SD 卡并启动 Linux 后进行。

以下任务留到后续：

- 双设备 DOA 结果回传与电脑端 AOA 融合。
- Web 地面站接入。
- OpenWiFi RID 解调链路。
- 与本轮无关的 FPGA 时序修复和工程重构。



## 七、执行效率与 Token 要求

- 先阅读现有项目中与 Linux 启动、设备树、AD9361、DMA、DOA 算法有关的文件和报告。
- 只检查必要目录，不进行全仓库审计。
- 先形成简短实施计划，再直接执行。
- 不写过多防御性代码，不做复杂抽象，不添加本轮用不到的功能。
- 不反复构建、重复仿真或长时间运行无关测试。
- 优先复用已有代码、驱动、配置和构建产物。
- 不要为了让启动成功而随意修改硬件设计。
- 未经用户要求，不执行 Git add、commit、push，不上传远端代码库。
- 不要修改或删除无关工程文件。
- 不要求等待开发板连接，不因缺少上板环境而停止文件准备。
- 完成上述交付后停止，不扩展到双站 AOA 或网页功能。


## 八、交付要求

完成后提供简洁、准确的工作报告，包括：

1. Linux 启动文件准备情况，以及哪些文件复用、哪些文件新建或修改。
2. 设备树、内核、根文件系统和启动配置的实际状态。
3. DOA 程序的文件位置、输入数据来源和启动命令。
4. DOA 算法复用了哪些现有代码，输出哪些指标。
5. 已经实际完成的构建、仿真或硬件验证，以及对应结果。
6. 尚未完成的步骤和具体原因。
7. SD 卡部署与首次启动的操作顺序。

工作报告续写在本文档的后续，避免重复粘贴大量日志。

完成单设备 Linux + DOA 目标后立即停止，不要自行继续开发双站 AOA 或网页功能。

---

## 执行结果：单设备 Linux DOA 文件准备（2026-10-27）

**结论：Linux 单设备 DOA 用户态程序、双通道 IQ 读取接口、相位标定流程和 SD 部署骨架已经完成；当前仓库缺少本板完整基础设备树、匹配内核 ABI/内核镜像、根文件系统和本板 U-Boot，且现有 OpenWiFi bitstream 尚未完成时序签核，因此不能生成或声称已有可启动 Linux SD 发布包。** 本轮没有修改 FPGA、BD、XDC 或既有驱动，没有烧写 SD 卡、启动开发板，也没有把裸机 `BOOT.BIN` 冒充 Linux 启动文件。

### 1. Linux 启动文件准备情况

已复用和确认：

- 硬件候选：`dma_project/dma_project.runs/impl_latch_1103/system_top.bit`，SHA256 为 `adde8209bff291b124351e42075cd2df4bc823d05c84d06cf7628dae5669101a`；该实现的既有记录仍为 WNS -0.641 ns、外部 I/O delay 缺项，故标记为**不可发布候选**。
- XSA 候选：`dma_project/system_wrapper_v2.xsa`，SHA256 为 `8a92dc61d6201c2479cb87b556676089a4094498aeefe8c146155742c75f8bf8`；没有找到由它生成并与 Linux 成套验证的 FSBL/DTB。
- 设备树片段：`openwifi/linux/an_openwifi_pl.dtsi` 和 `an_xc7z045_rf.dtsi`；前者描述两个 AXI DMA、OpenWiFi IP 地址/中断和 side_ch DMA 绑定，后者只补本板时钟及 AD9361 属性，不是完整基础 DTS。
- Linux 派生驱动和运行脚本：`ow/linux/driver`、`ow/linux/runtime`。side_ch 使用 Linux DMAEngine 映射/同步并通过 netlink 把数据交给用户态，不需要直接映射裸机 DDR 地址。

新建 `linux_doa/boot_manifest.json`，记录候选哈希、禁止误用的裸机 BOOT.BIN 和发布前全部缺项；新建 `linux_doa/sd_card/README.md`，定义最终 FAT32 启动分区与 ext4 根分区布局。未创建虚假的空白内核、DTB 或 BOOT.BIN。

### 2. 设备树、内核、根文件系统和启动配置状态

| 项目 | 实际状态 |
|---|---|
| DDR、UART、SD 启动 | 只有 XSA/裸机 FSBL 线索，缺少已核对的本板 Linux 基础 DTS；不能猜测板级参数。 |
| AD9361 | 有 RF 增量片段和 OpenWiFi 初始化脚本；完整 SPI、ADI ADC/DDS 节点仍依赖匹配基础树。 |
| DMA/OpenWiFi PL | 本板增量 DTS 已准备，地址为 DMA0 `0x80400000`、DMA1 `0x80410000`、side_ch `0x83c50000`；尚未在真实 Linux 启动中探测。 |
| Linux 内核 | `openwifi/sources.lock.json` 中 commit/config/release 均为 `null`；仓库没有匹配构建树、`.config`、`Module.symvers` 和板端 `uname -r`。 |
| U-Boot | 仅有其他官方板型的 U-Boot，不能用于本板 XC7Z045。 |
| rootfs/内核镜像 | 当前工程未找到可与本板硬件及驱动 ABI 配套的产物。 |
| BOOT.BIN | `baremetal_iq/.../BOOT.BIN` 是裸机 IQ 采集应用，已明确排除；没有生成 Linux BOOT.BIN。 |

### 3. DOA 程序位置、输入和命令

新增目录 `zynq7045_ad9361_rid_aoa/linux_doa/`：

- `linux_doa.c`：Linux netlink 实时读取及离线文件读取、数据去直流、诊断指标和命令行入口；
- `doa.c/.h`：单设备互相关测相、相位偏置校正、角度换算和分段标准差；
- `run_doa.sh`：检查参数、按双路模式加载匹配 `side_ch.ko` 并连续运行；
- `Makefile`、`test_doa.c`：构建和定向自检；
- `README.md`：编译、标定、运行、部署及上板待验证项。

实时输入复用 OpenWiFi side_ch：每窗先是8字节小端 TSF，再是4096组小端 `int16 I0/Q0/I1/Q1`，共32776字节。驱动参数为 `iq_len_init=4096 iq_dual_init=1`。程序不直接访问物理 DDR。

编译：

```sh
cd /opt/doa
make clean all CC=arm-linux-gnueabihf-gcc
make test CC=arm-linux-gnueabihf-gcc
```

先用已知角度源标定（间距必须换成实测相位中心间距）：

```sh
./linux_doa --live --samples 4096 --windows 16 \
  --rf-hz 2437000000 --spacing-m 0.050 --calibrate-angle-deg 0
```

记录稳定的 `phase_bias_deg` 后运行：

```sh
export DOA_ANTENNA_SPACING_M=0.050
export DOA_PHASE_BIAS_DEG=<本机同频点标定值>
./run_doa.sh
```

命令中的 `0.050` 仅演示参数格式，不是本板已确认天线间距。

### 4. 算法复用和输出指标

算法取自 `v3_two_station_doa/doa.c` 的**单站部分**，未带入双站 UDP/交会定位；其数学定义与 `uav-rf-aoa/v2_phase_calibration` 一致：互相关得到 `phase(RX2)-phase(RX1)`，扣除已知角度标定出的固定通道偏置，再按 `asin(lambda*phase/(2*pi*d))` 换算阵列前半平面方位角。Linux 前端增加四分量去直流，复用现有 side_ch 数据格式。

每窗输出：TSF、有效样本数、RX1/RX2 AC 复数 RMS、原始和校正相位、归一化相关性、相关性 SNR 代理值、方位角、8段角度标准差及有效/低相关标志。SNR 字段明确是相关系数换算的诊断量，不是经标定 RF SNR。

### 5. 已完成的构建与验证

- 使用本机 GCC 以 `-std=c11 -Wall -Wextra -Werror -pedantic -O2` 编译算法自检及完整程序的离线分支，均无警告/错误。
- 定向合成 IQ 自检通过：固定通道偏置输入22.999958°，估计30°目标得到29.999991°，相关性1.000000，角度分段标准差0.000026°。这是计算逻辑验证，不是真实硬件精度。
- 用已有真实 DDR/JTAG 窗口 `baremetal_iq/captures/real_20261025_2203/verified_iq_0001.bin` 验证32776字节解析及输出链；成功读取4096组样本并输出幅度、相位、相关性和角度字段。该窗口未做天线间距/相位标定，结果不作为测向结论。
- 当前机器未找到 ARM Linux 交叉编译器，故没有声称完成 ARM ELF 构建；没有内核构建树，故未编译 `.ko`；没有执行 Linux 启动或真实 DOA 上板测试。

### 6. 尚未完成及原因

1. **可启动 Linux 发布包未完成：** 缺少本板基础 DTS、U-Boot、内核构建/ABI、rootfs；这些值不能从其他板型猜测或混用。
2. **硬件发布未签核：** 现有 bitstream 有已记录的建立时序违例和外部接口约束缺口，不能作为最终 Linux 发布硬件。
3. **实时 DMA/netlink 未上板确认：** 源码正确使用 DMA API 处理映射和缓存一致性，但仍需实际内核驱动探测、取数和丢窗检查。
4. **实际角度精度未确认：** 物理左右天线映射、相位中心间距、频率/温度/增益/重启后的偏置及多径误差都需要真实 Linux 环境和已知方向信号验证。

### 7. SD 卡部署与首次启动顺序

1. 先完成 OpenWiFi 实现时序/外部接口签核，导出最终 XSA/bit，并从该 XSA 重新生成 FSBL。
2. 提供或构建本板 U-Boot、完整基础 DTS、内核镜像和 rootfs；将两个现有 DTSI 按说明合并，编译 DTB。锁定内核 commit、`.config`、`Module.symvers`、`uname -r`。
3. 用同一内核构建 AD9361/ADI/Xilinx DMA/OpenWiFi/side_ch 模块；交叉编译 `linux_doa`，核对所有文件 SHA256 和模块 vermagic。
4. 生成匹配的 `BOOT.BIN`。FAT32 分区放 `BOOT.BIN`、内核、`system.dtb` 和实际 U-Boot 所需启动脚本；ext4 分区解包 rootfs，并放入 `/opt/openwifi`、`/opt/doa` 和 `/lib/modules/<uname-r>`。
5. 设置 SD 启动，连接串口，保存 FSBL→U-Boot→kernel 完整日志；先确认 DDR、SD、AD9361 IIO、两个 AXI DMA 和 OpenWiFi 节点探测正常。
6. 执行匹配的 `ow/linux/runtime/start_rx.sh`，随后加载双路 side_ch；先跑已知角度标定，再运行 DOA。核对双路幅度、相关性、相位符号、天线映射及丢窗后，才评估真实角度精度。

本轮到此停止，未扩展双站 AOA、PC 融合或 Web 功能。
