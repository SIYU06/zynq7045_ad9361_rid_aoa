# 任务：Zynq-7045 双通道 IQ 采集、DDR 循环缓冲及 Python 分析

## 一、项目现状

工程根目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa`

硬件：Zynq-7045 + AD9361，Vivado/Vitis 2022.2。

Vivado 主工程：

`dma_project/dma_project.xpr`

最新 Bitstream：

`dma_project/dma_project.runs/impl_latch_1103/system_top.bit`

该 Bitstream 已通过 JTAG 成功烧录，Hardware Manager 已确认 FPGA 配置成功，温度及主要电压无明显异常。

现有 PL 数据链：

`AD9361 → rx_intf → side_ch → axi_dma_0 → DDR → PS`

另有 OpenWiFi 解调链，本轮暂不处理。

已知 side_ch 设计为双通道 IQ 捕获，预期单个窗口包含 8 字节头部和 4096 组 64-bit IQ 数据，总计 32776 字节。实际寄存器地址、启动方式、数据打包和 DMA 配置必须以当前工程源文件为准。

现有 DMA 使用 SG 模式，不要误用 Simple DMA 示例。

## 二、本轮目标

**不修改 PL、不重新综合布局布线、不启动 Linux，只用 Vitis 裸机程序通过 JTAG 控制和采集真实 IQ。**

完成以下功能：

1. 初始化 Zynq PS 和 AD9361，设置双接收通道及当前硬件支持的采样配置。
2. 配置 side_ch 和 SG DMA，把双通道 IQ 写入 DDR。
3. 实现 DDR 循环缓冲，可以连续采集多个窗口并覆盖已处理的旧数据。
4. PS 能读取 DMA 状态、描述符、接收长度及实际 IQ 数据。
5. 通过 JTAG 调试接口把采样数据导出到 PC。
6. PC 使用 Python 解析、绘图和分析 IQ。
7. 最终形成一套可以重复使用的采集测试程序。

本轮不实现无线协议解调、RID 解析或 AOA 定位算法，只验证 IQ 接收及传输。

## 三、Vitis 裸机程序

使用 Vitis 2022.2，新建独立测试 Application，优先复用现有 XSA、BSP、AD9361 驱动和初始化代码，不从零重写驱动。

先检查实际 XSA 是否与当前 Bitstream 对应；若不存在匹配 XSA，明确说明并给出从当前 Vivado 工程导出的方法，不得假设旧 XSA 一定兼容。

程序功能：

**1. 初始化**

- PS、DDR、UART（如可用）。
- AD9361 SPI 配置，确认 2RX2TX 模式。
- side_ch 双通道捕获配置。
- `axi_dma_0` SG 接收通道。

使用当前真实寄存器地址，不得臆造。

**2. IQ 采集**

先成功采集一个窗口，再扩展为循环采集。

采用固定数量的 DDR 缓冲区及 SG 描述符构成循环接收机制；优先采用易于控制的环形队列，已处理缓冲区才能重新交给 DMA 覆盖。

不要在 DMA 仍在写入时读取同一缓冲区。

保留窗口序号、接收长度和必要的状态。

正确处理 DMA 描述符、TLAST、缓存一致性及采样打包。只做保证正确运行所必需的处理。

**3. JTAG 调试与导出**

优先通过 Vitis Debug / XSCT 读取 DDR。

提供具体操作命令或脚本，让我可以：

- 启动采集；
- 查看 DMA 状态；
- 暂停或结束采集；
- 导出指定 DDR 缓冲区中的 IQ；
- 在 PC 上保存原始二进制文件。

不要把大量 IQ 数据逐行打印到 UART，也不要为数据导出重新设计 USB 协议。

如果通过 JTAG 导出需要先停止 DMA 或暂停 PS，明确实现该流程。

**4. 日志**

运行日志保持清晰、简短，但必须包含真实测量值：

- AD9361 初始化结果、RX 模式、采样率、中心频率、增益。
- DMA 初始化、运行、完成及错误状态。
- DDR 缓冲区地址、描述符数量。
- 每次捕获的实际字节数、完成次数、窗口序号。
- 捕获失败或覆盖情况（仅在可测量时输出）。
- IQ 数据解析状态。

无法直接测量的指标标注 N/A，不能填造数据。

## 四、PC Python 分析

写一个可以直接运行的 Python 脚本，读取导出的 `.bin` 文件及采集元数据。

自动完成：

1. 解析 RX1、RX2 的 I/Q，正确处理有符号数、位宽和字节顺序。
2. 绘制四路 IQ 时域波形。
3. 计算并绘制两通道 FFT 频谱。
4. 计算 RMS、峰值、均值、直流偏置、削顶比例。
5. 计算双通道幅度差和相位差。
6. 检查样本长度、异常常量数据、明显错位。
7. 输出简短分析报告。

先使用实际采集数据；如尚未完成实测，可提供少量模拟数据测试解析程序，但模拟结果必须明确标注，不得冒充硬件实测。

保留原始二进制数据和对应采样参数，方便以后重复分析。

## 五、严格控制工作范围与 Token

这是一次小范围硬件联调任务，不是重新开发系统。

要求：

- 不处理 Linux。
- 不处理 OpenWiFi 解调及 RID。
- 不修改 PL、BD、XDC 和 Bitstream。
- 不开展新的全面时序审计。
- 不添加 ILA。
- 不创建临时 Vivado 工程。
- 不重新综合或布局布线。
- 不重复检查已经确认正常的 FPGA 配置及电压温度。
- 不开展无关的防御性测试、完整系统测试或大规模代码扫描。
- 不重复编译无关工程。
- 不做 Git add、commit、push。

代码保持简洁，避免过度封装、复杂抽象和大量低概率异常分支。

但 SG DMA 描述符管理、缓冲区覆盖控制、缓存一致性和必要超时必须正确，不能为了精简而省略影响数据正确性的关键处理。

优先读取相关的少量源文件，确认真实接口，再直接开发。

如果现有硬件或驱动确实缺少必要功能，明确指出真实阻碍，不要未经允许修改 FPGA 工程。

## 六、交付要求

直接创建并完成：

- Vitis 2022.2 裸机测试工程及 C 源码。
- DDR 循环采集功能。
- JTAG 导出操作脚本或准确命令。
- Python IQ 数据解析与可视化程序。
- 简单 README(添加在本文档的后边)：告诉我如何烧录、运行、采集、导出、分析。

能在当前环境执行的编译与测试直接执行；需要我连接真实板卡的步骤给出明确操作。

最终日志说明：

1. 哪些功能已实际实现、哪些仅完成代码。
2. 是否成功编译。
3. 是否已实测取得 IQ 数据。
4. 实际使用的 DMA 地址、数据格式、缓冲区位置。
5. 我在 Vitis 中应该点击什么、运行什么。
6. 下一步只需要做什么。

不要写冗长报告，不要反复征求确认。

**当前最高优先级：从真实板卡成功获得第一份双通道 IQ 数据，并能够在电脑上通过 Python 分析。**

---

## 执行交付与操作 README（2026-10-25）

**代码已完成并编译通过，尚未取得真实 IQ 文件。** 初版 ELF 曾经通过 JTAG 在板上返回 READY；随后连接失去目标。你已明确回复“板卡暂不可连接，先完成代码与操作说明”，因此后续完成软件交付，未继续板测。最终 ELF 的 DMA 收包、循环缓冲、调谐修正仍须在恢复连接后验证，不能记作实测成功。

### 1. 交付位置及验证状态

工程目录：`F:\2026fpga\zynq7045_ad9361_rid_aoa\baremetal_iq`。

- Vitis workspace：`workspace/`；Platform：`iq_hw`；Application：`iq_capture`。
- 已编译 ELF：`workspace/iq_capture/Debug/iq_capture.elf`，编译记录 `build_final.log` 中有 `IQ_APPLICATION_BUILD_COMPLETE`，退出码0。
- 匹配 XSA：`system_top_iq.xsa`，从当前主工程实现导出；包内 `.bit` 与指定的 `impl_latch_1103/system_top.bit` 逐字节一致。旧两份 XSA 不匹配，未复用。哈希记录在 `hardware_manifest.json`；本轮 Bitstream 未修改，没有重综合/实现。
- C 源码：`src/main.c`、`src/board_rf.c` 等。复用本地 AD9361 驱动和40 MSPS FIR，仅修改本测试副本：修正当前板 GPIO 编号、补上实际 ADI 核寄存器读写、检查底层增益模式设置返回值，并修复旧驱动 RX-only 调谐分支错误返回成功的问题。最终程序只在40 MSPS做RX调谐，不切到25/61.44 MSPS。
- JTAG：`control.tcl`、`run.ps1`；批量采集：`collect.py`；解析绘图：`analyze_iq.py`。
- PC 定向测试已通过：128组明确标记为模拟的数据，验证符号/小端序/头部、幅差约−6.023 dB、相差约+60.006°、校验不一致拒绝及两张PNG。模拟文件在 `simulated_test/`，**不是硬件采样结果**。XSCT脚本载入和Python/PowerShell语法检查通过。

初版板上读回记录在 `status_init.log`：RX采样率40000000 Hz、软件路径IQ采样率20000000 Hz、中心频率2436999998 Hz、RX使能寄存器0xDE（双RX使能）、增益71/71 dB。增益读回与请求46 dB不一致，保留实际值，不把目标值当测量值。旧调谐分支当时返回0，但可能掩盖失败，因此**不据此声称PN校准通过**；最终修正后的ELF尚未板测。

### 2. 真实接口与 DDR 缓冲区

地址已与本次XSA生成的 `xparameters.h` 核对：SG DMA=`0x80400000`，side_ch=`0x83C50000`，rx_intf=`0x83C20000`，ADI核=`0x79020000`；SG使能=1，长度字段23位。

数据为 **8字节小端TSF头部 + 4096组小端有符号int16 `I1,Q1,I2,Q2`**，共32776字节。当前程序配置 `bb_gain=0`，按12位符号扩展解析。源码 `adc_intf` 对40 MSPS输入二抽一，因此此处IQ时间轴使用 **20 MSPS**；这不是原始40 MSPS无损连续流。

本次最终ELF的地址如下，重新链接后以自动生成的 `layout.json` 为准：

| 对象 | DDR地址 |
|---|---|
| JTAG状态/命令邮箱 `g_iq` | `0x00138080` |
| SG描述符区，4个、64字节对齐 | `0x00158280` |
| 缓冲区0 | `0x00138180` |
| 缓冲区1 | `0x001401C0` |
| 缓冲区2 | `0x00148200` |
| 缓冲区3 | `0x00150240` |

每槽跨度32832字节。描述符完成后检查DMA错误、实际长度及SOF/EOF；DMA拥有的槽不能导出。导出脚本先请求有限停止，等固件确认，再暂停A9读取DDR，完成后恢复A9。槽只有经显式release才可覆盖；`collect.py` 在PC验证文件长度和FNV-1a校验后才release。程序关闭D-cache以保证HP3、描述符、数据和JTAG邮箱一致，运行期间不要另行开启D-cache。

side_ch配置依据源码：reg1=1选择写reg2启动AXIS；reg3=0x11选择双IQ；reg11=128为预触发长度；reg12=4096；reg2=4097对应含头部的64位拍数及TLAST；reg5自由触发位只脉冲一次。窗口之间有软件/JTAG间隙，丢样总数和物理ADC削顶指标为N/A，未声称无缝RF采集。

### 3. 恢复连接后，先取第一份真实 IQ

保持板卡上电并连接JTAG。已配置的FPGA无需重复烧录；如果板卡断电后配置丢失，在Vivado Hardware Manager点击 **Open Target → Auto Connect → Program Device**，选择原有 `dma_project/dma_project.runs/impl_latch_1103/system_top.bit`。

在PowerShell运行：

```powershell
cd F:\2026fpga\zynq7045_ad9361_rid_aoa\baremetal_iq
.\run.ps1 init
.\run.ps1 status
```

`init` 使用匹配的PS初始化文件配置PS/DDR、停止A9核1并下载ELF到核0，保留当前PL配置，不启动Linux。状态 `HEADER` 第2项：0初始化中、1 READY、2运行、3已停止、4失败、5等待消费者。须等到READY；若FAILED，保留完整输出，错误码按有符号32位解释，不要绕过PN/采样率检查强行采集。

```powershell
.\run.ps1 single
.\run.ps1 status
.\run.ps1 export 0 captures\first_iq.bin
& 'D:\Python38-32\python.exe' .\analyze_iq.py .\captures\first_iq.bin
```

首次采集应看到 `completed=1`、槽0状态COMPLETE=2、长度32776，且BD含完成/SOF/EOF、无错误。导出文件名必须不存在，避免覆盖原始数据。输出为 `first_iq.bin`、`first_iq.bin.json` 和 `first_iq.analysis/` 下的四路时域图、两通道FFT图、`analysis.json`、`analysis.txt`；元数据保存实际采样参数、序号、DMA/BD状态和校验值。未完成窗口会被拒绝导出。幅相分析会标注低相关性，不能直接当作天线相位校准结果。

### 4. 循环采集多个窗口

第一份文件导出后，释放槽0，再运行批量脚本：

```powershell
.\run.ps1 release 1
& 'D:\Python38-32\python.exe' .\collect.py --windows 8 --output .\captures\batch01
```

脚本分批使用4个槽，完整导出并验证后再回收，下一批才覆盖旧槽。它要求开始时槽已全部释放、没有其他采集在运行；输出目录也须为新目录。对每个 `.bin` 运行 `analyze_iq.py` 即可分析。

手动控制：`.\run.ps1 run 4` 采4个窗口；`.\run.ps1 stop` 等待当前有限包结束并停止；`.\run.ps1 status` 查看邮箱、DMA寄存器和4个槽；`.\run.ps1 release 15` 释放全部已处理槽。**不要在导出/保存完成前release，也不要只暂停PS就认为DMA已经停止。**

### 5. Vitis中打开与调试、重新编译

启动Vitis 2022.2，在workspace选择框（或 **File → Switch Workspace → Other**）选择上述 `baremetal_iq/workspace`，工程列表中打开 `iq_capture/src/main.c`、`board_rf.c`；可在 `capture()` 附近设置断点。

采集可直接使用上面的PowerShell命令，它们调用已安装Vitis 2022.2的XSCT。若使用Vitis的 **Xilinx → XSCT Console**，可以加载同一控制函数而不退出控制台：

```tcl
set iq_control_library_only 1
source {F:/2026fpga/zynq7045_ad9361_rid_aoa/baremetal_iq/control.tcl}
set argv {init}
iq_control
set argv {status}
iq_control
```

后续将 `argv` 改为 `{single}`、`{stop}`、`{export 0 F:/2026fpga/zynq7045_ad9361_rid_aoa/baremetal_iq/captures/first_iq.bin}` 等，再调用 `iq_control`。

修改C源码后运行 `.\run.ps1 build`，成功后必须再次 `init` 下载新ELF，不能继续使用板上旧程序。当前Python依赖已安装在本目录的 `python_deps/`；迁移环境可用 `python -m pip install -r requirements.txt`。若需重新导出XSA，可运行Vivado批处理 `export_hardware.tcl`，该脚本只打开当前实现并导出硬件，不触发综合/布局布线。

**下一步只需恢复板卡连接，执行 init → status → single → export → analyze。** 本轮没有修改PL、BD、XDC和Bitstream，没有添加ILA，没有启动Linux，也没有执行Git add/commit/push。
