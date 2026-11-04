# 任务：解决剩余时序问题，推进至 Bitstream

当前项目：XC7Z045 + AD9361 + OpenWiFi + AOA  
工具链：Vivado 2022.2

## 一、当前工程状态

上一轮已完成：

- 主工程：`dma_project/dma_project.xpr`
- 顶层：`system_top`
- BD：`ow/board/src/system.bd`
- 综合：成功。
- 最新实现：`impl_2r2t_2003`，route_design Complete。
- 26个端口引脚约束已修复。
- 2RX2TX（40 MSPS）时钟模式已约束。
- WNS = +0.214 ns，WHS = +0.014 ns。
- 最终 DRC：0 Error、0 Critical Warning。
- 尚未生成本轮 Bitstream。

最新实现检查点：

`dma_project/dma_project.runs/impl_2r2t_2003/system_top_routed.dcp`

优先使用上一轮报告、现有日志及 Timing/Methodology 报告，不要重新扫描整个项目。

Vivado 界面当前提示部分设计文件 Out-of-date，先用文件内容及运行记录简要判断是否为生成文件时间戳变化。不要直接 Force up-to-date，也不要无依据地重复综合。

## 二、本轮解决三个问题

**1. OpenOFDM 的6个锁存器**

定位 `deinterleave.v` 的不完整赋值问题及12个未约束内部端点。

结合原始逻辑判断锁存器是否有意存在。若确认是非预期锁存器，进行最小范围修复，并使用已有测试或简短定向验证确认解交织行为没有被破坏。

不要大规模重构 OpenOFDM，不要修改固定上游仓库；修改本板派生副本并保持可复现。

**2. AD9361 外部接口时序约束**

处理15个no_input_delay、13个no_output_delay。

根据当前XDC、AD9361对应模式的官方时序参数和已有板级资料，补充有依据的时序约束。

区分LVDS同步数据接口、SPI和异步控制信号，不得对所有端口套用同一延时或随意设置false_path。

若缺少PCB走线参数，先处理可确定部分，列出真正缺少的参数，不要猜测。

**3. CDC及datapath_only**

检查97项 `set_max_delay -datapath_only` 提示及相关跨时钟域路径。

优先保留原有可用设计，只修复能够明确证明存在问题的约束。不要为了消除Warning而盲目删除约束、添加false_path或重写CDC结构。

## 三、直接执行

按照以下顺序：

1. 读取现有报告，定位具体RTL和XDC。
2. 完成有依据的最小修改。
3. 修改RTL时才重新综合；仅修改实现约束时尽量复用现有综合结果。
4. 执行必要的Implementation，检查DRC、Timing Summary、Check Timing和Methodology。
5. 如果关键时序问题解决、引脚约束有效且没有阻塞错误，直接生成Bitstream。
6. 如果仍有不能证明安全的关键时序路径，停止Bitstream生成，明确指出剩余问题。

允许直接修改和执行，不必每完成一个小步骤就向我请求确认。

## 四、严格控制Token和计算资源

- 不重复BD验证。
- 不重复已经完成的检查。
- 不开展全面代码审计。
- 不运行完整系统仿真或无关测试。
- 不反复综合、实现；每轮必须有明确的修改依据。
- 不重新下载OpenWiFi，不创建新Vivado工程。
- 不修改DMA位宽、AXI地址、IQ格式和已验证的板级引脚。
- 不删除原工程或已有实现结果。
- 不执行Git add、commit、push，不上传远端。

把Token优先用于实际解决问题，而不是编写冗长计划和报告。

## 五、最终汇报
汇报内容添加在本文件中，续写在后边
用简短中文告诉我：

1. 三类时序问题分别解决了什么，还剩什么。
2. 实际修改了哪些文件。
3. 综合与实现是否成功，WNS/WHS、DRC及未约束关键路径情况。
4. Bitstream是否生成；如果生成，给出实际路径。
5. 如果没生成，明确告诉我还需要提供什么资料，或者下一步具体做什么。

对于已有日志，只引用关键证据，不大段复制。

**现在直接执行，目标是尽快获得第一版时序可信、可以开展真实硬件测试的Bitstream，而不是继续停留在分析阶段。**

---

## 执行结果（2026-10-25 16:40）

**本轮已完成真实综合和布局布线，锁存器问题已解决；时序尚未通过，未生成 Bitstream。** 按本任务第三节第6项停止生成，不能把 route_design Complete 当作时序签核通过。

### 1. 三类问题的结果

- **OpenOFDM：已解决锁存器及其内部端点问题。** 在本板派生的 `deinterleave.v` 组合块入口增加 `out_bits = 6'b000000`，合法选择分支保持原样，未映射选择不再保持上次结果。新综合和实现均为 **0 个锁存器**；`no_clock` 从54降至0，`unconstrained_internal_endpoints` 从12降至0。简短 XSim 定向验证通过 **58,368 次合法硬/软判决选择比较**，并验证控制输出及无效选择归零。测试使用 LUT 桩和定向选择输入，验证范围是本次组合选择修改，未声称完成整包解交织或系统仿真。固定上游文件未修改，规范化 SHA256 仍为 `44f228e94704b7feb5fcf4f8c8ed5cf7cb44aa2b70df0d2aaa940520e19681df`。
- **外部接口：器件参数已核实，板级预算仍缺失。** 你已回复没有 PCB 走线偏差资料。已记录官方 LVDS RX 时钟到数据/帧延迟0.25～1.25 ns、TX建立/保持1/0 ns，以及独立的SPI参数；这些不能直接当作完整的本板 input/output delay。`openwifi/ad9361_io_budget.json` 保存参数、来源及未填写项，明确不是生效XDC。未知项未填0，也未添加笼统 false_path。最终仍有 **15个 no_input_delay、13个 no_output_delay**，涉及LVDS数据/帧、GPIO状态及SPI/控制输出。
- **CDC：完成定位和一次更严格约束验证，尚未解决签核问题。** 原97项 TIMING-11 对应三条最大延时约束（TX32位、RX64位、valid1位）。本轮试验保留5 ns数值，去掉 `-datapath_only`，恢复时钟偏移和保持分析；TIMING-11现为0，但出现 **32个建立时序违例**。最差路径为 `tx_intf_0/inst/tx_iq_intf_i/csi_fuzzer_i/iq_out_reg[9]` → `tx_intf_0/inst/dac_intf_i/data_from_acc_stage1_reg[9]`，100 MHz→40 MHz；数据延迟0.531 ns、时钟路径偏移−4.808 ns，Slack −0.641 ns。**此结果由本轮约束语义改变得到，不能据此断言原CDC硬件必然错误，也不能把97项提示消失称为CDC修复完成。** 当前三条修改保留为待解决候选，尚不可签核；下一步须结合数据稳定窗口/握手和时钟相位，确定该用同步检查还是有充分依据的CDC例外，不能只为正WNS改回屏蔽检查。

官方依据：[AD9361 Rev.G Table 1](https://www.analog.com/media/en/technical-documentation/data-sheets/AD9361.pdf)、[AN-1441](https://www.analog.com/en/resources/app-notes/an-1441.html)。

### 2. 实际修改文件

以下路径均相对于 `F:/2026fpga/zynq7045_ad9361_rid_aoa/`：

- RTL派生副本：`ow/ip/openofdm_rx/verilog/deinterleave.v`、`ow/board/ip_repo/openofdm_rx/src/deinterleave.v`、`ow/board/src/ipshared/723d/src/deinterleave.v`、`ow/board/src/ipshared/8131/src/deinterleave.v`；实际编译使用8131副本。
- 可重现补丁及测试：新增 `openwifi/apply_deinterleave_fix.py`、`openwifi/tests/deinterleave_tb.v`、`openwifi/tests/run_deinterleave_test.ps1`；修改 `openwifi/prepare.py`，重新准备派生源时应用补丁并采用本板时序文件。原RTL备份在 `change_backups/deinterleave_20261025/`。
- 时序及预算：修改 `ow/board/src/openwifi_timing.xdc`，新增其本板源文件 `openwifi/board_timing.xdc` 和上述 `openwifi/ad9361_io_budget.json`。
- `dma_project/dma_project.xpr`：新增并选择本轮综合/实现运行；旧运行和检查点保留。没有修改DMA位宽、AXI地址、IQ格式或已核实引脚，没有执行Git add/commit/push。

### 3. 实际运行与检查

本轮确有RTL修改，因此旧运行过期有实际依据；没有使用 Force up-to-date。新运行仍在原主工程中，未创建替代工程、未重复BD验证。最终项目读取结果如下，两者 `NEEDS_REFRESH=0`：

| 项目 | 结果 |
|---|---|
| 综合 `synth_latch_1103` | synth_design Complete；0 Error、0 Critical Warning |
| 实现 `impl_latch_1103` | route_design Complete；布线错误0 |
| 建立时序 | WNS **−0.641 ns**，TNS −19.713 ns，失败端点32 |
| 保持时序 | WHS **+0.049 ns**，THS 0，失败端点0 |
| 脉宽 | WPWS +0.264 ns，失败端点0 |
| 最终DRC | **0 Error、0 Critical Warning**；另有213项Warning/Advisory |
| Check Timing | no_clock=0，内部未约束端点=0；外部输入15、输出13仍缺延时 |
| Methodology | TIMING-11=0；仍有TIMING-18等提示 |

说明：实现运行日志仍有与上一轮相同的两条IP约束 Critical Warning：TDD同步模块未匹配、FIFO的 `din_ovf_m*` 属性对象为空；它们与上表的最终DRC结果是不同口径。另外启动时有本地Tcl Store写权限提示，未阻止运行。

本轮布线检查点：`dma_project/dma_project.runs/impl_latch_1103/system_top_routed.dcp`。证据目录：`F:/2026fpga/openwifi_bit_20261025_1103/`，关键文件为 `final_project_status.txt`、`directed_test.log`、`impl_timing_summary.rpt`、`impl_check_timing.rpt`、`impl_drc.rpt`、`impl_methodology.rpt`。最终XPM总线偏斜检查两项均通过，但不代表上述TX数据总线已签核。

### 4. Bitstream与下一步

**没有生成本轮 `.bit`。** 剩余阻碍是32个跨域建立违例，以及不能完成板级签核的外部接口预算。下一步先证明TX/RX跨域传输的稳定窗口并修正相位/约束方案，再复用本轮综合结果做必要实现；外部部分需从板厂资料或实测得到数据/帧相对时钟的最小/最大走线偏差，读取实际AD9361 `0x006/0x007` 延迟配置，并确认SPI时钟/采样边沿和CTRL_OUT模式。你已确认现无PCB数据，当前不再重复索要，也不猜测补齐。
