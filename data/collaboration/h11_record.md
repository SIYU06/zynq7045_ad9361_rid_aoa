# 任务：AD9361 异常诊断 + PLL 状态检查 + 动态 IQ 监测

## 一、现有工程

工程根目录：`F:\2026fpga\zynq7045_ad9361_rid_aoa`

测试工程：`baremetal_iq`

硬件：Zynq-7045 + AD9361  
工具链：Vivado/Vitis 2022.2

目前已经实现：

- FPGA Bitstream 成功烧录。
- PS/DDR 初始化成功。
- AD9361 双通道 IQ 采集已运行。
- SG DMA 连续完成两个 32776 字节窗口。
- JTAG 导出真实 IQ 成功。
- Python 离线分析与绘图成功。

**本轮不修改 PL、BD、XDC、Bitstream。**

## 二、任务1：诊断 AD9361 初始化异常

目前每次初始化都会出现：

```text
ad9361_setup: Either set ENSM PINCTRL or FDD Independent Mode
Calibration TIMEOUT (0x5E, 0x80)
ad9361_init : AD9361 Rev 2 successfully initialized
```

要求：

1. 定位两条异常日志的驱动源码及触发条件。
2. 确认 `0x5E/0x80` 对应的实际校准或锁定检查。
3. 在超时发生时及初始化完成后，读取对应 SPI 寄存器和 BBPLL 锁定状态。
4. 核对参考时钟频率、BBPLL 参数、ENSM 模式与当前板卡配置。
5. 查明为什么出现超时后仍打印初始化成功。
6. 如果确认属于软件配置问题，进行最小修改并验证；如果涉及硬件，明确指出需要的具体资料。

不要盲目扩大超时时间，不要通过屏蔽错误来伪造初始化成功。

## 三、任务2：增加 AD9361 状态诊断

在现有 Vitis 裸机程序中增加简洁的诊断输出：

- AD9361 参考时钟参数。
- BBPLL 锁定状态及相关寄存器。
- RX/TX LO 频率和锁定状态。
- ENSM 当前工作状态。
- RX1/RX2 增益、采样率、带宽。
- 校准结果及异常状态。
- SG DMA 状态、错误码、接收长度和采集次数。

优先复用现有驱动及 SPI 读取接口。

严格区分目标配置值、实际寄存器读回值和推算值。不可获取的数据标注 N/A。

不重新编写驱动，不做无关功能扩展。

## 四、任务3：开发 PC 端动态 IQ 监测程序

基于现有：

- `collect.py`
- `analyze_iq.py`
- XSCT/JTAG 导出流程
- 已有 IQ 数据格式和 DMA 缓冲区管理

新增 `live_iq.py`。

### 界面设计

界面采用**简洁、美观的深色 SDR 仪表盘风格**，字体、配色、曲线和布局统一，适配普通电脑屏幕。

显示以下内容：

1. RX1-I、RX1-Q、RX2-I、RX2-Q 四路动态时域波形。
2. RX1/RX2 的 FFT 频谱。
3. RMS、峰值、直流偏置、幅度差。
4. 双通道相位差与相关性。
5. 采样率、LO 频率、DMA 状态、窗口序号、实际刷新率。
6. AD9361 PLL/ENSM 状态及异常提示。

### 数据更新方式

`DDR 捕获 → JTAG 导出 → Python 解析 → 更新图形`

要求：

- 连续捕获多个 IQ 窗口并动态刷新。
- 支持开始、暂停、停止。
- 可选择保存原始 IQ 文件。
- 不重复初始化 AD9361。
- 使用现有 DDR 缓冲区和采集控制接口。
- 处理好缓冲区导出与释放顺序。
- 标注真实刷新率；不宣称实现了连续 20 MSPS 实时传输。

优先采用 Python + matplotlib，不引入大型 GUI 框架。

复用 `analyze_iq.py` 的解析和 FFT 逻辑，避免重复代码。

## 五、执行顺序

1. 读取现有 AD9361 驱动及 `baremetal_iq` 相关代码。
2. 定位并处理初始化异常及 PLL 问题。
3. 增加必要的 AD9361 状态读回与日志。
4. 开发美观、可动态刷新的 `live_iq.py`。
5. 进行一次必要的联合硬件测试，验证初始化、采集、动态刷新。

如果板卡暂时不可访问，先完成代码开发与离线检查，不要反复尝试连接。

## 六、Token 与工作范围限制

**优先解决实际问题，严格避免无效 Token 消耗。**

- 不扫描整个仓库。
- 不进行全面审计或无关重构。
- 不修改 FPGA PL 及 Bitstream。
- 不重新综合、布局布线。
- 不处理 Linux、OpenWiFi、RID 或 AOA。
- 不涉及队友的任何代码或工程。
- 不添加大量防御性代码。
- 只保留保证 DMA、DDR 数据正确性所必需的检查。
- 不反复运行相同测试。
- 尽量复用已有函数和项目结构。
- 不执行 Git add、commit、push。

直接执行，不必每一步都征求确认。

## 七、最终交付

简短汇报：

1. AD9361 初始化异常的真正原因，以及是否解决。
2. BBPLL、ENSM、射频参数的实际读回结果。
3. 修改了哪些文件。
4. `live_iq.py` 的启动命令和使用方法。
5. 动态界面是否经过真实板卡测试，以及实际刷新效果。
6. 剩余问题和下一步操作。

完整日志追加到本轮任务 MD 中，终端只输出关键结果。

**最终目标：解决 AD9361 初始化异常，确认锁相环状态，并建立美观、可重复使用的 PC 端动态 IQ 监测工具。**

---

## 执行结果与启动说明（2026-10-25 23:24）

**本轮已解决所述ENSM配置冲突和BBPLL未锁定问题，真实板卡动态监测联合测试通过。** 最终初始化超时计数0，BBPLL/RX LO/TX LO均锁定；GUI实际显示4个新采集窗口，暂停、恢复、停止通过。没有修改PL、BD、XDC或Bitstream，没有操作其他工程及队友源码，没有Git提交/推送。

### 1. 异常的真实原因与修复

1. `ad9361.c/ad9361_setup()` 在 `ensm_pin_ctrl && fdd_independent_mode` 同时为真时打印冲突提示，并自动关闭前者。旧配置确实同时开启两项。现于本测试的 `board_rf.c` 明确关闭 `ensm_enable_txnrx_control_enable`，保留FDD Independent；最终有效配置为PINCTRL=0、Independent=1。
2. `Calibration TIMEOUT (0x5E,0x80)` 是 **BBPLL VCO锁定检查**，不是RX/TX射频PLL检查。基线诊断在超时当刻及初始化结束后均读到 `0x05E[7]=0`，即真实未锁定。此前“有IQ”和“初始化成功”均不能替代该检查。
3. **参考时钟路径选错是主要配置根因。** 原理图第4页：PE4259 U53的RF1接板载时钟、RF2接外部U.FL J5；pSemi真值表规定CTRL高选RF1、低选RF2。前版 `board_rf.c` 把GPIO105（EMIO51，9361_CLK_SEL）置0，选了外部输入。现明确置1，实测GPIO读回1。原理图同时显示XTALP未接、XTALN经C12接REF_CLK，因此改为 `xo_disable_use_ext_refclk_enable=1`，采用外部参考输入路径；这里“外部”是相对AD9361内部DCXO，时钟源仍是本板振荡器。
4. **超时后仍打印成功的原因已定位并修复。** 本地 `util.c/clk_set_rate()` 两处调用 `ad9361_bbpll_set_rate()` 丢弃返回值，随后无条件返回0，导致 `ad9361_setup()` 没有收到失败，`ad9361_api.c` 继续打印成功。现在传播BBPLL错误，仅成功后更新缓存及initialized标志；未放大超时，也未屏蔽错误。新加的超时钩子保存当刻SPI快照，后续失败保留DDR诊断，避免再访问可能无时钟的PL AXI。

官方依据：[ADI UG-570初始化/校准表](https://www.analog.com/media/en/technical-documentation/user-guides/ad9361.pdf)、[ADI no-OS驱动](https://github.com/analogdevicesinc/no-OS/blob/main/drivers/rf-transceiver/ad9361/ad9361.c)、[PE4259数据手册Table 5](https://psemi.com/pdf/datasheets/pe4259ds.pdf)。原理图依据为本地 `AN_XC7Z035(2).pdf` 第3、4页；本轮还保存了时钟选择及XTAL连接局部图。

### 2. 诊断过程及最终读回日志

| 阶段 | 实际结果 |
|---|---|
| 旧配置加诊断 | 超时1次：reg=0x05E、mask=0x80、observed=0；初始化后0x05E=0x01，BBPLL未锁；RX/TX锁定位当时为1 |
| 仅修复错误返回 | 初始化真实失败，不再假报成功；保留超时快照 |
| 外部参考模式、CLK_SEL仍为0 | 仍未锁，说明单独改输入模式不足；记录中共3次锁定超时 |
| 外部参考模式＋CLK_SEL=1 | 初始化成功，超时0；随后4窗口联合测试及最终复读均保持三路PLL锁定 |

期间DAP发生AHB/APB事务错误，停止了重复访问；你恢复板卡和同一份Bitstream后继续验证。曾试验ADI新版首次频率字过渡步骤，但未解决问题，**已撤去，不在最终代码中**。

最终真实SPI及配置读回：

```text
CLK_SEL GPIO105       = 1
0x009 CLOCK_ENABLE    = 0x17   (XO_BYPASS=1)
0x05E BBPLL/overflow  = 0x81   (bit7=1，BBPLL锁定；低位并非锁定位)
0x247 RX VCO lock     = 0x02   (bit1=1)
0x287 TX VCO lock     = 0x02   (bit1=1)
0x014 ENSM_CONFIG_1   = 0x28
0x015 ENSM_CONFIG_2   = 0x84
0x016 CALIBRATION     = 0x00
0x017 STATE          = 0x1A   (低4位0xA=FDD)
0x041/042/043/044     = 00/00/00/20
0x045/046            = 00/05
timeout_count        = 0
init_result          = 0
RX digital tune      = 0
```

频率来源明确区分如下，未将软件读回/计算值说成示波器测量值：

| 参数 | 数值与来源 |
|---|---|
| REF目标 | 40000000 Hz，与原理图40MHz标注相符；物理频率实测N/A |
| BB参考 | 40000000 Hz，由参考配置及SPI分频读回计算 |
| BBPLL | 1280000000 Hz，由SPI整数/小数字及参考配置计算；锁定状态另取实际位 |
| RX LO / TX LO | 2436999998 / 2400000000 Hz，驱动根据寄存器及参考参数换算 |
| RX/TX采样率 | 40000000 / 40000000 Hz，驱动时钟链换算 |
| IQ窗口采样率 | 20000000 Hz，现有PL支路二抽一所得 |
| RX/TX带宽 | 40344822 / 35301580 Hz，驱动API状态值，不是扫频实测 |
| RX1/RX2增益 | 46 / 46 dB，API读回 |

### 3. 动态界面与真实联合测试

新增 `baremetal_iq/live_iq.py`：深色matplotlib/Tk仪表盘，四路IQ、双路FFT、RMS/峰值/DC、幅差/相差/相关性、LO/采样率、序号/长度/DMA状态、SPI PLL/ENSM/超时状态。复用 `analyze_iq.py` 的解析、统计和FFT，数据线程执行有限的捕获→导出→校验→可选保存→release；UI线程绘图。未重复初始化AD9361。

真实GUI测试结果：

```text
JOINT_GUI_PASS windows=4 new-window-refresh=0.093 Hz
pause_held_without_new_windows = true
resume_received_new_window    = true
stopped_worker                = true
all_frames_bbpll_locked       = true
all_frames_rf_lo_locked       = true
error                        = null
```

4个窗口各32776字节，文件内容互不相同，均通过固件FNV、TSF及长度校验；DMA状态为 `0x0001100A`，无错误位；描述符完成状态 `0x8C000000`，实际长度32776。实际刷新约0.093 Hz（约10.7秒/新窗口，包含JTAG启动/导出、release及测试暂停），**不代表连续20 MSPS传输**。离线回放刷新更快，已明确标成REPLAY，不当作硬件实时性能。

真实数据及证据在 `baremetal_iq/diag_20261025_2254/`：

- `joint_hardware/window_000001.bin`～`window_000004.bin` 及同名JSON，保存实际RF快照和ELF哈希。
- `joint_hardware/session.json`、`joint_gui_checks.json`、`joint_gui.log`：真实刷新率、窗口序号、暂停/恢复/停止及每窗口PLL状态。
- `dashboard_hardware.png`：真实板卡联合测试截图；`dashboard_final_layout.png`：最后仅调整布局后，用上述真实文件回放的截图，图内标记REPLAY。
- `rf_baseline.log`、`rf_recovered.log`、`rf_extref.log`：失败条件证据；`rf_muxfix.log/.json`、`rf_final.log/.json`：修复及最终SPI读回。
- `build_muxfix.log`、`init_muxfix.log`、`status_final.log`：编译、PS/DDR初始化和最终mailbox状态。详细日志保留在这些文件，本节记录关键原始值。

最终mailbox为PAUSED、completed=4、error=0、active_slot=0xFFFFFFFF；4个槽在导出校验保存后均已release。程序仍在运行，可直接启动界面，无须重新初始化。

### 4. 使用方法

当前环境直接运行：

```powershell
cd F:\2026fpga\zynq7045_ad9361_rid_aoa\baremetal_iq
& 'D:\Python38-32\python.exe' .\live_iq.py
```

点击 **Start** 开始；**Pause** 在正在进行的有限窗口安全收尾后暂停，点击Start恢复；**Stop** 停止本次监测，后续可再Start。关闭窗口也等待当前有限操作收尾。默认不长期保存原始IQ；勾选 **Save raw IQ windows**，或用 `--save-raw`，将后续窗口及元数据保存到会话目录。若已有未释放槽，先保存它们再release；程序不会为腾空间直接覆盖旧窗口。锁定/初始化状态不通过时，新采集会被拒绝并显示错误。

查看当前PLL状态（不会重新初始化）：

```powershell
& 'D:\Python38-32\python.exe' .\rf_status.py
```

保存数据的监测启动例子：

```powershell
& 'D:\Python38-32\python.exe' .\live_iq.py --save-raw --output .\captures\live_new_session
```

离线查看本轮真实记录（显式回放）：

```powershell
& 'D:\Python38-32\python.exe' .\live_iq.py --replay .\diag_20261025_2254\joint_hardware --rf-log .\diag_20261025_2254\rf_final.log
```

断电后只需恢复原Bitstream，然后用 `xsct.bat control.tcl init` 初始化一次；监测期间无需重复init。修改源码后按上轮build流程重新编译、下载，不能使用旧ELF。最终ELF已编译并下载，SHA256为 `0b63caf8561b3c337ef85441aadcc24512179c77be549a529f24faa3c17bb0a7`。

### 5. 修改文件与剩余事项

必要固件修改：`src/board_rf.c`、`src/util.c`、`src/ad9361.c`、`src/main.c`；新增 `src/rf_diagnostics.c/.h`。工具修改：`control.tcl`、`run.ps1`、`write_symbols.py`、`prepare_sources.py`，新增可重复应用的 `apply_rf_patches.py`。PC新增 `live_iq.py`、`rf_status.py`；`analyze_iq.py` 抽出共用FFT并增加仅计算统计的调用方式。修改仅在 `baremetal_iq` 及本报告中，未改IDE中打开的其他 `demo_vivado_v2_IQ/.../ad9361.c`。

本轮目标已完成。REF物理频率/幅度未用仪器测量，长期稳定性及天线相位校准不在本轮验证范围；当前相位差只作观测。**下一步只需启动 `live_iq.py` 并点击Start查看真实动态IQ。**
