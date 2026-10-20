# openwifi 移植修改记录

日期：2026-10-20。

**已按要求停止继续验证。本工程处于移植中间状态，尚未完成综合、实现、时序和上板测试，不能作为可下载的成品工程。**

## 1. 本次目标

直接在 `dma_project` 中移植 openwifi，由 Zynq PL 完成 Wi-Fi 解调，PS 负责配置射频、接收解调帧及 IQ。原始 IQ 侧通道供后续双通道分析/AOA 使用。

```text
AD9361 → ADI axi_ad9361 → rx_intf → openofdm_rx → 解调帧 → DMA → PS
                              └→ side_ch → 双通道 IQ → DMA → PS
```

保留 TX、XPU 等模块的接口和初始化依赖，新增顶层将外部 PA 使能固定关闭，作为接收移植起点。

## 2. 已查看并确认的内容

- 查看 `原理图png` 的射频接口、FPGA 引脚、PS MIO、时钟、DDR、网口等页面。
- 用户确认实物为 **XC7Z045**，沿用 `xc7z045fbg676-1`。原理图概览虽然写 XC7Z035，详细 FPGA 页也标有 XC7Z045。
- 已运行本机 Vivado，确认版本为 **2022.2**。
- 读取原 RF 工程的 LVDS 接口、AD9361 初始化代码和 PS 参数，以及 DMA 工程的 BD/XPR。
- 放大原理图确认 **RF_TXNRX 接 F14**；旧 RF 工程写成 H14，新约束已更正。H14 属于接收差分时钟对。
- 网口原理图为 **Marvell 88E1512**，RGMII 接 PS MIO，复位接 MIO8；实际 PHY 地址和时序尚未验证。

## 3. 已下载并锁定的源码

源码保存在 `upstream/`，准确记录见 [openwifi/sources.lock.json](openwifi/sources.lock.json)。

| 项目 | 提交 |
|---|---|
| openwifi-hw | `fa6c89687e4637f07adbfb41299056b6d18fd80e` |
| openwifi | `674995a130893bd9d0fe94d6ef0790ac8f43ec2a` |
| ADI HDL，2022_R2 | `7ea497b6c24172ee293d6e0a9a387a16973da5ce` |
| OpenOFDM | `2bb3ad1a1f0023bfd15168db4e196ebf0d56d76c` |

硬件仓库的 ADI gitlink 原为 `f61d9707...`，但官方构建脚本会切换到 `2022_R2`。本次按脚本要求选用后者，并记录了实际提交。以后仅运行默认 submodule update 不足以恢复本次 ADI 版本。

这是一组已锁定的候选源码，**尚未证明硬件、驱动和本板运行兼容**。Linux 源码提交、配置、运行版本和模块 ABI 尚未锁定，在 JSON 中标为未完成。

## 4. 新增的适配文件

手写文件位于 `openwifi/`：

| 文件 | 内容 |
|---|---|
| [prepare.py](openwifi/prepare.py) | 校验源码提交、生成构建副本和板级 PS 设置、备份原工程输入 |
| [windows_exec.tcl](openwifi/windows_exec.tcl) | 将上游部分 POSIX 文件操作改为 Windows 可运行的 Tcl 操作，限制修改范围在 `ow/` |
| [package.tcl](openwifi/package.tcl) | 打包 ADI 七个 IP 和 openwifi 六个 IP |
| [system_top.v](openwifi/system_top.v) | 本板 DDR/MIO、AD9361 LVDS、SPI、GPIO 顶层适配 |
| [board.xdc](openwifi/board.xdc) | 本板 RF 引脚、IO 电平及接收接口时钟约束 |
| [retarget.tcl](openwifi/retarget.tcl) | 将参考 BD 改成本板 PS 参数，移除无用外部接口，固定未使用输入 |
| [build.tcl](openwifi/build.tcl) | 修改原 XPR、接入 BD、生成 wrapper 和报告，提供后续综合/实现入口 |
| [sources.lock.json](openwifi/sources.lock.json) | 工具、器件、依赖提交与未完成项 |

新增顶层保留上游 GPIO 编号，例如 reset 为 EMIO46/Linux GPIO100。**旧裸机初始化程序的 GPIO 映射不能直接沿用。**

## 5. 构建副本与板级设置

`ow/` 是生成目录，上游下载源码与构建改动分开保存：

```text
ow/ip/                    openwifi/OpenOFDM 构建副本
ow/adi-hdl/               ADI 构建副本
ow/board/src/system.bd    从 ZC706+FMCOMMS2 结构派生的 BD
ow/board/src/system_top.v 本板顶层副本
ow/board/src/board.xdc    本板约束副本
ow/board/ps_settings.tcl  本板 PS 设置
ow/board/ip_repo/         已打包 openwifi IP
```

使用 ZC706+FMCOMMS2 的模块连接作结构参考，没有使用其比特流或 FMC 引脚约束。

已在生成副本中增加 `an_xc7z045` 板型，选择大 FPGA 配置、100 MHz 基带和 side_ch。处理了 Windows shell 命令及版本号查询。ADI 打包按显式文件列表加入源文件，关闭本机曾卡住的自动 include 扫描。

PS 参数来源于原 RF 工程，并按原理图配置 UART1、SD0、SPI0 EMIO、64 位 EMIO GPIO、1.8V PS IO bank 和 GEM0 RGMII。网口目标设置为千兆，尚未证明实物链路可用；DDR 板级延时继承现有工程，未独立校准。

接收时钟约束按 **40 MSPS、2R2T、160 MHz LVDS 接口时钟**设置，仍需与后续驱动配置和实测核对。

## 6. 已完成的构建步骤

已生成以下 IP 的 `component.xml`：

- openwifi：`openofdm_rx`、`openofdm_tx`、`rx_intf`、`tx_intf`、`xpu`、`side_ch`。
- ADI：`axi_ad9361`、`util_cpack2`、`util_upack2`、`util_wfifo`、`util_rfifo`、`util_tdd_sync`、`util_clkdiv`。

日志见 [package_openwifi.log](openwifi/package_openwifi.log) 和 [package_adi.log](openwifi/package_adi.log)。

**IP 打包完成不等于综合、时序或许可证验收通过。Viterbi 授权及评估限制尚需确认。**

已开始修改原项目 `dma_project/dma_project.xpr`：登记新的 `ow/board/src/system.bd`，加入 ADI 和 openwifi 的 IP 仓库路径。

第二轮 Vivado 已应用本板 PS 参数并进入 BD 输出生成；日志显示多个模块完成生成。用户要求停止时脚本尚在执行，因此当前只能记录为中间状态。最后查看 XPR 时顶层仍是 `system_wrapper`，新 `system_top.v` 和 XDC 尚未完成最终登记步骤。

不要将日志里单个模块的 `Generation completed` 理解为整套工程通过。日志保存在 [build_validate.log](openwifi/build_validate.log)。

## 7. 备份

已保存修改前输入，目录为 `baseline_before_openwifi/`：

```text
baseline_before_openwifi/dma_project.xpr
baseline_before_openwifi/dma_project.srcs/sources_1/bd/system/system.bd
baseline_before_openwifi/sha256.json
```

这是 XPR、BD 及校验记录，**不是整个项目的完整备份**。原有 bit/XSA 不是本次 openwifi 移植产物。

## 8. 当前问题与未完成事项

| 内容 | 状态 |
|---|---|
| ADI 缺少项目 Tcl、Windows include 扫描停滞 | 已在构建副本处理，七个 IP 后续打包完成 |
| 复制 PS 派生 GUI 参数造成 Tcl 错误 | 已缩小为实际 DDR/MIO/外设配置，第二轮进入输出生成 |
| 未连接输入警告 | 最新 retarget.tcl 增加显式固定值，尚未重新运行验证 |
| 禁用 SPI1 后参考 BD 遗留端口/网络 | 已看到无源警告，尚需清理并核对 wrapper |
| AXI ID 宽度连接警告 | 尚未完成分析和综合检查 |
| 移除旧项目子设计文件的警告 | 最新 build.tcl 改为先移除父 BD，尚未重新运行验证 |
| 新顶层、约束登记及完整 BD 验收 | 未完成 |
| 综合、实现、DRC、时序、bitstream、新 XSA | 未完成 |
| 本板设备树、内核补丁、驱动编译及运行 | 未完成 |
| Linux 冷启动、网口、SPI、射频接口校准 | 未上板验证 |
| 已知 Wi-Fi 包解码及 FCS | 未验证 |
| 双通道 IQ 同步、窗口、丢样及相位校准 | 未验证 |

WSL 中已确认存在 Ubuntu-22.04、ARM GCC 和 dtc，但没有编译 Linux 软件。没有生成新的本板设备树，没有修改 SD 启动文件，也没有烧写板卡。

## 9. 停止位置

后续从 `openwifi/` 的脚本和日志继续即可，不必重新下载源码。按用户要求，本次只记录工作状态，**不再自动启动验证、综合、实现或上板操作**。
