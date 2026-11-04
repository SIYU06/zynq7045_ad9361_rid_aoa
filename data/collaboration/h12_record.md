# 任务：OpenWiFi 接收与 RID 解析链路现状盘点

## 一、当前目标

项目：Zynq-7045 + AD9361 无人机 RID 侦测系统。

目前已完成：
- AD9361 校准超时及 BBPLL 锁定问题已解决。
- 双通道 IQ 已通过 DMA 写入 DDR，并由 PS 读取验证。

现在暂停 IQ 采集与 JTAG 优化，集中检查 OpenWiFi 到 RID 解析的链路。

## 二、检查内容

只检查当前工作区中与以下内容直接相关的文件：

1. OpenWiFi 上游源码、当前使用版本及实际移植情况。
2. FPGA/PL 中的 IQ 输入、同步、解调和接收模块。
3. 802.11 帧检测、解码、MAC 帧提取及已有解析代码。
4. OpenWiFi 与现有 AD9361、IQ 接口和硬件工程的连接关系。
5. 当前工程中是否已有 RID 解析实现，以及它与 MAC 帧输出的连接情况。
6. 必要的构建脚本、配置文件和相关 MD 文档。

先查看现有文档，再检查少量关键源码。沿实际数据流追踪，不要全面扫描仓库。

## 三、必须回答的问题

**1. 现有 OpenWiFi 工程有什么？**

列出关键模块、文件及作用，说明哪些是上游原有，哪些是当前工程新增或修改的。

**2. 目前实际做到哪一步？**

明确区分：
- 已有验证证据的功能；
- 只有代码或配置、尚未验证的功能；
- 尚未连接或缺失的环节。

不能把源码存在、综合成功或接口连通直接视为无线解调成功。

**3. 从 IQ 到 RID 还缺什么？**

按以下链路逐段检查：

`AD9361 IQ → OpenWiFi 接收与解调 → 802.11 MAC 帧 → RID 数据识别与字段解析`

指出实际断点、接口不匹配、缺失模块和必要依赖。没有证据的环节标记为“待验证”，不要猜测。

**4. 下一步最应该做什么？**

只列出优先级最高的 3 项任务，说明先做什么、为什么，以及如何判断完成。

## 四、执行限制

- 本轮只盘点，不修改源码、BD、XDC、设备树或构建配置。
- 不重新综合、布局布线、仿真或编译。
- 不处理 AD9361 校准、JTAG、DDR 和 IQ 动态显示。
- 不重新移植整个 OpenWiFi 上游。
- 不检查 ESP32、发送端或其他无关工程。
- 不做全面审计，不逐文件生成长篇说明。
- 不执行 Git add、commit、push。
- 不添加防御性代码，不重复验证已知结果。

## 五、交付格式
报告内容在本文章后续续写

1. **现有模块**：关键模块及作用。
2. **当前进度**：已验证、未验证、未接通。
3. **关键断点**：OpenWiFi 到 RID 的实际缺口。
4. **下一步 3 项任务**：按优先级排序。

只盘点一遍，完成后停止，等待下一步指令。

**目标：用最少的 Token 搞清楚现有 OpenWiFi 能复用什么、真正卡在哪里，以及怎样以最短路径打通 RID 接收链路。**
---

## 执行结果：OpenWiFi → RID 链路盘点（2026-10-26）

**结论：现有工程已有 PL 接收解调链路、Linux 收帧驱动和独立 RID 解析器，能够复用；尚无本板从空口恢复有效 MAC 帧并送入 RID 解析的证据。主要缺口是可部署的本板 OpenWiFi 硬件/软件组合及端到端联调，并非缺少整套解调器或 RID 字段解析代码。**

本轮只读相关文档、BD 和少量关键源码，仅续写本报告；未构建、仿真、上板或修改工程配置。下述“已验证”沿用既有记录，不代表本轮重新测试。路径除 `rid_receiver/`、外层报告目录及提示词外，均相对于 `zynq7045_ad9361_rid_aoa/`。

### 1. 现有模块

**来源与版本。** `openwifi/sources.lock.json` 记录以下候选版本；`upstream/` 保存上游，`ow/` 为本板构建派生副本，不能只凭上游提交号代表最终构建内容：

| 依赖 | 锁定提交 |
|---|---|
| openwifi-hw | `fa6c89687e4637f07adbfb41299056b6d18fd80e` |
| openwifi 软件/驱动 | `674995a130893bd9d0fe94d6ef0790ac8f43ec2a` |
| ADI HDL 2022_R2 | `7ea497b6c24172ee293d6e0a9a387a16973da5ce` |
| OpenOFDM | `2bb3ad1a1f0023bfd15168db4e196ebf0d56d76c` |

Linux 的 commit/config/release 在锁文件中仍为空；上述版本组合在本板的运行兼容性待验证。

| 关键模块/文件 | 作用与来源 |
|---|---|
| `ow/board/src/system.bd` 中 `axi_ad9361`、`util_ad9361_adc_fifo`、`util_ad9361_adc_pack` | ADI 上游接收接口、跨时钟缓存与四分量打包；本板 BD 由 ZC706+FMCOMMS2 结构派生。 |
| `ow/ip/rx_intf/src/rx_intf.v`、`adc_intf.v` | 上游接收接口：通道选择、抽取/缩放及基带输入；接收解码字节、附加接收信息并输出 AXI Stream。 |
| `ow/ip/openofdm_rx/verilog/dot11.v`、`ofdm_decoder.v` | 上游 PHY：短/长前导同步、频偏处理、FFT/均衡、解调、解交织、纠错、解扰及 FCS 检查；输出字节、包长、速率和 FCS 状态。本板派生 `deinterleave.v` 已修复组合赋值遗漏，固定上游未改。 |
| `ow/ip/xpu`、`tx_intf`、`openofdm_tx` | 上游 MAC 辅助控制及 TX/初始化依赖，仍保留于设计；存在这些模块不表示 TX 已验收。 |
| `ow/ip/side_ch` | 上游 IQ/CSI 侧通道；主解码帧不从此出口输出。派生 Linux `side_ch.c` 增加可选双路 IQ 初始化参数。 |
| `openwifi/system_top.v`、`board.xdc`、`board_timing.xdc`、`retarget.tcl` | 本板新增/修改的顶层、引脚/时序和 BD 适配，处理 XC7Z045、PS 参数、复位及未用接口等。 |
| `openwifi/prepare.py`、`package.tcl`、`build.tcl`、`apply_deinterleave_fix.py` | 本项目构建准备、IP 打包、工程接入和派生补丁；源码修改可复现入口。 |
| `ow/linux/driver/sdr.c` 及各 IP 驱动 | 派生自上游；解析 RX DMA 接收信息，剥离16字节私有头，设置 RSSI/速率/FCS 状态，通过 `ieee80211_rx_irqsafe()` 交给 mac80211。派生源码适配 XC7Z045 大 FPGA 识别。 |
| `openwifi/linux/{an_openwifi_pl.dtsi,an_xc7z045_rf.dtsi,start_rx.sh}`、`prepare_linux.py` | 本板设备树片段、软件暂存及 monitor 接收入口；不是完整、已部署的 Linux 发布包。 |
| 工作区 `rid_receiver/decoder.py`、`receiver.py` | 本项目独立 Python RID 实现。支持 Beacon Vendor IE `FA:0B:BC/0D`、固定布局 NAN，以及 Basic ID、Location、Authentication、Self ID、System、Operator ID 等；入口支持 monitor 网卡或 PCAP，另有合成演示。 |

### 2. 当前进度

**已有验证记录：**

- 按本次任务给定状态，AD9361 校准/BBPLL、双路 IQ 经 DMA 到 DDR 并由 PS 读取已完成；本轮不重复验证。这证明采集链可用，尚不能证明 OpenWiFi PHY 收包或其 DMA/驱动运行正常。
- 10月25日的 OpenWiFi 构建记录：`synth_latch_1103` 综合完成，`impl_latch_1103` 布线完成；解交织修改通过58,368次定向选择比较，锁存器归零。该测试范围不含完整 Wi-Fi 包解码。
- 同轮最终 DRC 为0 Error/0 Critical Warning，但 WNS **−0.641 ns**、32个建立违例；外部输入/输出延时仍有15/13项缺失，**未生成本轮 OpenWiFi bitstream**。证据：外层 `openwifi_bit_20261025_1103/` 中 `final_project_status.txt`、`impl_timing_summary.rpt`、`impl_check_timing.rpt`，以及 `提示词/10.25_11.03修复问题推进至bit流.md`。最终 DRC 口径不等于运行日志没有约束警告，也不等于时序签核。
- `rid_receiver/VALIDATION.md` 记录9项软件测试通过、3个合成目标走通 Beacon 提取→RID 解码→聚合→网页显示。Scapy 抓取/PCAP 回放和真实空口仍未完成运行验证。

**有源码/配置，实际功能待验证：** ADI 接口到 PHY 的采样率、缩放和时钟配合；同步、解调、纠错、有效 FCS；解码帧 DMA、中断与 mac80211 收帧；本板 DT/内核/驱动/FIR 组合；monitor 帧进入 RID 程序。

**尚未接通或未完成交付：** 本轮可签核 OpenWiFi bitstream 及配套启动产物；锁定内核 ABI 并部署对应模块的证据；本板 monitor 接口与 `rid_receiver` 的运行连接；真实 RID 接收与字段核对记录。现有 IQ 采集成果不能补足这些证据。

### 3. 关键断点

源文件中的实际数据路径如下，箭头表示静态连接/代码调用，并非空口验收通过：

```text
AD9361 LVDS → axi_ad9361 → ADC FIFO → cpack(四分量)
 → rx_intf.adc_data/adc_valid → 抽取/滤波等处理 → sample0 → openofdm_rx
 → byte_out/byte_out_strobe + 包信息/FCS → rx_intf
 → axi_dma_1 S2MM → PS Linux sdr驱动 → mac80211 monitor帧
 → receiver.capture() → Store.frame() → extract_frame() → decode_payload()

旁路：rx_intf.sample0/sample1 → side_ch → axi_dma_0 S2MM → IQ/CSI
```

1. **IQ → PHY：连线存在，部署和功能证据断开。** 当前 BD 明确将 I0/Q0/I1/Q1 接入 FIFO/打包器，再接 `rx_intf`；`sample0` 接 PHY，`sample1` 接 side_ch，双 RX 输入并不表示 PHY 在做双通道联合解调。`adc_intf.v` 有按有效样本二抽一逻辑，40 MSPS 输入对应20 MHz OFDM路径的预期节拍，实际节拍/缩放仍待验证。已有 DDR 中的 `I1,Q1,I2,Q2` 文件没有自动回灌 PHY 的入口，不能把 IQ 文件直接交给 RID 程序。旧 `AD9361_IQ数据采集与linux解调对接.md` 的“Linux做PHY”是另一条方案；本移植实际由 PL 做 PHY，PS Linux负责驱动与后续解析。
2. **PHY → MAC：已有模块，无合法收包证据。** `dot11.v` 确有字节输出和 CRC/FCS 判定；BD 已将解码字节/状态送给 `rx_intf`，其 AXI Stream 接 **DMA1/0x80410000 S2MM**。**DMA0/0x80400000 S2MM 是 side_ch**，不能用双路 IQ DMA 成功替代解码帧 DMA 成功。当前前置阻碍为本板硬件交付和 Linux 配套；待验证项包括有效 PHY 头、帧长、FCS及 DMA/IRQ 后的原始管理帧。
3. **MAC → RID：解析器存在，运行桥接未验收。** `decoder.extract_frame()` 要求从 Frame Control 开始、不含 radiotap/FCS 的802.11帧；`sdr.c` 的原始 DMA 缓冲含16字节私有头，驱动还声明 `RX_INCLUDES_FCS`。应优先经已有驱动→mac80211→monitor/Scapy 接口接入，而非另写裸 DMA 解析器。`capture()` 已取 `bytes(p[Dot11])` 并过滤 radiotap 标记的坏 FCS，但没有显式去除尾部 FCS 的代码；实际抓包层类型、尾部处理及 PCAP 回放的 FCS 过滤需核对，不能宣称格式已完全适配。
4. **必要依赖及覆盖范围。** 仍需最终硬件对应的 DT/启动固件、匹配内核源码/配置/符号版本及模块、AD9361/ADI/DMA 驱动和匹配 FIR/RF 配置；Viterbi IP 授权/限制尚无本轮确认。现有首版入口为信道6 HT20，不覆盖802.11b；RID 解析器只支持文档列出的 Beacon/NAN 布局，不含蓝牙或任意厂商格式。目标制式、信道和封装必须匹配，普通 Wi-Fi 收包成功不能直接认定 RID 接收成功。

### 4. 下一步 3 项任务（优先级顺序）

1. **先闭合本板 OpenWiFi 最小部署组合。** 沿用现有移植，解决已记录的跨域时序及外部接口签核问题，确认 IP 授权，生成并记录匹配 bit/XSA/启动固件/DT，锁定实际 Linux ABI 并构建对应模块。原因：目前主接收路径尚缺可部署、可追溯的整套交付。完成标准：对应版本启动日志完整，驱动及 DMA/IRQ 探测成功，monitor 接口可建立，无配置/ABI不匹配；这一步仍不算无线解调验收。
2. **再证明“已知 OFDM 空口包 → 本板有效 MAC 帧”。** 固定已知信道/20 MHz制式，沿现有 PHY→DMA1→mac80211 路径取包。原因：这是 IQ 到 RID 之间最关键的未证实环节。完成标准：保存真实抓包及日志，帧源地址、长度和内容与已知输入对应，重复收到 FCS 正确的管理帧，并记录包数与错误数。
3. **最后接入现有 RID 解析器并完成真实字段验收。** 在能访问 monitor 接口的 Linux 上准备 Python/Scapy，使用已有 `--interface`；若程序运行于 PC，先传输原始802.11 PCAP走已有 `--pcap`，核对 radiotap/FCS边界，再做实时接收。原因：解析器已经存在，优先补运行连接。完成标准：真实且封装受支持的 RID 帧可追溯到原始抓包，身份/位置等广播字段与已知目标一致，保留日志；合成 DEMO 不计入完成。

本轮盘点结束，未执行上述后续任务，等待下一步指令。
