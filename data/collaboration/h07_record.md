# 继续当前 FPGA 工程：修复约束并推进到 Bitstream

项目路径线索：
`F:\2026fpga\zynq7045_ad9361_rid_aoa`

此前报告中的工程线索：
- 主 Vivado 工程候选：`dma_project/dma_project.xpr`
- BD 候选：`ow/board/src/system.bd`
- 顶层模块：`system_top`
- 约束文件：`board.xdc`、`openwifi_timing.xdc`

这些是已有线索，请快速核实当前实际主工程及引用关系，不要预设路径一定未变，也不要重新遍历整个工作区。

## 一、先快速确认当前状态

此前已经完成：
- BD 验证。
- 综合。
- Implementation，且布局布线已完成。

但尚未生成 Bitstream。

此前报告还称更新了多个 XCI、XPR 和 Vivado 生成产物，但我在变更列表中目前只看到 MD 报告文件。

请简要确认当前实际主工程、综合和实现状态，以及必要的工程修改是否确实保存在当前工程中。不要开展独立的全面审计，不要逐个文件进行冗长的哈希比对。若发现实际工程与报告不一致，只说明关键差异并继续处理正确的工程。

## 二、重点解决引脚约束问题

此前实现报告显示，有 26 个端口缺少有效的引脚或电平约束。

请直接从当前实现结果、DRC 报告、顶层端口和现有 XDC 中找出这些端口，并逐项判断：

1. 端口的实际用途。
2. 是否需要连接到板卡物理引脚。
3. 如果需要，依据当前板卡原理图、现有引脚表及工程定义确定正确的 `PACKAGE_PIN` 和 `IOSTANDARD`。
4. 如果不应作为外部引脚，则根据实际设计意图处理，而不是随意分配引脚。

允许修改必要的 XDC 文件，但严禁猜测引脚、照搬其他板卡的引脚映射，或通过降低 DRC 严重度来绕过问题。

如果缺少确定引脚所需的原理图或证据，列出具体端口及缺少的信息，不要猜。

## 三、解决时钟约束和时序方法学问题

此前报告指出：
- `clk_wiz_0/inst/clk_in1` 存在主时钟定义方面的方法学警告。
- 存在未约束路径。
- WNS 为 +0.612 ns，WHS 为 +0.013 ns，但完整时序覆盖情况尚需确认。

请结合当前实际 XDC、Clock Wizard 配置、时钟树及 Timing Summary：

1. 定位重复或不合理的时钟定义。
2. 检查生成时钟是否被正确识别和约束。
3. 检查未约束路径及其原因。
4. 修复有明确证据的问题，确保约束符合真实时钟结构。

不要随意新增重复的 `create_clock`、虚构时钟频率、添加无依据的 false path，或为了让报告变绿而屏蔽真实时序问题。

## 四、修复后直接继续执行

1. 保存必要的 XDC 修改。
2. 重新运行 Implementation。
3. 检查 DRC、时钟定义、未约束路径、Setup/Hold 时序和资源报告。
4. 如果关键检查通过且没有阻塞 Bitstream 的问题，继续生成 Bitstream。
5. 如果仍有阻塞问题，停止并说明具体原因及需要补充的信息。

不要重复执行已经成功的 BD 验证和综合，除非实际修改确实要求重新执行。

本轮不修改 DMA 位宽、OpenWiFi 功能逻辑、RF 接口、AXI 地址或双路 IQ 数据通路，除非发现明确的阻塞性错误且先说明原因。

## 五、控制成本和最终汇报

不要把本轮变成审计项目，不要反复搜索无关目录，不要反复运行相同的失败流程。

禁止删除原有工程和备份，禁止 Git add、commit、push 或远端上传。

最后简明告诉我：
- 26 个端口分别是什么，哪些已解决、哪些需要我提供信息。
- 时钟约束修复了什么，还有哪些问题。
- Implementation 是否通过，关键 DRC 和时序结果如何。
- Bitstream 是否生成，实际文件位置在哪里。
- 本轮实际修改了哪些关键文件，以及为什么我在变更列表中可能看不到这些修改。

请直接执行必要的工程操作，不要只提供分析方案。

---

# 执行结果补充（2026-10-25，接续10月24日的约束修复）

**已解决26个端口的引脚/电平约束和内部主时钟重定义；2RX2TX模式重新实现完成。完整时序覆盖仍有明确缺口，因此本轮未执行write_bitstream，未生成新的.bit。** 这不是Vivado仍禁止生成的结论，而是本提示词要求的“关键检查通过后才生成”条件尚未满足。没有把仍可疑的路径设为false path，也没有降低DRC等级。

## 1. 当前实际工程与保存状态

根目录仍为 `F:\2026fpga\zynq7045_ad9361_rid_aoa`：

- 主工程：`dma_project/dma_project.xpr`。
- BD：`ow/board/src/system.bd`，顶层 `system_top`，顶层文件 `ow/board/src/system_top.v`。
- 实际板级约束：`ow/board/src/board.xdc`、`ow/board/src/openwifi_timing.xdc`。
- 原 `synth_1` 和 `impl_1` 确实保存在工程中，分别显示 `synth_design Complete!` 和 `route_design Complete!`。
- 本轮最终实现运行：**`impl_2r2t_2003`**，同一主工程、同一BD，复用原 `synth_1/system_top.dcp`。没有创建替代工程，也没有重跑综合或BD验证。
- 已将当前实现运行切换到 `impl_2r2t_2003`；旧 `impl_1` 和本轮失败的 `impl_constraints_2003` 均保留，没有覆盖其证据。

本轮日志目录，下文记为D：`F:\2026fpga\openwifi_constraints_20261024_2003`。目录名沿用开始日期，最终复验于10月25日完成。

## 2. 26个端口：全部已解决，不缺引脚信息

直接诊断证实根因是XDC表达形式，不是26个信号缺少板级映射。`D/inspect.log` 中Vivado明确报：

```text
[Designutils 20-1307] Command 'foreach' is not supported in the xdc constraint file.
.../ow/board/src/board.xdc:26
```

在原布线检查点中，`read_xdc` 后spi_csn仍在工具自动放置的AA19；仅在诊断内存中用普通Tcl `source`执行同一文件后，才变成原表指定的C11。该诊断没有保存旧检查点。实际修复是将foreach块展开为26条明确的 `set_property -dict {PACKAGE_PIN ... IOSTANDARD LVCMOS18}`。

以下端口均应连接物理引脚，**现全部为LVCMOS18，实际routed设计查询均为FIXED=1**：

| 端口 | PACKAGE_PIN | 用途/板级网名 |
|---|---|---|
| spi_csn | C11 | AD9361 SPI_ENB |
| spi_clk | B11 | SPI_CLK |
| spi_mosi | A13 | SPI_DI |
| spi_miso | A12 | SPI_DO |
| resetb | H16 | RF_REST |
| en_agc | G16 | RF_AGC |
| sync_in | G15 | RF_SYNC_IN |
| enable | G14 | RF_ENABLE |
| txnrx | F14 | RF_TXNRX |
| gpio_clksel | Y12 | 9361_CLK_SEL |
| gpio_R1_LNA_EN | M2 | R1_EN / R1_LNA_EN |
| gpio_R2_LNA_EN | L2 | R2_EN / R2_LNA_EN |
| gpio_T1_PA_EN | N4 | T1_EN / T1_PA_EN |
| gpio_T2_PA_EN | M4 | T2_EN / T2_PA_EN |
| ctrl_in[0] | C2 | CTRL_IN0 |
| ctrl_in[1] | B1 | CTRL_IN1 |
| ctrl_in[2] | B2 | CTRL_IN2 |
| ctrl_in[3] | A2 | CTRL_IN3 |
| gpio_status[0] | D13 | CTRL_OUT0 |
| gpio_status[1] | C13 | CTRL_OUT1 |
| gpio_status[2] | C14 | CTRL_OUT2 |
| gpio_status[3] | B14 | CTRL_OUT3 |
| gpio_status[4] | A15 | CTRL_OUT4 |
| gpio_status[5] | A14 | CTRL_OUT5 |
| gpio_status[6] | C12 | CTRL_OUT6 |
| gpio_status[7] | B12 | CTRL_OUT7 |

依据为现有板级引脚表，并重新查看了工作区 `原理图png/AN_XC7Z035(2)_页面_09.png`（RF使能）、10页（时钟源选择）、11页（RF控制、SPI、CTRL_IN/OUT）。没有使用其他开发板引脚，没有删除外部端口或变更原引脚号。

验证凭据：`D/final_project_status.txt` 逐项记录上述26项实际属性；`D/2r2t_io.rpt` 及最终DRC确认生效。NSTD-1、UCIO-1均消除。**这些端口不需要用户再补引脚信息。**

## 3. 时钟修复及2RX2TX适用范围

### 3.1 内部主时钟重复定义

生成文件 `ow/board/src/ip/system_clk_wiz_0_0/system_clk_wiz_0_0.xdc` 包含针对外部时钟输入模板的：

```tcl
create_clock -period 25.000 [get_ports clk_in1]
```

但本设计的clk_in1来自 `util_ad9361_divclk`，不是独立板载振荡器。这个内部primary clock截断上游分频关系，产生原TIMING-4两项和TIMING-27一项。

本轮在主工程中将**仅此模板文件**的 `USED_IN_IMPLEMENTATION` 设为false，保存为XPR的 `CompFileExtendedInfo / UsedInImplementation=0`。没有修改Vivado安装库或固定上游IP源码，也没有全局关闭所有IP约束。MMCM输出改由真实上游时钟自动推导；未新增create_clock或人为重新定义频率。

### 3.2 正确传播后暴露的模式问题

第一次修复实现 `impl_constraints_2003` 在route前置DRC失败：`PDRC-34`，MMCM计算得到2000 MHz VCO，超过该器件600—1200 MHz范围。其输入周期被取为12.5 ns，倍频25、分频1。这个失败保留在原运行和 `D/impl_exit_code.txt=1` 中，未掩盖。

根因是分频器本身保留两种可选择模式，工具同时传播40和80 MHz。证据：`ow/adi-hdl/library/xilinx/util_clkdiv/util_clkdiv.v` 中SEL_0_DIV=4、SEL_1_DIV=2，clk_sel=0选第一路；现有BD将ADC/DAC的r1_mode经AND接入clk_sel。现有工程目标、板级档案及 `openwifi/linux/an_xc7z045_rf.dtsi` 均采用2RX2TX。

因此在实际 `openwifi_timing.xdc` 中增加有明确模式依据的：

```tcl
# Only the existing 2RX2TX / 40 MSPS operating profile is signed off here.
set_case_analysis 0 [get_pins i_system_wrapper/system_i/util_ad9361_divclk/inst/clk_sel]
```

这是**时序模式分析**，并未在BD/RTL中硬接常量。必须由软件保持ADC/DAC的2RX2TX配置；不支持把本轮结果用于运行时1RX1TX切换。如以后要支持该模式，需另行审查接口时钟和MMCM结构，不能把它静默排除后宣称也已通过。

最终实际时钟查询：

| 时钟 | 周期 | 来源/关系 |
|---|---:|---|
| rx_clk | 6.250 ns | 外部AD9361 LVDS，160 MHz |
| clk_div_sel_0_s | 25.000 ns | 由rx_clk分频4，2RX2TX的有效采样时钟40 MHz |
| clk_div_sel_1_s | 12.500 ns | 另一路硬件分频仍存在，但在本模式不穿过选择器到MMCM |
| clk_out1_system_clk_wiz_0_0 | 10.000 ns | 自动生成，master为clk_div_sel_0_s，100 MHz基带 |
| clk_fpga_0 / clk_fpga_1 | 10.000 / 5.000 ns | PS输出100/200 MHz |

TIMING-4、TIMING-27、PDRC-34及AVAL-46均在最终2RX2TX报告中消除；multiple_clock计数恢复为0。

## 4. 重新Implementation的实际结果

最终原工程运行目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa\dma_project\dma_project.runs\impl_2r2t_2003`

由于已知Windows/WMI启动包装问题，本轮继续直接调用Vivado为该原工程运行生成的Tcl，未修改其布局布线算法命令。实际外层命令：

```powershell
& 'E:\thenewruanjian\vivado\Vivado\2022.2\bin\vivado.bat' -mode batch -source 'F:\2026fpga\openwifi_constraints_20261024_2003\run_2r2t.tcl' -log system_top.vdi -journal 'F:\2026fpga\openwifi_constraints_20261024_2003\run_2r2t.jou'
```

工作目录就是上述impl_2r2t_2003；脚本执行优化、布局、物理优化、布线并导出报告。**进程退出码0**，`D/2r2t_exit_code.txt`、`D/result_2r2t.txt`记录ROUTE_COMPLETE，重新打开工程查询为 `route_design Complete!`。

| 检查 | 最终结果 |
|---|---|
| 布局布线 | 完成，routed DCP已保存 |
| NSTD-1 / UCIO-1 | 0 / 0 |
| 最终DRC Error / Critical Warning | 0 / 0（仍有Warning/Advisory） |
| 已约束路径WNS / TNS | +0.214 ns / 0.000 ns |
| 已约束路径WHS / THS | +0.014 ns / 0.000 ns |
| 脉宽WPWS / TPWS | +0.264 ns / 0.000 ns |
| 建立/保持/脉宽失败端点 | 均为0 |
| Bus skew两条约束裕量 | +9.472 ns、+9.512 ns |
| LUT / 寄存器 | 40447（18.50%） / 54578（12.48%） |
| BRAM / DSP | 161 Tile（29.54%） / 154（17.11%） |

该数值属于本轮新约束和2RX2TX模式，没有沿用上一轮0.612/0.013 ns。

工具运行日志仍有Tcl store回退、已优化掉的TDD模块约束和wfifo约束空对象提示；“最终DRC没有Critical Warning”不代表整个进程日志零严重提示。

## 5. 未通过的完整时序关卡：本轮Bitstream未执行

已执行 `check_timing -verbose -file ...` 并查看RTL/端点，证据在 `D/check_timing_verbose.rpt`，不是只重复引用上一轮统计。

### A. OpenOFDM六个锁存器相关内部时序没有闭环

- no_clock检查计数54，涉及 `openofdm_rx_0/inst/dot11_i/ofdm_decoder_inst/deinterleave_inst/out_bits_reg[0..5]/G` 等门控端；该计数包括不同根信号的检查结果，不代表存在54个独立板级时钟。
- 12个未约束内部端点已精确定位到同一组 `out_bits_reg[0..5]` 的 **D、CLR** 端。
- 当前打包源码 `ow/board/ip_repo/openofdm_rx/src/deinterleave.v:61` 的组合always块中，soft decoding分支不是所有选择情况都有赋值，综合结果存在6个锁存器；报告同时有TIMING-20、LATCH-1和门控时钟提示。
- 这是RTL行为及其时序解释问题，不是补一个板级create_clock能正确解决。没有给数据驱动门控端虚构时钟，也没有给这12个端点批量false_path。本轮按“不改OpenWiFi功能逻辑”的范围保留，下一轮应对这一小段做功能/有效输入条件核对及必要的定向修复验证，而非大范围重构。

### B. 外部接口延时尚缺有依据的预算

15个no_input_delay端口：`gpio_status[7:0]`、`rx_data_in_p[5:0]`、`rx_frame_in_p`。

13个no_output_delay端口：`enable`、`spi_clk`、`spi_csn`、`spi_mosi`、`tx_clk_out_p`、`tx_data_out_p[5:0]`、`tx_frame_out_p`、`txnrx`。

其中AD9361接收数据/帧确实属于接口时序范围，不能因为芯片有PN校准就把STA约束全部省掉；异步状态、SPI、ENSM控制则需按实际采样/控制方式分类，不能无依据统一加false_path。

**还需的信息/依据**是本板接口的有效时序预算：匹配工作模式的AD9361数据/帧输出延时、接收要求、板级数据—时钟走线偏差，以及最终LVDS延时配置/校准条件。可以继续由Codex结合对应原厂手册和板级资料建立预算；若现有资料缺PCB走线差，则需要用户提供相应布局/时序数据，不能用猜测数值替代。26个PACKAGE_PIN本身不缺资料。

### C. 已有97项datapath-only使用提示需要审查

移除错误的内部primary clock后，真正相关的40/100 MHz关系得以恢复，方法学TIMING-11指出97项既有 `set_max_delay -datapath_only` 使用不恰当。首例为 `rx_intf_0/inst/adc_intf_i/adc_data_shift_reg[0]/C → adc_data_shift_stage1_reg[0]/D`。既有约束来自接收/发送适配的跨域处理，需结合其采样协议判断，不应直接删除或放宽来改善报告。本轮未扩大到该数据通路重写。

以上说明**“All user specified timing constraints are met”仅对已建立的检查成立**。尽管工具当前DRC可能允许write_bitstream，完整时序条件仍未满足，本轮据提示词第4节停止，**没有执行write_bitstream，没有生成新的.bit文件，更没有上板**。没有声称工具禁止一个实际上尚未尝试的Bitstream操作。

## 6. 实际修改文件及Git可见性

| 文件 | 本轮实际变化 |
|---|---|
| `ow/board/src/board.xdc` | 原26项映射展开成明确XDC语句，实际使用文件 |
| `openwifi/board.xdc` | 同步上述表达形式，避免板级源文件保留旧循环 |
| `ow/board/src/openwifi_timing.xdc` | 增加有依据的2RX2TX模式case analysis及适用范围注释 |
| `dma_project/dma_project.xpr` | 保存Clock Wizard模板的实现加载属性、新实现运行及当前运行选择 |

主BD、顶层HDL、DMA位宽、AXI地址、RF接口和双路IQ数据通路没有本轮功能修改。没有重新生成/替换综合DCP，没有手改固定上游或Vivado安装文件。

在仓库根目录执行 `git status --short -- ...`，上述4个关键文件均实际显示 **M**，`git diff --check`通过；它们没有被本轮忽略。IP XCI此前已从忽略规则中放开，但尚未跟踪的文件只显示??，普通git diff没有历史基线；生成HDL、运行目录、DCP、日志等仍按规则忽略。IDE如果只显示MD，应检查是否查看了正确仓库 `zynq7045_ad9361_rid_aoa`、文件过滤器或已缓存的变更列表，不应据此认定Vivado未保存。

未执行git add、commit、push或远端上传。修改前主要输入保存在 `D/inputs_before.zip`，原报告和所有旧运行仍保留。

## 7. 交接位置与下一步

最新检查点：

`F:\2026fpga\zynq7045_ad9361_rid_aoa\dma_project\dma_project.runs\impl_2r2t_2003\system_top_routed.dcp`

本轮**没有新Bitstream路径可交付**，不要将旧.bit重新命名冒充此次结果。

主要证据：`D/final_project_status.txt`、`D/2r2t_timing_summary.rpt`、`D/2r2t_methodology.rpt`、`D/check_timing_verbose.rpt`、`D/impl_drc.rpt`、`D/2r2t_io.rpt`；最终运行目录内也保存对应routed DRC、methodology、timing、route status和资源报告。部分诊断输出曾因不适用的Tcl命令退出，均未保存设计；最终核对改用Vivado支持的命令，`final_inspect_supported.log`中可核实正常结束。

下一轮按顺序：先处理/证明OpenOFDM六锁存器的内部时序，再补AD9361接口的有依据延时预算并审查97项datapath-only，最后重新实现并判断是否满足Bitstream条件。无需重新查找工程、分配26个引脚或重复BD验收。
