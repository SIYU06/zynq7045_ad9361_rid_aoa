# 任务：Zynq-7045 + AD9361 Linux 实板启动与单设备 DOA 测向调试

## 一、当前状态与工程路径

用户已经完成 SD 卡启动文件复制，并将 SD 卡插入开发板。目前已连接 JTAG、UART、以太网和电源，准备进行真实上板调试。

工程根目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa`

请优先阅读已有两份工作报告：

- `10.27_12.38DOA估计.md`
- `10.27_22.20DOAlinux启动.md`

已知关键路径：

**Linux 启动文件：**

`F:\2026fpga\openwifi_linux_boot_20261027_2220\sd_card`

其中包含：

- `BOOT.BIN`
- `uImage`
- `system.dtb`
- `uEnv.txt`

配套说明：

`F:\2026fpga\openwifi_linux_boot_20261027_2220\README.md`

**现有 DOA 工程：**

`F:\2026fpga\zynq7045_ad9361_rid_aoa\linux_doa`

主要文件：

- `linux_doa.c`：Linux 实时 IQ 数据读取及 DOA 程序入口。
- `doa.c/.h`：双通道互相关测相、相位校正和方向角计算。
- `run_doa.sh`：启动 DOA 测向。
- `Makefile`：程序编译。
- `README.md`：部署与使用说明。

**已有 Linux 驱动：**

- `ow/linux/driver`
- `ow/linux/runtime`
- `openwifi/linux/an_openwifi_pl.dtsi`
- `openwifi/linux/an_xc7z045_rf.dtsi`

硬件实现：

`dma_project/dma_project.runs/impl_txiq_cdc_1708`

本轮不重新综合、布局布线或生成 Bitstream。

## 二、本轮目标

在真实 Zynq-7045 + AD9361 开发板上，尽可能完成：

1. Linux 从 SD 卡启动。
2. AD9361 和 DMA 等必要设备正常初始化。
3. Linux 获取 RX1、RX2 双通道真实 IQ。
4. 运行现有 DOA 程序，输出相位差与方向角。
5. 进行一次必要的已知方向标定和实际角度观察。

最终目标：

AD9361 双通道 IQ → FPGA DMA → PS Linux → DOA 相位差计算 → 单设备方向角输出。

本轮不开发双站 AOA、不向电脑回传 DOA、不接入 Web 地面站、不处理 RID。

## 三、执行顺序

### 第一阶段：检查串口与 Linux 启动

1. 查找当前可用的串口设备及现有串口工具，优先使用 UART 115200 8N1。
2. 在可访问串口的情况下，读取真实启动日志，确定 FSBL、U-Boot、Linux 内核分别运行到哪一步。
3. 确认 U-Boot 是否成功读取 `uEnv.txt`、`uImage` 和 `system.dtb`。
4. 确认第二分区 ext4 根文件系统能否正常挂载。
5. 如果启动失败，根据实际日志定位首个阻塞问题，只做必要修复。

已知 `BOOT.BIN` 中使用复用的 U-Boot 2018.01，`uImage` 标记为 Linux 5.15.0-175919-g427c94e8faa，默认根文件系统为 `/dev/mmcblk0p2`。

此前报告说明当前启动方式不要求 `boot.scr`，不要在没有日志依据的情况下重新制作启动文件。

如果第二分区根文件系统缺失，先明确报告；只有找到可确认兼容的 rootfs 后才进行部署，不要随意采用其他板型的根文件系统。

如果当前环境无法直接访问物理串口或开发板，明确给出用户需要执行的最少操作及需要返回的日志，不要假装已经完成上板测试。

### 第二阶段：验证 Linux 硬件与驱动

Linux 启动后，重点确认：

- AD9361 是否正常识别、初始化及锁相。
- AXI DMA0 是否正常识别。
- `side_ch` 是否正常加载。
- Linux 是否具备实际读取双通道 IQ 的接口。

已有裸机系统完成过双通道 IQ 经 DMA 写入 DDR 的测试，本轮直接复用这部分成果，不重新开发或反复测试裸机链路。

现有 DOA 程序使用 side_ch 的 Linux DMAEngine/netlink 数据通路，优先检查并复用已有驱动。

如果内核模块需要编译，必须与当前运行内核版本和 ABI 匹配；不要强制加载不兼容模块。

不要把物理 DDR 地址直接作为 Linux 用户态指针访问。

### 第三阶段：运行现有 DOA 程序

先确认程序能够在当前 ARM Linux 环境中编译、运行。

现有 IQ 数据格式：

- 每个采集窗口 32776 字节。
- 前 8 字节为 TSF。
- 后续为 4096 组双通道 IQ。
- 每组数据为 `int16 I0、Q0、I1、Q1`，小端格式。

已有驱动参数：

`iq_len_init=4096 iq_dual_init=1`

优先使用：

`linux_doa/run_doa.sh`

如有必要，使用当前 Linux 环境交叉编译已有 `linux_doa`，不要重写 DOA 算法。

成功读取真实 IQ 后，输出：

- RX1/RX2 幅度。
- 原始相位差。
- 校正后的相位差。
- 双通道相关性。
- DOA 方向角。
- 必要的有效性指标。

已知参考命令：

`./linux_doa --live --samples 4096 --windows 16 --rf-hz 2437000000 --spacing-m 0.050 --calibrate-angle-deg 0`

其中 `0.050 m` 只是此前报告中的示例天线间距，不能直接当作真实参数。

如果还没有准确的天线相位中心间距和通道标定值，先输出原始相位差及诊断结果，明确标注未经标定的角度。

本轮优先完成真实数据输入和 DOA 输出，不要求马上达到最终测向精度。

## 四、执行效率与限制

**本轮强调效率，严格控制 Token 消耗。**

- 优先使用已有报告和准确路径，不全面扫描仓库。
- 不写过度防御性代码、不增加无关异常处理和复杂抽象。
- 不重复开发 IQ 采集、DMA 和 DOA 算法。
- 不反复进行同样的测试。
- 每个阶段只进行必要的检查，发现问题再针对性修复。
- 不反复重启设备或重新生成启动镜像。
- 不做无关的仿真、综合、布局布线。
- 不修改 Vivado、RTL、XDC 或现有 Bitstream。
- 对 SD 卡写入、分区格式化或重建启动镜像等可能破坏现有部署的操作，先确认目标及必要性。
- 不执行 Git add、commit、push，不上传远端仓库。
- 不开发其他功能。

遇到无法立即解决的硬件阻塞，保留日志和已有成果，明确指出需要用户进行的操作，不要无限尝试。

## 五、工作报告

**将本轮执行报告直接续写在本提示词文件末尾，不另建重复报告。**

报告只记录：

1. Linux 实际启动到了哪个阶段。
2. UART、SD、AD9361、DMA 和 side_ch 的真实状态。
3. DOA 程序是否成功编译及运行。
4. 是否读取到真实双通道 IQ。
5. 实际 DOA 输出结果及是否完成标定。
6. 修改的必要文件。
7. 当前阻塞及下一步最短操作。

严格区分已完成、未完成和等待用户操作的事项。

不要粘贴大量重复日志，保留关键错误及必要证据即可。

完成单设备 DOA 上板调试目标后停止。

---

## 六、2026-10-29 实板执行报告

### 1. Linux、UART 与 SD 启动状态

- 已通过 `COM9`、115200 8N1 直接操作真实开发板，板端进入 `root@analog` shell；最终已恢复终端回显。
- Linux 已完整进入用户空间：`Linux analog 5.15.0-175919-g427c94e8faa5`，设备树型号为 `AN XC7Z045 AD9361 OpenWiFi`。
- 根文件系统从 `/dev/mmcblk0p2` 正常挂载为 ext4；容量约 28 GiB，已用约 8.6 GiB，可用约 18 GiB。由此确认 FSBL、U-Boot、内核、DTB 和 SD 根文件系统启动链均已实际通过。
- 启动日志中仍有 SPI NOR `mtdblock` 读/擦除错误，以及以太网 `Could not attach PHY (-19)`；它们未阻断 SD 启动和本轮 UART 调试。主机有线网卡也未形成链路，因此本轮文件传输使用 UART，并逐文件校验 SHA256。

### 2. AD9361、DMA 与 PL 驱动真实状态

- IIO 实际枚举：`ad9361-phy`、`xadc`、`cf-ad9361-dds-core-lpc`、`cf-ad9361-lpc`；内核日志确认 `AD936x Rev 0 successfully initialized`。
- 板上内核原配置未启用 `CONFIG_XILINX_DMA`，根文件系统也没有与当前内核匹配的模块目录。已从板端 `/proc/config.gz` 取得配置，使用 ADI Linux 精确提交 `427c94e8faa57cb224bd40f1a0c8fe25168be2e5` 完整构建 `Module.symvers`，再构建模块。生成模块的 `vermagic` 均为：
  `5.15.0-175919-g427c94e8faa5 SMP preempt mod_unload modversions ARMv7 p2v8`。
- `xilinx_dma.ko` 已真实加载；`80400000.dma`、`80410000.dma` 均绑定 `xilinx-vdma`，新增 `dma1chan0/1`、`dma2chan0/1`。日志确认两个 `Xilinx AXI DMA Engine Driver Probed!!`。
- `rx_intf.ko`、`openofdm_rx.ko` 已加载并分别绑定 `83c20000.rx_intf`、`83c30000.openofdm_rx`，两者 `hw_init err 0`。
- `side_ch.ko iq_len_init=4096 iq_dual_init=1` 已加载并绑定 `83c50000.side_ch`，成功取得 `dma1chan1`，日志为 `DMA channel setup successfully`、`init_side_channel() err 0`。
- RF 已使用仓库内锁定的 OpenWiFi FIR 完成初始化并回读确认：RX/TX 采样率 `40000000`、FIR 使能为 `1`、RX LO `2436999998 Hz`、RX1/RX2 手动增益均为 `46 dB`。
- 当前内核 `CONFIG_CFG80211` 未启用，因此完整 `sdr.ko`/mac80211 监控接口不能与本内核安全构建；本轮没有强行加载不兼容无线栈，而是用最小 RX 链完成双路 IQ 实采。

### 3. DOA 程序编译和运行

- DOA 算法原有主机单元测试通过：`bias_deg=22.999958`、`bearing_deg=29.999991`、`coherence=1.000000`。
- Ubuntu 交叉编译出的用户程序依赖较新的 GLIBC，板端检查发现不兼容后未强行运行；随后使用板上自带 GCC 对现有 `linux_doa.c + doa.c` 原生编译，成功生成并运行 `/root/doa_stage/linux_doa.board`。算法本身未重写。
- 实际寄存器诊断确认本板双路 IQ RTL 使用 `reg22` 作为 IQ 数据计数：`reg22=8192`，而上游旧路径 `reg20=0`；同时 `reg3=0x11`、`reg12=4096`、`reg2=4097`。Linux side_ch 已按裸机验证序列，仅在 `iq_dual_init=1` 时读取 reg22，并在 DMA 描述符 pending 后对 reg5 产生一次 `1→0` 有限采集脉冲。

### 4. 真实双通道 IQ 与 DOA 结果

- 已从真实 AD9361 RX1/RX2 经 FPGA side_ch、AXI DMA、Linux DMAEngine/netlink 读取窗口；每窗 32776 字节，包含 8 字节 TSF 和 4096 组 `I0/Q0/I1/Q1`。
- 首个成功窗口：RX1/RX2 RMS 幅度 `9942.981566 / 5186.251096`，原始相位差 `44.412890°`，相关度 `0.930683`，相关度 SNR 代理 `11.280 dB`。
- 16 次独立窗口实采中，12 次输出完整结果、4 次被现有算法判为子段不可解而拒绝；这 16 次期间 DMA/netlink 持续工作。完整输出窗口的相关度范围约 `0.109781–0.992086`，说明当前现场信号和通道幅度一致性仍不稳定。
- 最高相关度窗口：RX1/RX2 RMS 幅度 `6913.727066 / 12654.952932`，原始相位差 `65.488829°`，相关度 `0.992086`，SNR 代理 `20.981 dB`。
- 使用示例间距 `0.050 m`、相位偏置 `0°` 时，该最高相关度窗口给出诊断角 `26.587813°`，标准差 `2.090841°`，标志 `0x09`。该角度只用于证明计算链已运行，不是已标定真实方位。

### 5. 标定状态

- **未完成真实方位标定。** 当前没有获得实测天线相位中心间距，也没有确认一个处于阵列已知角度的稳定窄带/同频信号源，因此没有把提示词中的 `0.050 m` 示例和零相位偏置当作真实参数。
- 已完成标定前所需的真实双通道 IQ、原始相位、相关度、幅度和诊断角输出。下一步必须先测量真实阵元相位中心间距，并把稳定信号源放在已知方位（建议阵列正前方 0°），再运行 `--calibrate-angle-deg` 得到固定通道相位偏置。

### 6. 必要修改和生成物

- `ow/linux/driver/side_ch/side_ch.c`：增加 Linux 5.15 `.remove` 兼容返回值；修正释放通道时的空指针判断；双路 IQ 模式读取 reg22，并按已验证裸机序列产生有限采集脉冲。
- `ow/linux/driver/side_ch/side_ch.h`：增加本板双路 IQ 数据计数寄存器 22 定义。
- `ow/linux/driver/rx_intf/rx_intf.c`、`ow/linux/driver/openofdm_rx/openofdm_rx.c`：增加 Linux 5.15 `.remove` API 兼容。
- 构建/诊断产物保存在 `F:\2026fpga\tmp\doa_kernel_427c94`；板端临时部署保存在 `/root/doa_stage`。没有替换内核、DTB、BOOT.BIN 或 bitstream，没有写 SD 启动分区，没有修改 Vivado/RTL/XDC，也没有执行 Git add/commit/push。

### 7. 当前结论与最短下一步

- **已完成：** Linux 实板启动、AD9361 初始化、精确 ABI DMA/PL 驱动加载、40 MSPS RF 初始化、真实 RX1/RX2 IQ 读取、原始相位/相关度/未标定 DOA 输出。
- **未完成：** 真实天线几何参数输入、已知方位相位标定和标定后角度精度验证。
- **最短下一步：** 用户提供/测量阵元相位中心间距，并将稳定 2.437 GHz 信号源置于已知方位；保持当前板端模块和 RF 状态不变，先采集多窗求相位偏置，再用该偏置复测实际角度。
