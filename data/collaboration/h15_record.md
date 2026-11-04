# 任务：FPGA 时序不收敛基础排查

工程目录：`F:\2026fpga\zynq7045_ad9361_rid_aoa`

## 目标

基于现有 Vivado 工程和最近几次布局布线日志情况，排查时序不收敛的主要原因，为下一步修复提供依据。

## 执行步骤

1. 找到最近一次有效的实现结果和时序报告，优先复用已有结果，不重新综合或布局布线。
2. 提取最差的 **10 条建立时间路径（Setup Paths）**，列出起点、终点、时钟域、数据路径延迟、Slack，以及主要逻辑和布线延迟。
3. 简要判断这些路径主要属于哪类问题：逻辑过长、跨时钟域、时钟约束问题、外部 I/O 约束缺失，或其他明确原因。
4. 总结最值得优先检查的 1～3 个问题，并给出对应的文件或模块位置。证据不足的地方标记为待确认，不要猜测。

## 限制

- 本轮只做基础排查，**不修改 RTL、XDC 或其他工程文件**。
- 不重新综合、不重新布局布线、不生成 Bitstream。
- 不全面审计工程，不重复检查已经明确的无关问题。
- 不写大量辅助脚本或防御性代码；优先使用 Vivado 已有报告和必要的 Tcl 查询。
- 控制 Token 消耗，只执行必要的查询，不反复测试。
- 不处理 Linux、设备树、DOA 算法或其他任务。
- 不执行 Git 提交或远端上传。

## 交付

直接在本提示词文件末尾续写本轮工作报告，简要列出：

- 使用的现有实现结果；
- 最差 10 条建立时间路径；
- 时序不收敛的主要原因及证据；
- 建议优先检查的 1～3 项。

完成后停止，等待下一步指示。

---

## 执行结果：时序不收敛基础排查（2026-10-27）

本轮只读取已有实现报告和相关 RTL/XDC，没有运行 Vivado、综合、布局布线或 Bitstream，也没有修改工程文件。

### 1. 使用的现有实现结果

采用最近一次完整布线结果：

- run：`dma_project/dma_project.runs/impl_rxaxis_final`
- routed checkpoint：`system_top_routed.dcp`，时间为 2026-10-26 14:27:55
- 时序报告：`system_top_timing_summary_routed.rpt`，命令为 `report_timing_summary -max_paths 10 -report_unconstrained`
- 设计状态：Fully Routed；88775 个可布线网络全部完成，routing error 为 0
- 总体时序：WNS **-0.684 ns**，TNS **-20.480 ns**，建立违例端点 **32**；WHS +0.050 ns、THS 0，脉宽 WPWS +0.264 ns
- 32 个建立违例全部位于 `clk_out1_system_clk_wiz_0_0 -> clk_div_sel_0_s`；其他时钟内和已报告的其他时钟间路径均无建立违例

### 2. 最差 10 条建立路径

共同路径定义：

- `S[n]`：`i_system_wrapper/system_i/openwifi_ip/tx_intf_0/inst/tx_iq_intf_i/csi_fuzzer_i/iq_out_reg[n]/C`
- `D[n]`：`i_system_wrapper/system_i/openwifi_ip/tx_intf_0/inst/dac_intf_i/data_from_acc_stage1_reg[n]/D`
- 时钟域：`clk_out1_system_clk_wiz_0_0`（100 MHz）→ `clk_div_sel_0_s`（40 MHz）
- 路径约束：`set_max_delay 5 ns`；Slow Process Corner；以下路径组合逻辑级数均为 **0**

| 排名 | 起点 → 终点 | Slack/ns | 数据路径/ns | 逻辑/ns | 布线/ns | 时钟偏斜/ns |
|---:|---|---:|---:|---:|---:|---:|
| 1 | `S[25]` → `D[25]` | -0.684 | 0.574 | 0.308 | 0.266 | -4.808 |
| 2 | `S[30]` → `D[30]` | -0.672 | 0.552 | 0.269 | 0.283 | -4.806 |
| 3 | `S[27]` → `D[27]` | -0.668 | 0.559 | 0.308 | 0.251 | -4.808 |
| 4 | `S[22]` → `D[22]` | -0.666 | 0.543 | 0.269 | 0.274 | -4.807 |
| 5 | `S[29]` → `D[29]` | -0.665 | 0.555 | 0.308 | 0.247 | -4.808 |
| 6 | `S[13]` → `D[13]` | -0.663 | 0.526 | 0.269 | 0.257 | -4.808 |
| 7 | `S[16]` → `D[16]` | -0.659 | 0.535 | 0.269 | 0.266 | -4.806 |
| 8 | `S[28]` → `D[28]` | -0.658 | 0.548 | 0.269 | 0.279 | -4.809 |
| 9 | `S[18]` → `D[18]` | -0.650 | 0.543 | 0.269 | 0.274 | -4.806 |
| 10 | `S[24]` → `D[24]` | -0.650 | 0.540 | 0.269 | 0.271 | -4.806 |

### 3. 主要原因及证据

**主要原因不是逻辑过长。** 最差路径均只有寄存器时钟到输出和短布线，组合逻辑级数为0；数据路径仅0.526～0.574 ns，逻辑与布线各约一半。5 ns 最大延时约束中，约 **-4.81 ns 的时钟偏斜**和0.284 ns时钟不确定度占据了主要预算，因此形成约-0.65～-0.684 ns违例。报告中的源时钟插入延迟约14.76 ns，目的时钟插入延迟约9.15 ns，经公共路径悲观消除后仍得到上述负偏斜。

**路径本质是100 MHz到40 MHz的多位 IQ 跨时钟传输，约束语义与实际传输协议需要一起确认。** `ow/ip/tx_intf/src/csi_fuzzer.v:63`～64在100 MHz域产生 `iq_out`；`ow/ip/tx_intf/src/tx_intf.v:293`～315把 `wifi_iq_pack` 直接交给 `dac_intf`；`ow/ip/tx_intf/src/dac_intf.v:69`～81在40 MHz `dac_clk` 下直接采样为 `data_from_acc_stage1`。接口虽有 `data_valid_from_acc`，但该信号在 `dac_intf.v` 中只出现在端口声明，没有参与采样控制。当前 `ow/board/src/openwifi_timing.xdc:38` 对此总线施加不带 `-datapath_only` 的5 ns `set_max_delay`，因此正常计入两棵时钟路径的偏斜。现有证据不足以断定应该放宽约束、改为 datapath-only、使用多周期，还是补真正的跨域握手/FIFO；必须先确认数据稳定窗口和设计意图，不能仅为消除违例改约束。

**40 MHz目的时钟网络本身存在明确的方法学警告。** `system_top_methodology_drc_routed.rpt` 报告2项 CKBF-1：7系列器件中 `BUFR -> BUFGCTRL` 级联不是推荐时钟拓扑。对应源码为 `ow/adi-hdl/library/xilinx/util_clkdiv/util_clkdiv.v`：两个 BUFR 分频输出进入 `BUFGMUX_CTRL`；当前 `SEL_0_DIV=4`，160 MHz `rx_clk` 分到40 MHz。该拓扑与较大的源/目的时钟插入差同时出现，是否是负偏斜的直接根因仍需下一轮针对时钟树确认，但它是明确应优先检查的结构问题。

**外部 I/O 约束仍不完整，但不是本次32个内部建立违例的直接来源。** `check_timing` 仍有15个 `no_input_delay` 和13个 `no_output_delay`；methodology 的32项 TIMING-18明确覆盖 AD9361 `rx_data/frame` 输入以及 `tx_clk/data/frame`、`enable`、`txnrx` 输出。这会阻止完整板级时序签核，但当前负 WNS全部来自上述100→40 MHz内部 IQ 总线。缺少 PCB 走线及接口预算时不能猜填延时。

### 4. 建议优先检查的 3 项

1. **先确认 TX IQ 总线的跨域协议和稳定窗口。** 重点看 `tx_intf.v:293`～315、`dac_intf.v:69`～81、`csi_fuzzer.v:63`～64，并结合 `wifi_iq_ready/read_bb_fifo` 的实际节拍确认32位数据何时更新、40 MHz域何时允许采样。只有明确协议后，才能决定采用同步约束、多周期、datapath-only还是结构化 CDC；当前标记为待确认。
2. **检查 `util_clkdiv` 的 BUFR→BUFGMUX_CTRL 时钟拓扑及100/40 MHz相位关系。** 位置为 `ow/adi-hdl/library/xilinx/util_clkdiv/util_clkdiv.v` 和 BD 中的 `util_ad9361_divclk`。目标是解释约-4.81 ns捕获不利偏斜，并判断是否应在时钟生成结构上解决，而不是只调大最大延时。
3. **在内部建立违例方案确定后补板级 I/O 预算。** 位置为 `openwifi/board_timing.xdc`、派生的 `ow/board/src/openwifi_timing.xdc` 及板级 XDC。需要 AD9361接口模式、器件时序、PCB数据/时钟走线偏差和实际延时寄存器设置；现有资料不足，保持待确认。

本轮基础排查结束，没有进行任何修复或重新实现。
