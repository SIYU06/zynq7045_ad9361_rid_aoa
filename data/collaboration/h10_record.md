# 任务：修复 XSCT 初始化失败，推进真实 IQ 采集

当前工程为 Zynq-7045 + AD9361，使用 Vivado/Vitis 2022.2。

现有工作目录：`baremetal_iq`
Vitis 工作区：`baremetal_iq/workspace`
Application：`iq_capture`
当前 ELF：`workspace/iq_capture/Debug/iq_capture.elf`
当前 Bitstream：`impl_latch_1103/system_top.bit`
当前 XSA：`system_top_iq.xsa`

## 一、首先解决真正的错误

运行 `.\run.ps1 init` 时出现：

```text
can't read "PCW_SILICON_VER_1_0": no such variable
Memory read error at 0x138080.
Cannot access DDR: the controller is held in reset
```

请直接检查 `run.ps1`、`control.tcl`、实际调用的 `ps7_init.tcl` 及其生成来源，定位变量未定义的真正原因。

要求：
- 确认当前 XSCT 实际加载的是哪个初始化脚本。
- 检查脚本是否与当前 XSA、器件及 Vitis 2022.2 匹配。
- 修复根因，不要随意定义一个同名变量掩盖错误。
- 修复后通过 XSCT 重新执行 PS 初始化，并验证 DDR 是否能够正常读写。
- DDR 测试不得覆盖正在使用的程序、描述符或 IQ 缓冲区。

## 二、继续推进，不要只写报告

初始化修复后，自动按顺序执行：

1. 确认 PS/DDR 初始化成功。
2. 下载并启动现有 `iq_capture.elf`。
3. 检查 UART 输出和 mailbox 状态，确认程序真正运行。
4. 检查 AD9361 初始化与校准状态。
5. 启动一次 SG DMA 捕获，读取真实完成描述符、状态和实际长度。
6. 检查 DDR 中的 IQ 数据，确认不是未初始化数据或固定重复值。
7. 导出真实 IQ 文件，再运行现有 Python 分析脚本。

每一步成功后再进入下一步。前一步失败就定位该错误，不要重复执行后续必然失败的步骤。

## 三、执行方式与 Token 限制

请自主完成可执行的检查、必要修改、编译和验证，连续工作约 15 分钟，或直到达到明确的阻塞条件。

- 优先复用现有代码和驱动，只改必要文件。
- 不修改 Vivado BD、RTL、XDC 或 Bitstream。
- 不重新综合、布局布线，不创建新工程。
- 不重复扫描整个仓库，不进行全面审计。
- 不添加复杂防御性代码，不重复跑已经通过的测试。
- 不要无限轮询 JTAG、DDR 或 DMA。
- 如果板卡未连接、未上电或硬件条件不满足，先完成离线检查，不要反复尝试。
- 不删除原文件，不执行 Git 提交或推送。

## 四、最终交付
报告添加在本报告的后边，续写
请实际执行到哪一步，就报告到哪一步：

1. 修复了什么文件、什么根因。
2. XSCT 初始化是否成功，DDR 是否实际读写成功。
3. ELF 是否真正运行，AD9361 是否完成初始化。
4. DMA 是否实际完成传输、接收了多少字节。
5. 是否生成真实 IQ 文件，Python 是否分析成功。
6. 如果仍然失败，给出最新的关键报错、已排除的原因和我下一步唯一需要执行的操作。

不要把代码编译成功等同于硬件验证通过。优先取得第一份真实 IQ 数据，尽量节省 Token。

---

## 实际执行结果（2026-10-25 22:15）

**已修复初始化错误，并取得真实双通道 IQ 文件；最终程序连续完成2个窗口，PC解析和绘图成功。** 本轮未修改BD、RTL、XDC、Bitstream，未重新综合/实现，未提交或推送Git。

### 1. 根因及必要修改

- 修改 `baremetal_iq/control.tcl`：上轮代码在 `iq_control` 函数中直接 `source ps7_init.tcl`，导致生成脚本的 `PCW_SILICON_VER_*`、`APU_FREQ` 进入函数局部作用域，而生成过程读取全局变量。已改为 `uplevel #0 [list source $ps_init]`，**没有手工补定义版本常量**。离线隔离解释器复现了旧作用域问题并验证修复。
- 实际加载路径为 `baremetal_iq/workspace/iq_hw/hw/ps7_init.tcl`；文件与当前 `system_top_iq.xsa` 内的 `ps7_init.tcl` 逐字节一致，XSA哈希也匹配既有记录，排除了加载旧初始化脚本的原因。
- 初始化增加64字节DDR读写及恢复检查，并允许CPU已停止时重试。当前XSCT不支持Tcl `try`，实现采用 `catch`，未修改生成的初始化文件。`run.ps1` 无须改动；本环境禁止直接运行ps1，实测直接调用同一Vitis 2022.2 XSCT脚本，未改变系统执行策略。
- 修改 `baremetal_iq/src/main.c`：补查第二次提交时发现DMA状态 `0x15019`，原代码仍记作完成。检查驱动后去掉每包重复的 `XAxiDma_BdRingStart`，改为仅首次启动、后续由 `BdRingToHw` 更新尾指针，并增加完成后的DMA错误检查。重新编译、下载后连续2个窗口通过，最终状态为 `0x1100A`，无DMA错误位。旧日志、旧源码备份和首轮数据均保留。

### 2. 板上实测结果

| 检查项 | 实际结果 |
|---|---|
| PS初始化 | 成功，版本变量错误消失 |
| DDR读写 | `0x02000000`，16个32位变化测试字全部读回一致，原内容已恢复；避开程序、描述符及IQ缓冲区 |
| ELF运行 | 新ELF下载后mailbox进入READY；采集后PAUSED，错误码0 |
| AD9361 | 初始化完成，双RX使能寄存器 `0xDE`，RX调谐返回0 |
| 实际参数读回 | RX 40000000 Hz，IQ路径20000000 Hz，LO 2436999998 Hz，最终增益46/46 dB |
| SG DMA | 连续2个窗口，每个32776字节，即8字节头部＋4096组双通道IQ |
| 描述符 | 实际DDR描述符状态字 `0x8C008008`：完成、SOF/EOF、长度32776，无BD错误 |
| JTAG导出 | 两个最终窗口的长度和FNV-1a均与固件记录一致，两个窗口内容不同 |
| UART | COM9访问被拒绝；COM10打开后未收到日志，未声称UART验证通过。程序运行证据来自实际mailbox、DMA描述符及DDR数据 |

最终固件保持PAUSED，两个完成槽仍保留，未release覆盖。本轮验证了两次提交，未扩展到长期采集或环形覆盖压力测试。

### 3. 真实数据及Python分析

以下路径相对于工程根目录 `F:/2026fpga/zynq7045_ad9361_rid_aoa/`：

- 最终数据：`baremetal_iq/captures/real_20261025_2203/verified_iq_0001.bin`、`verified_iq_0002.bin`。
- 对应元数据：同名 `.bin.json`，包含真实参数、序号、描述符、DMA状态、校验及本次ELF哈希。
- 分析结果：`baremetal_iq/captures/real_20261025_2203/verified_iq_0001.analysis/`，内有 `iq_time.png`、`iq_fft.png`、`analysis.json`、`analysis.txt`。
- 执行证据：`baremetal_iq/bringup_20261025_2203/`，重点为 `init_dma_fix.log`、`status_two_fixed.log`、`descriptor_verified.log`、`export_verified_1.log`、`export_verified_2.log`、`analysis_verified.log`。

最终第一窗口四路不同码值数量为176/184/216/228，均在12位有符号范围内，相邻整组重复比例0，码值极限削顶比例0；不是未初始化常量数据。I/Q四路RMS分别约24.833、25.236、34.345、37.557码值。幅度差约3.152 dB，平均相位差约−127.287°，相关性仅0.2305，不能据此认定天线相位已经校准。物理ADC削顶及窗口间丢样数仍为N/A。

**下一步只需打开上述 `iq_time.png`、`iq_fft.png` 验收真实数据。** 首份真实IQ采集目标已达到，无需再次初始化或重烧FPGA才能查看这些文件。若之后重采，在工程根目录可直接使用 `& 'E:\thenewruanjian\vivado\Vitis\2022.2\bin\xsct.bat' baremetal_iq/control.tcl init`，其余 `status/single/export` 操作同上轮README；导出应使用新文件名。
