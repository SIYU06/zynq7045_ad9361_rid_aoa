# 任务：排查并修复 FPGA 时序不收敛问题

工程目录：`F:\2026fpga\zynq7045_ad9361_rid_aoa`

### 一、目标

基于现有 Vivado 工程和时序报告，找出建立时间不收敛的主要原因，进行针对性修改，并验证修改效果。

### 二、执行步骤

1. 优先读取现有实现结果和时序报告，提取最差的 10 条建立时间路径，包括起点、终点、时钟域、Slack、逻辑延迟和布线延迟。
2. 根据路径信息判断主要原因，重点区分 RTL 关键路径过长、时钟约束问题、跨时钟域问题和外部 I/O 约束缺失。
3. 结合实际路径，选择最值得优先解决的问题，直接修改对应 RTL 或 XDC。不要为了消除警告而随意放宽约束、添加虚假例外或猜测外部延时。
4. 修改后进行必要的综合和一次完整布局布线，检查 WNS、TNS、建立时间违例数量及相关约束覆盖情况。
5. 如果问题仍未解决，报告实际结果和剩余原因，不要无限循环修改、构建。

### 三、执行要求

- 优先复用现有工程、实现结果和报告，不重新审计整个仓库。
- 不写过多防御性代码，不做复杂重构，不修改无关模块。
- 不重复运行相同测试，不进行大量无谓仿真，严格控制 Token 消耗。
- 不要只为了让 WNS 变正而修改约束；必须保证约束具有实际依据。
- 如果发现问题涉及真实跨时钟域风险，先检查现有同步逻辑，不要直接用时序例外掩盖问题。
- 保留必要的修改记录，避免覆盖唯一可用的既有实现结果。
- 不处理 Linux、设备树、DOA 算法或 OpenWiFi RID 解析以外的其他任务。
- 不执行 Git commit、push 或远端上传。

### 四、交付

将本轮工作报告直接续写在当前工作报告文件末尾，记录：

1. 最差 10 条建立时间路径及主要特征。
2. 时序不收敛的根本原因，以及支持该判断的证据。
3. 实际修改的文件、模块和修改理由。
4. 修改前后的 WNS、TNS、违例端点数量及关键约束检查结果。
5. 本轮实际运行的构建与验证结果。
6. 仍未解决的问题及下一步建议。

完成一次有针对性的修复和验证后停止，不要自行扩展任务。

---

## 执行结果：TX IQ 跨时钟路径整改（2026-10-27）

本轮复用原主工程与最近一次完整实现，只针对已确认的 TX IQ 跨域路径修改 RTL/XDC；随后新建独立 run，实际完成一次综合和一次完整布局布线。旧的 `impl_rxaxis_final` 及其 routed checkpoint 均未覆盖，未生成 Bitstream，未执行 Git commit、push 或远端上传。

### 1. 修改前最差 10 条建立时间路径

修改前基线为 `dma_project/dma_project.runs/impl_rxaxis_final/system_top_routed.dcp`。设计 Fully Routed，WNS **-0.684 ns**、TNS **-20.480 ns**、建立违例端点 **32**，WHS +0.050 ns。32 个建立违例全部属于 `clk_out1_system_clk_wiz_0_0`（100 MHz）到 `clk_div_sel_0_s`（40 MHz）的同一条 32 位 IQ 跨域总线。

共同路径：

- `S[n]`：`i_system_wrapper/system_i/openwifi_ip/tx_intf_0/inst/tx_iq_intf_i/csi_fuzzer_i/iq_out_reg[n]/C`
- `D[n]`：`i_system_wrapper/system_i/openwifi_ip/tx_intf_0/inst/dac_intf_i/data_from_acc_stage1_reg[n]/D`
- 约束为 5 ns MaxDelay，Slow Process Corner；所有路径逻辑级数均为 0

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

### 2. 根本原因与整改依据

负 Slack 不是由 RTL 组合逻辑过长造成的。上述路径均为 0 级组合逻辑，数据路径仅 0.526～0.574 ns；真正吞掉 5 ns 预算的是约 **-4.81 ns** 的源/目的时钟插入偏差以及 0.284 ns 时钟不确定度。原约束把这条跨域总线当作普通相关时钟建立路径，因而将时钟树偏差计入 5 ns 数据通路预算。

RTL 检查确认这不是任意变化的裸多位总线：40 MHz 域中的 `dac_phase` 每拍翻转，经 4 级 `xpm_cdc_array_single` 同步到 100 MHz 域；`read_bb_fifo` 只在同步后信号的上升沿产生请求，因此 `csi_fuzzer.iq_out` 约每 50 ns 才更新一次。40 MHz 域已有连续的 `data_from_acc_stage1`、`data_from_acc_stage2` 两级采样，数据稳定窗口显著大于保留的 5 ns 物理传输上限。因此本轮没有删除约束、扩大数值、增加 false path 或猜测 multicycle，而是明确现有两级接收结构为同步链，并让 5 ns 约束只度量物理数据路径。

Vivado 最终 `report_cdc` 将该路径识别为 `Safely Timed`、深度 2、`Multi-bit synchronized with ASYNC_REG property`、例外类型 `Max Delay Datapath Only`。CDC-6 仍以 Warning 等级提示“多位同步”，这是工具对该结构的分类；协议安全性来自同步后的反向请求、约 50 ns 源数据稳定窗口、两级目的寄存器以及 5 ns 物理路径上限的共同保证，而不是用例外掩盖任意跨域数据。

### 3. 实际修改

1. `ow/board/src/ipshared/22ce/src/dac_intf.v`：在实际综合使用的 `data_from_acc_stage1[31:0]` 和 `data_from_acc_stage2[31:0]` 上添加 `ASYNC_REG=TRUE`，保留原两级采样行为不变。
2. `ow/board/ip_repo/tx_intf/src/dac_intf.v`、`ow/ip/tx_intf/src/dac_intf.v`：同步相同修改，避免打包源、暂存源与当前生成源不一致。
3. `ow/board/src/openwifi_timing.xdc`、`openwifi/board_timing.xdc`：仅把该 TX IQ 总线的 `set_max_delay 5` 改为 `set_max_delay -datapath_only 5`；5 ns 数值及精确起止对象未改变，RX 约束未在本轮修改。
4. `openwifi/apply_tx_iq_cdc_fix.py`、`openwifi/prepare.py`：加入可重复应用的小型板级补丁，后续重新准备锁定源时不会丢失上述 RTL 修改。
5. `F:/2026fpga/openwifi_timing_fix_20261027_1708/build_once.tcl`：只用于创建并运行独立的 `synth_txiq_cdc_1708` / `impl_txiq_cdc_1708`，生成验证报告；没有替代或重建主工程。

### 4. 修改前后结果

| 指标 | 修改前 `impl_rxaxis_final` | 修改后 `impl_txiq_cdc_1708` |
|---|---:|---:|
| WNS | -0.684 ns | **+0.559 ns** |
| TNS | -20.480 ns | **0.000 ns** |
| 建立违例端点 | 32 | **0** |
| WHS / THS | +0.050 ns / 0 | **+0.053 ns / 0** |
| WPWS / TPWS | +0.264 ns / 0 | **+0.264 ns / 0** |
| 100→40 MHz TX IQ 路径最差 Slack | -0.684 ns | **+2.208 ns** |

正式 routed timing summary 明确给出 `All user specified timing constraints are met`。新的全局最差建立路径已变为同一 100 MHz 域内 `PS7_i/MAXIGP1ACLK` 到 `tx_intf_s_axi_i/slv_reg11_reg[0]/D`，Slack +0.559 ns；它不再是本次 TX IQ CDC 路径。

TX IQ 定向检查结果：

- 起点 32 个、终点 32 个、匹配时序路径 32 条；最差路径为 bit 15，Slack +2.208 ns。
- 32 条路径数据延迟范围为 1.987～2.774 ns，全部满足原 5 ns 上限；最差路径逻辑 0.308 ns、布线 2.466 ns、逻辑级数 0。
- `report_exceptions -coverage` 的 Position 33 显示 `Max Delay Datapath Only max_dpo=5`，32 个起点、32 个终点、32 个端点，From/To 覆盖均为 **100%**。
- 综合网表中两级共 64 个寄存器全部为 `ASYNC_REG=1`。
- 方法学报告中没有 `TIMING-11 Inappropriate max delay with datapath only`；说明该 datapath-only 约束的终点已被工具识别为有效同步链。
- `check_timing` 的 `no_clock`、`unconstrained_internal_endpoints`、`multiple_clock`、`generated_clocks`、`loops` 均为 0。

### 5. 本轮构建与验证

- 工具：Vivado 2022.2；批处理进程退出码 0。
- 综合：`synth_txiq_cdc_1708`，0 error、0 critical warning，生成 `system_top.dcp`；`synth_result.txt=PASS`。项目调度状态仍显示 `Scripts Generated`，这是沿用已验证的直接执行 Vivado 生成 Tcl 的方式；DCP、综合报告和 PASS 文件是实际完成证据，`NEEDS_REFRESH=0`。
- 实现：`impl_txiq_cdc_1708` 完成 opt/place/phys_opt/route，项目状态 `route_design Complete!`、`NEEDS_REFRESH=0`；`impl_result.txt=ROUTE_COMPLETE`。
- 路由：88715 个可布线网络全部 Fully Routed，routing error 为 0。
- Routed DRC：0 error；报告保留 213 项既有 warning/advisory，没有通过降级规则消除问题。
- Routed checkpoint：`dma_project/dma_project.runs/impl_txiq_cdc_1708/system_top_routed.dcp`。
- 主要证据目录：`F:/2026fpga/openwifi_timing_fix_20261027_1708`，包括 timing summary、定向 TX IQ timing、exception coverage、CDC、methodology、check_timing、DRC、route status 和同步寄存器属性清单。

### 6. 仍未解决的问题与下一步建议

本轮目标中的内部建立时间不收敛已经解决，但完整板级签核仍有以下已知缺口，本轮按要求不继续扩展修改：

1. `check_timing` 仍报告 15 个 `no_input_delay` 和 13 个 `no_output_delay`，methodology 仍有 32 项 TIMING-18。需要 AD9361 器件时序、接口模式、PCB 走线偏差和实际延时寄存器设置后才能填写，不能猜测。
2. `util_clkdiv` 的 BUFR→BUFGCTRL 仍有 2 项 CKBF-1。当前内部时序已通过，不需要为了本轮结果重写时钟结构；后续做板级时钟架构签核时再评估。
3. methodology 还保留 7 项 LUTAR-1 和 1 项与 ADI DAC FIFO `din_unf_d_reg -> dout_unf_m1_reg` 有关的 TIMING-10/CDC-2；它们不是本次 TX IQ 路径，需在独立任务中按各自协议处理。

本轮一次针对性修复和验证至此停止。
