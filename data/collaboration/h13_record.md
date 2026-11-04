# 任务：离线推进 OpenWiFi 接收链路至 DMA1

基于现有《10.26 10.03 OpenWiFi 审计》，继续推进 Zynq-7045 + AD9361 工程。

目标链路：

`AD9361 → OpenWiFi PL 解调 → rx_intf → DMA1 S2MM → PS/DDR`

目前双通道 IQ 经 DMA 写入 DDR 的链路已验证。本轮不重复处理。

## 一、本轮任务

1. 根据已有报告和关键源码，检查 OpenWiFi 的 IQ 输入、PHY 解调、帧输出及 DMA1 连接。
2. 优先处理已有记录中影响综合、布局布线和时序的明确问题。修改必须有依据，不猜测板级约束。
3. 检查 DMA1 的 AXI Stream 接口、数据位宽、包长、FCS 状态及 DDR 写入配置是否匹配。
4. 利用现有工具完成可执行的离线验证，必要时运行综合、布局布线和 Bitstream 生成。
5. 检查现有 Linux 驱动源码与 DMA1 的接口关系，但暂不开发 Linux 设备树、完整驱动部署或 RID 解析。

## 二、执行限制

- 本轮没有开发板连接条件，**禁止执行 JTAG、XSCT 上板、DDR 实读写及真实射频测试**。
- 不因缺少开发板而停止可独立完成的源码检查、修改和离线构建。
- 不修改已经验证通过的 AD9361 校准和 IQ 采集链路。
- 不重新移植整个 OpenWiFi，不做全面审计。
- 不添加大量防御性代码，不重复执行相同测试。
- 不处理 Linux 设备树、RID、AOA 或 IQ 动态监测。
- 不执行 Git add、commit、push。

## 三、完成标准

分别报告（续写在本报告后边）：

1. **源码与连接**：OpenWiFi 解调输出到 DMA1 的链路是否完整，发现了哪些明确问题。
2. **离线构建**：综合、布局布线、时序检查及 Bitstream 生成分别是否成功；列出实际关键错误。
3. **DMA1 配置**：静态检查发现的问题及修改结果。
4. **硬件待验证项**：只列出必须上板才能确认的内容，不把静态检查结果说成硬件实测成功。

如果遇到阻塞，优先完成不受影响的任务，不要反复尝试失败的步骤。

最终只输出修改文件、关键结果、剩余阻塞及下一步操作。控制 Token 消耗，完成后停止。
---

## 执行结果（2026-10-26）

**本轮修复了 OpenWiFi 解码帧出口的 AXIS 包尾背压缺陷，完成离线定向仿真、实际综合和布局布线。DMA1 静态连接/配置匹配，但整设计时序仍未通过，未生成 Bitstream；没有执行任何上板操作。**

### 1. 源码与连接

关键路径在 BD/生成 HDL 中已接通：

`axi_ad9361 → ADC FIFO → 四分量打包 → rx_intf/sample0 → openofdm_rx → 解码字节/包长/FCS → rx_intf → DMA1 S2MM → AXI interconnect2 → PS ACP → DDR`

- IQ 输入、PHY 同步/解调/纠错/FCS 及字节输出沿用现有实现。本轮未修改 AD9361 校准或已验证的 IQ 采集链。
- **明确缺陷：** 原 `rx_intf_m_axis.v` 用 `TREADY` 门控 `TLAST`，末拍受背压时不能持续提供包尾标志。原代码在真实 XPM FIFO 模型下于635 ns复现失败：`TLAST index=0 expected=1 ready=0 last=0`。依据为 [AMD AXI4-Stream Protocol Checker PG145 的 TLAST 稳定规则](https://docs.amd.com/api/khub/documents/SLWzYbqIew1c8Si3gFkbjA/content)。
- **最小修复：** `TLAST` 由有效末拍位置产生，保持到握手，不再依赖 `TREADY`，并移除旧单拍抑制寄存器。同时修改 `rx_intf.v`：包控制器接收 `TLAST & TREADY` 完成事件，避免背压期间提前结束当前包。
- 上游源码未修改；补丁同步到构建源、IP 仓库及实际编译的 `ipshared/8940` 三处派生副本。

离线验证结果：

| 验证 | 实际结果与范围 |
|---|---|
| AXIS 定向仿真 | **8项通过**：单拍/多拍、背压、数据顺序、全字节有效、包尾及 endless 模式；使用真实 XPM FIFO。修改前相同检查失败。 |
| 字节→接收头→AXIS 定向仿真 | **46项通过，共15,360字节**：帧长14～32、1697～1700字节，两种FCS状态，接收头、补零、末拍背压及控制器等待完成握手。使用真实字节打包/头插入/流输出 RTL 和 XPM FIFO。 |
| 静态连接/参数核对 | **15条关键连接通过**，DMA1 XCI、DDR映射和驱动缓冲容量匹配。 |

上述仿真从人工注入的 PHY 输出字节开始，FCS 状态也是注入值；没有验证 IQ→完整 PHY 解调、CRC计算、XPU过滤策略、真实 DMA 引擎或 DDR 写入。坏FCS状态用例只验证状态位传输，不代表正常接收模式应放行坏包。

### 2. 离线构建

最终版本使用 Vivado 2022.2，在原主工程新增 `synth_rxaxis_final` / `impl_rxaxis_final`，保留历史运行和检查点；未修改 BD、XDC、DMA 参数或 Linux 源码。

| 项目 | 最终结果 |
|---|---|
| 实际综合 | **成功**；`synth_design` 计数0 Error、0 Critical Warning，锁存器0；已生成 `system_top.dcp`。 |
| 布局/布线 | **成功**；全部88,775条可布线网络完成，布线错误0，生成 routed DCP。 |
| 建立时序 | **未通过**：WNS **−0.684 ns**，TNS **−20.480 ns**，失败端点32。 |
| 保持/脉宽 | WHS **+0.050 ns**、THS 0；WPWS **+0.264 ns**，相应失败端点均0。 |
| 最终 DRC | **0 Error、0 Critical Warning**；另有213项Warning/Advisory。 |
| Check Timing | no_clock=0，内部未约束端点=0；仍缺 **15项输入、13项输出延时**。 |
| Methodology | 42项Warning；仍有时钟拓扑、异步复位、同步器属性及I/O延时提示；TIMING-11未出现。 |
| Bitstream | **未生成**：建立时序和外部接口签核仍阻塞。 |

最差路径为：

`tx_intf_0/.../csi_fuzzer_i/iq_out_reg[25] → dac_intf_i/data_from_acc_stage1_reg[25]`

100 MHz→40 MHz，现有最大延时约束5 ns，数据路径0.574 ns、时钟偏移−4.808 ns，Slack −0.684 ns。`dac_intf.v` 的两级数据寄存器与独立同步的读请求确实存在，但现有证据不足以证明可安全放宽该总线的约束。本轮未恢复 `-datapath_only` 或增加 false_path 来隐藏违例。接收端 `rx_intf` 发起的已报告最差建立路径为+0.348 ns，仅表示当前约束下的分析结果，不代表RF外部接口或整条接收链签核通过。

实现日志仍有既有两条 IP 约束 Critical Warning：TDD模块未匹配、FIFO约束对象为空；启动另有本地Tcl Store权限提示。它们没有阻止本轮构建，与最终 DRC 的统计口径不同。

**运行状态说明：** 本轮实际执行了 Vivado 生成的综合/实现 Tcl。综合日志、`final_synth_result.txt=PASS` 与 DCP 证明综合完成；项目调度器的综合 `STATUS` 仍显示 `Scripts Generated`，实现显示 `route_design Complete!`，两者 `NEEDS_REFRESH=0`。未强制改写状态，不能仅凭GUI文字否定或替代实际构建证据。前面的 `synth_rxaxis_1020` 为中间版本结果，不作为最终版本验收依据。

最终检查点（相对项目根目录）：

- `dma_project/dma_project.runs/synth_rxaxis_final/system_top.dcp`
- `dma_project/dma_project.runs/impl_rxaxis_final/system_top_routed.dcp`

全部证据位于工作区 `openwifi_rx_dma_20261026_1020/`：`axis_before/test.log`、`axis_after/test.log`、`frame_final/test.log`、`dma1_static.json`、`source_manifest.json`、`build_final.log`、`final_synth_result.txt`、`final_impl_{timing,check_timing,drc,route_status,methodology}.rpt` 和 `final_project_status.txt`。最终核对12个源码/测试文件的SHA256与构建期间记录一致。

### 3. DMA1 配置与驱动接口

| 项目 | 核对结果 |
|---|---|
| AXI Stream | RX出口与DMA1均为64位；TDATA/TVALID/TREADY/TLAST在生成HDL中对应。RX的TSTRB全1，DMA1的TKEEP由生成HDL固定为 `0xFF`。 |
| 接收传输长度 | **16 + ceil(pkt_len/8) × 8 字节**；尾部补零，帧长仍由私有头记录。不是按未补齐的帧长直接计DMA字节。 |
| 私有接收头 | 0～7：TSF；8～9：RSSI；10～11：GPIO/包存在标志；12～13：PHY帧长；14：速率/HT标志；15：相位偏移。 |
| FCS状态 | PHY最后一个字节被替换为 `{fcs_ok, rx_pkt_sn[6:0]}`；驱动从 `16+len−1` 取最高位。缓冲区不是保留完整原始FCS的纯MAC帧流。 |
| DMA1 | 寄存器基址 `0x80410000`；S2MM启用、SG启用、长度字段23位、地址32位、DRE启用。 |
| DDR路径 | DMA1数据与SG描述符经 interconnect2→ACP；DDR窗口映射0～1 GiB，覆盖当前PS DDR设置上限 `0x3FFFFFFF`。 |
| 容量边界 | 软件阈值1700字节，最大AXIS传输 **1720字节**，小于每BD的 **2048字节**，也小于接收FIFO容量。 |
| 中断/驱动 | DMA1 S2MM中断回接 `rx_intf/s2mm_intr`，再由接收控制产生收包中断；`sdr.c` 申请 `rx_dma_s2mm`，以 `dma_alloc_coherent` 分配循环缓冲并调用 cyclic DMA，按上述头布局取帧。 |

除上述包尾握手修复外，未发现需要改位宽、包长配置或DDR地址配置的明确证据，因此保留现有参数。Linux通道名在实际系统是否绑定DMA1、描述符是否执行、ACP一致性和中断时序仍需运行验证；本轮未处理设备树或驱动部署。

### 4. 修改文件、剩余阻塞与下一步

项目内实际修改：

- `ow/{ip/rx_intf,board/ip_repo/rx_intf}/src/` 及 `ow/board/src/ipshared/8940/src/` 中的 `rx_intf_m_axis.v`、`rx_intf.v`，共6个派生文件；原件保存在 `change_backups/rx_axis_20261026/`。
- `openwifi/prepare.py`：在新建/已有暂存路径均应用本板补丁。
- 新增 `openwifi/apply_rx_axis_fix.py`、`openwifi/check_rx_dma.py`。
- 新增 `openwifi/tests/rx_axis_tb.sv`、`rx_frame_tb.sv`、`run_rx_axis_test.ps1`。
- `dma_project/dma_project.xpr`：新增本轮运行并选择最终运行；修改前XPR保存在证据目录 `dma_project_before.xpr`。
- 本报告；证据目录中的构建脚本、日志与报告为本轮新增产物。

**剩余阻塞：** TX跨域建立违例尚未解决；AD9361外部接口完整时序预算仍缺失。没有依据把5 ns改大、把未知板级延时填0，或把布局布线成功视为时序通过。

**下一步操作：** 先针对 `csi_fuzzer→dac_intf` 的数据更新、跨域读请求和实际消费相位建立可验证的稳定窗口，确定有依据的RTL/约束修复；外部I/O另补板级走线及器件接口配置依据，再复用最终源码执行必要实现检查。无需重新移植OpenWiFi或修改DMA1位宽。

必须上板才能确认的项目仅保留：

1. 当前OpenWiFi硬件中的实际IQ节拍、缩放和复位/时钟释放是否符合PHY输入要求。
2. 已知20 MHz OFDM空口包是否恢复正确PHY头、帧长与FCS。
3. DMA1循环描述符、ACP/DDR内容、缓存可见性、中断与连续收包/绕回是否正常。

本轮未执行JTAG、XSCT、DDR实读写、真实射频、设备树开发、RID/AOA或Git提交操作。到此停止。
