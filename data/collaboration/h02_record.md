# XC7Z045 + AD9361 + OpenWiFi + AOA 本轮验收

日期：2026-10-23。执行依据：同目录 `26.10.23_0.54.51ai工作.md`。

本轮完成了源工程修复和有限静态审计，建立在已有移植基础上；**尚未完成首次Wi-Fi接收验收**。没有运行综合、实现、bitstream生成、长仿真、内核编译或板端命令，没有下载依赖、改动固定上游源码、覆盖引脚约束或提交Git。

## 1. 主工程与四类来源

以下路径除特别说明外，相对于 `F:\2026fpga\zynq7045_ad9361_rid_aoa`。

| 来源 | 路径与实际使用内容 | 复用边界 |
|---|---|---|
| A：队友AD9361双路工程 | `demo_vivado_v2_IQ/demo_v2/ofdm_80211n_2r2t_v1/`，裸机程序在 `vitis_ws_IQ/vitis_ws/workspace_amd/ad9361_app_v2/src/`；既有移植已提取本板PS设置至 `openwifi/board_ps_settings.tcl`，RF候选配置记录于 `board_profile.json` | 保留原工程、两路IQ、候选延时和板级配置。本轮没有修改该参考工程。OpenWiFi工程使用ADI `axi_ad9361`，并非直接沿用队友自定义LVDS RTL；换接口后的PN校准仍必需 |
| B：AOA仿真 | `uav-rf-aoa/v1_ideal_simulation/aoa_two_antenna_sim.py`、`v2_phase_calibration/aoa_phase_calibration_sim.py`；提交 `cdcd782e52c986bf6ac20ceb3f5239b27886fc9b` | 参考同步双路复数序列、复共轭平均和相位标定要求；没有导入PL、改写算法或运行仿真 |
| C：官方OpenWiFi | `upstream/openwifi-hw/`、`upstream/openwifi/`，嵌套OpenOFDM与ADI HDL；构建副本在 `ow/ip`、`ow/adi-hdl`、`ow/board/ip_repo` | 复用六个OpenWiFi IP、ADI接口/打包/FIFO、官方BD连接和驱动绑定；本轮只改板级适配及派生Linux驱动 |
| D：老师USRP方案 | 工作区根目录 `基于USRP4120的OPENWIFI设计和使用说明(4)(1).doc`，已有转换件 `F:\2026fpga\tmp\openwifi_usage_converted.docx`，项目内既有 `openwifi/老师方案对照审查.md` | 本轮复核转换件中的ARM/FPGA分工、设备树地址/中断适配和128点FFT描述。借鉴部署方法，不导入其板卡参数、约束、PS设置、bitstream或FFT配置 |

实际XPR入口是 `dma_project/dma_project.xpr`，其中sources_1指向 `ow/board/src/system.bd`、`system_top.v` 和生成wrapper，顶层为 `system_top`；约束指向 `board.xdc`、`openwifi_timing.xdc`。`dma_project/dma_project.srcs/.../system.bd` 是旧DMA示例，不能将其地址/DMA模式当成OpenWiFi现状；根目录的其他OFDM工程也不是本轮主入口。

继续开发时优先使用 `openwifi/build.tcl validate` 创建的独立 `ow/project/dma_project_openwifi.xpr`。该脚本会生成BD输出，并拒绝覆盖已有暂存XPR；本轮没有执行它。当前源BD标记 `validated=false`，生成wrapper、旧XSA/bit/ELF均不能作为本轮构建通过的证据。

## 2. 固定上游及依赖完整性

| 仓库 | 本地HEAD（已与sources.lock.json逐项核对） |
|---|---|
| openwifi-hw | `fa6c89687e4637f07adbfb41299056b6d18fd80e` |
| openwifi | `674995a130893bd9d0fe94d6ef0790ac8f43ec2a` |
| ADI HDL / 2022_R2 | `7ea497b6c24172ee293d6e0a9a387a16973da5ce` |
| OpenOFDM | `2bb3ad1a1f0023bfd15168db4e196ebf0d56d76c` |

四个仓库的已跟踪源文件没有本轮修改。硬件父仓库显示ADI子模块偏离gitlink，是既有锁定2022_R2的选择，不应直接submodule update恢复成另一版本。硬件/驱动这一候选组合尚未经过本板运行验证。

| 模块组 | 实际依赖及当前状态 |
|---|---|
| RF接口及搬运 | `axi_ad9361`、`util_cpack2`、`util_upack2`、`util_wfifo`、`util_rfifo`、`util_tdd_sync`、`util_clkdiv` |
| OpenWiFi PHY/MAC | `rx_intf`、`openofdm_rx`、`xpu`、`tx_intf`、`openofdm_tx`、`side_ch`；TX路径保留其控制/初始化依赖 |
| PS传输与控制 | 两个SG AXI DMA、AXI interconnect、PS GP0/GP1、ACP/HP3、concat、reset和clock wizard；来自现有官方派生BD |
| FPGA内部计算IP | 各核心component.xml引用的Verilog/XCI等文件存在；未执行其生成、综合或许可证检查 |
| Linux | 官方主驱动及六模块接口源码已在本地，`ow/linux/driver`增加本板识别和本轮side_ch选项；运行内核源码、配置、符号版本和ABI仍未锁定 |

本轮逐项检查13个已打包IP的component.xml，526个文件引用均存在。未发现缺少某个OpenWiFi核心源码包，但这不等于全部生成IP、许可、工具升级或内核依赖已经验收。`openwifi/ip_status.rpt` 是10月20日历史报告，未用作本轮Vivado通过证据。

## 3. 本轮实际修改

| 文件 | 本轮修改 | 验证状态 |
|---|---|---|
| `openwifi/retarget.tcl` | 显式启用MMCM locked，增加层级输入bb_clk_locked，接至基带reset控制器dcm_locked；显式设PS外部复位低有效 | Tcl结构检查通过，未在Vivado执行 |
| `ow/board/src/system.bd` | 同步上述锁定/复位连接，保持validated=false；不改AXI地址、IRQ、IQ顺序和物理引脚 | JSON和源连接审计通过，未做Vivado BD验证 |
| `openwifi/prepare_linux.py` | 新增可重现的side_ch派生补丁：可选bool模块参数iq_dual_init，默认关闭；为1时reg3写0x11，启用已有RTL双路模式 | Python语法及派生内容一致性通过，未编译C模块 |
| `ow/linux/driver/side_ch/side_ch.c`、`ow/linux/sources_manifest.json` | 将上述补丁应用到现有派生副本并更新对应SHA256 | 清单内所有文件哈希通过；固定上游未改 |
| `openwifi/export_hw_contract.py` | 从只核对DMA地址/IRQ扩展到四路IQ、共享strobe、PHY、side_ch、四条DMA流、锁定/复位、九个MMIO地址/范围和主驱动有效IRQ的检查；不匹配时停止导出 | 当前源BD通过；故意断开RX2、锁定线、共享strobe的三个内存样例均被拒绝 |
| `openwifi/hardware_contract.json` | 刷新源BD哈希、主驱动IRQ索引、复位链和审计状态 | 与源BD SHA256一致 |
| `openwifi/audit_rx_static.py`、`rx_static_audit_20261023.json` | 可重跑的有限静态审计及本轮输出 | 通过；不调用Vivado、编译器或仿真器 |
| `openwifi/linux/HANDOFF.md`、`openwifi/AOA仿真与本板接口对照.md`、`README.openwifi.md` | 补充双路模式、含头窗口长度、数据解释及本轮状态；纠正“上游缺少双路打包”的旧描述 | 文档已更新 |

`linux/an_openwifi_pl.dtsi` 已由扩展后的导出器重新核对生成，绑定内容未发生实质变化，不把既有23位DMA修改计为本轮新增。预存Git修改保持原样；本轮修改前的BD和派生驱动等保存在 `change_backups/rx_integration_20261023/`。没有自动提交。

## 4. AD9361 → OpenWiFi → DMA 当前连接

```text
AD9361 LVDS → ADI axi_ad9361
  I0/Q0/I1/Q1 → util_ad9361_adc_fifo → util_cpack2(4×16bit)
  → rx_intf.adc_data[63:0] + adc_valid
  → adc_intf公共抽取/跨域 → 接收滤波/DDC
      ├─ sample0 + sample_strobe → openofdm_rx
      │    → 解码数据/FCS等反馈 → rx_intf.m00_axis
      │    → axi_dma_1.S2MM → ACP → PS
      └─ sample0/sample1 + 同一sample_strobe → side_ch
           → side_ch.m00_axis → axi_dma_0.S2MM → HP3 → PS
```

四个ADC分量分别进入FIFO lane0=I0、lane1=Q0、lane2=I1、lane3=Q1；源BD连线检查通过。`sample0`内部为 `{I0,Q0}`，`sample1`为 `{I1,Q1}`，side_ch入口交换各32位字内部的半字后再双路拼接；小端内存中样本顺序为I0/Q0/I1/Q1。ADI数据格式寄存器、接收缩放、天线选择和真实物理左右关系仍需实测，不能仅凭总线顺序认定符号/幅度已经正确。

当前40 MSPS入口、20 MHz接收配置预期得到20 MSPS解调/side_ch取点。`adc_intf.v`使用抽取计数及两级采样跨域，不是可由本轮静态连接检查证明无风险的异步FIFO；保留官方实现及既有约束，不擅自重写。需在Vivado检查相关时钟关系和CDC报告，再由ILA确认valid、连续性及复位恢复。

## 5. Linux资源与时钟对应

| MMIO资源 | 地址 / 范围 | 绑定或用途 |
|---|---|---|
| ADI axi_ad9361 | 0x79020000 / 64K | 基础ADI ADC/DDS设备树；PL片段不代替该节点 |
| DMA0 | 0x80400000 / 64K | tx_dma；MM2S至tx_intf，S2MM来自side_ch |
| DMA1 | 0x80410000 / 64K | rx_dma；MM2S至side_ch，S2MM来自rx_intf解调帧 |
| tx_intf | 0x83c00000 / 64K | sdr,tx_intf |
| openofdm_tx | 0x83c10000 / 64K | sdr,openofdm_tx |
| rx_intf | 0x83c20000 / 64K | sdr,rx_intf |
| openofdm_rx | 0x83c30000 / 64K | sdr,openofdm_rx |
| xpu | 0x83c40000 / 64K | sdr,xpu |
| side_ch | 0x83c50000 / 64K | sdr,side_ch |

| 中断源 | F2P位 | GIC绝对ID | DTS SPI编号 / 类型 |
|---|---:|---:|---|
| rx_intf/rx_pkt_intr | 1 | 62 | 30 / 上升沿 |
| DMA1 MM2S | 2 | 63 | 31 / 高电平 |
| DMA1 S2MM | 3 | 64 | 32 / 高电平 |
| tx_intf/tx_itrpt | 5 | 66 | 34 / 上升沿 |
| DMA0 MM2S | 6 | 67 | 35 / 高电平 |
| DMA0 S2MM | 7 | 68 | 36 / 高电平 |

主sdr节点IRQ按索引排列29、30、33、34；索引0和2为保留位置，真正RX/TX分别在索引1、3，不能压缩成只有两个条目。主驱动dma-names为 `rx_dma_s2mm`、`tx_dma_mm2s`，side_ch为 `rx_dma_mm2s`、`tx_dma_s2mm`；两个DMA均保留SG，长度字段23位。数据面DMA1到ACP、DMA0到HP3，是否使用一致性属性应按最终内核DMA API和实际实现确认，未擅加dma-coherent。

PS FCLK0源配置100 MHz供ADI控制/GP0；FCLK1为200 MHz供延时控制；40 MHz `util_ad9361_divclk/clk_out`进入MMCM生成100 MHz供PHY/MAC、DMA、GP1、ACP/HP3时钟。现有网名 `sys_ps7_FCLK_CLK2` 实际由MMCM输出驱动，不能据名字当成PS FCLK2。复位链本轮新增 `clk_wiz_0/locked → openwifi_ip/bb_clk_locked → sys_rstgen1/dcm_locked`，配合低有效PS FCLK_RESET2_N；本轮未验证掉锁后的硬件恢复。

设备树片段 `an_openwifi_pl.dtsi` 用 `clkc 0x11`（PS FCLK0）描述100 MHz资源，而实际基带时钟来自MMCM；频率相同不能证明父时钟描述完整。现阶段不猜造最终时钟provider，应在最终基础DTS/XSA合入时核对。`an_xc7z045_rf.dtsi` 仍依赖基础树定义gpio0/ad9361_phy等，不是完整可启动DTB。

GPIO保留OpenWiFi映射：reset=EMIO46、sync=45、en_agc=44、enable=47、txnrx=48、ctrl=40..43、clksel=51。物理板约束本轮未动。PS/FSBL、基础DTS、SPI、ADI ADC/DDS、DMA驱动与openwifi模块必须来自同一套最终硬件/内核配套，Linux commit/config/release仍为空，不能宣称可部署。

## 6. AOA双通道保留情况

两路ADC IQ、接收适配输出及side_ch输入均保留，未为单路Wi-Fi删除RX2。官方side_ch已有双路模式，本轮通过派生驱动参数提供明确入口：重新编译匹配内核模块后可用 `insmod ./side_ch.ko iq_len_init=4096 iq_dual_init=1`；该命令本轮未执行，采样数据仍须官方用户态/netlink流程取回。

双路模式输出为一个64位TSF头 + N个64位样本对。N=4096时为32776字节；去头后的IQ载荷才是32768字节。默认单路模式的高32位是状态/RSSI等字段，不可当RX2。保留默认行为，只有显式iq_dual_init=1才切换为双路。

这是接收适配后的16位样本，不能直接当作40 MSPS、12位ADC原码；原有 `board_profile.json` 的12位符号扩展描述是原始数据交换目标，不代表side_ch当前数据缩放。尚未完成真实数据适配、连续样本/溢出记录、天线左右确认和相位标定；仿真的1 MSPS、6 cm、40°默认值均不直接写入硬件。无需本轮重写AOA RTL或新增专用AOA DMA。

## 7. 尚缺配置与首次接收阻塞项

1. **最终可用硬件产物缺失**：本轮源BD未经过Vivado validate、输出重新生成或综合实现；新锁定线、层级边界及IP升级须验证。旧bit/XSA与源工程不对应。Viterbi许可、资源及时序未确认。
2. **RF接口与启动时钟未闭环**：gpio_clksel有效电平/上电顺序未确定；ADI接口替换后的PN、LVDS反相/延时、2R2T顺序和40 MSPS必须实测。不能把队友候选延时无条件套给ADI核。
3. **完整Linux配套缺失**：没有匹配新XSA的基础设备树、FSBL/BOOT及已锁定内核ABI，派生模块未编译。现有片段不能独立启动；PHY地址/RGMII延时也未确定。
4. **首次协议数据未验证**：需已知20 MHz OFDM源验证同步、PHY头、FCS及DMA包。未证明802.11接收、丢包率或RID识别；老师文档的128点FFT配置不直接迁入当前20 MHz核。
5. **AOA采集/标定未验收**：双路硬件路径和模式存在，但没有真实窗口、相位和采集连续性的证据。此项不应阻塞先做单路Wi-Fi接收。

## 8. 下一次现场验证的前三项

1. **Vivado与ILA：确认时钟/复位及RF样本。** 在独立暂存工程中validate并重新生成输出，检查MMCM locked到reset链，核对160 MHz接口/40 MHz采样/100 MHz基带及复位极性；在硬件上先做ADI PN/延时校准，再抓两路IQ和共同valid，检查顺序、符号、削顶和掉锁恢复。完成必要时序/许可检查后再生成与导出新硬件。
2. **Linux：用同一XSA配套启动并核对资源。** 生成对应FSBL/基础DTS，合入两个片段，记录实际内核源码/config/Module.symvers/uname；编译匹配模块，核对0x79/0x80/0x83资源、DMA通道、/proc/interrupts、RF/FIR/40 MSPS读回及错误日志。不要给旧bitstream直接搭配新设备树。
3. **真实RF：先已知Wi-Fi帧，再双路IQ标定。** 用信道6 HT20已知20 MHz OFDM信号核对PHY头、DMA帧和FCS，并用参考抓包对应；随后显式启用双路side_ch、去时间戳头，确认同窗数据和预期采样率，再用已知方向/分路信号建立标定。普通扫描结果或仿真角度曲线不能代替此验收。

## 9. 本轮检查凭据与状态

- **已经修改**：锁定/复位源连接、派生side_ch双路参数、导出器/审计器及文档。
- **静态验证通过**：固定HEAD、13个IP的526个文件引用、四路IQ及共享strobe/PHY/side_ch/DMA拓扑、地址/IRQ核对、源BD哈希、派生Linux文件清单、三个断线负例、三个Python文件语法、Tcl结构完整性、Git diff --check。Git仅提示既有LF/CRLF转换，没有空白错误。
- **尚未上板验证**：全部新修改；同时未运行本轮Vivado BD验证、HDL/C编译、时序/CDC闭环或设备树编译。不得将“静态通过”表述为“可接收Wi-Fi”。

重跑有限审计可在项目根目录执行 `D:\Python38-32\python.exe openwifi/audit_rx_static.py`；源BD变化时先运行 `openwifi/export_hw_contract.py`。本机PATH中的python.exe是不可用WindowsApps别名，因此本轮使用上述现有Python3.8，不安装新环境。检查输出位于 `openwifi/rx_static_audit_20261023.json`。
