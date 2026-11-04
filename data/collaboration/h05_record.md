# 任务：直接验证现有主工程的 Block Design

本轮只做一件事：**找到当前整个项目真正使用的主 Vivado 工程，验证它实际引用的 BD，并输出清晰的问题清单。**

不再创建暂存工程，不复制文件，不调整工程目录。

## 一、利用已有报告快速定位

上一轮工作报告提供了以下线索，请优先核对，不要重新遍历整个项目：

- 主工程候选：`dma_project/dma_project.xpr`
- 当前 BD 候选：`ow/board/src/system.bd`
- 顶层模块：`system_top`
- 约束文件：`board.xdc`、`openwifi_timing.xdc`
- 旧 DMA 示例 BD：位于 `dma_project` 的工程源文件目录下，不应仅凭文件名选择。

这些是上一轮报告中的路径，不保证当前工作区完全未变。请先检查文件是否存在，再核对 XPR 实际引用关系。

如果候选主工程仍然引用上述 BD，就直接验证它。

如果引用关系已经变化，则根据实际工程引用确定正确对象，并简要说明依据。不要扫描无关的上游源码、AOA 仿真目录或所有构建产物。

## 二、直接在现有主工程中验证

1. 使用本机 Vivado 2022.2 打开现有主工程。
2. 确认工程实际使用的 BD、顶层模块和约束文件。
3. 在原工程中打开该 BD，执行 `Validate Design`。
4. 记录真实的验证结果、错误信息、相关 IP 实例、信号路径和日志位置。
5. 如果验证失败，先定位具体原因，不要自动修改或反复重试。

**禁止创建暂存工程、复制 BD、移动文件、重复添加已有文件，或使用会创建独立暂存工程的构建流程。**

## 三、重点检查什么

- BD 能否正常打开并通过验证。
- IP 是否缺失、锁定或存在版本问题。
- AD9361 → OpenWiFi 接收链的连接。
- 双路 IQ → `side_ch` 的连接。
- AXI 地址、DMA、时钟、复位和中断。
- MMCM `locked` 到 `bb_clk_locked` 再到复位控制器的连接。
- 关键外部文件引用是否有效。

只报告本次验证实际发现的问题。不要把尚未运行综合、时序分析或上板测试的问题误报成已发生的错误。

## 四、问题报告必须让我一眼看懂

每个问题单独列出：

- **问题等级**：P0 / P1 / P2。
- **问题是什么**：用简单中文说明。
- **证据**：报错原文、文件位置、IP 实例或信号路径。
- **影响**：阻塞哪个后续环节。
- **下一步怎么做**：明确需要修改什么、在哪里修改。
- **通过标准**：怎样才能确认修复成功。

等级定义：

- P0：当前 BD 无法打开或验证，流程无法继续。
- P1：会阻塞后续综合、实现或硬件启动的关键问题。
- P2：不阻塞当前 BD 验证，但可能影响后续 DMA、Linux 或 AOA 的问题。

区分已确认问题与待验证风险，不要将推测写成事实。

## 五、严格控制成本

- 本轮不修改源文件、BD、约束、设备树或驱动。
- 不运行综合、实现、Bitstream 生成、仿真或 Linux 编译。
- 不安装依赖、不下载新代码、不自动修复。
- 不执行 Git add、commit、push，不上传任何文件。
- 只运行一次 BD 验证；失败后收集证据并停止。

最后只需要告诉我：

1. 实际主工程和 BD 分别是什么。
2. BD 验证是否通过。
3. 发现了哪些具体问题，按优先级排序。
4. 我下一步应该做什么。

现在直接执行，不要先写长篇方案。





# 现有主工程BD直接验证结果

日期：2026-10-24。只运行一次Vivado 2022.2进程，退出码1。没有创建暂存工程、复制BD、添加已有文件、运行构建脚本或保存工程/BD；没有修复、升级IP、综合或重试。

## 实际对象与结论

- 主工程：`F:\2026fpga\zynq7045_ad9361_rid_aoa\dma_project\dma_project.xpr`。
- 实际sources_1中的BD：`F:\2026fpga\zynq7045_ad9361_rid_aoa\ow\board\src\system.bd`，不是旧DMA示例BD。
- Vivado读取的顶层：`system_top`。
- XPR约束：`ow/board/src/board.xdc`、`openwifi_timing.xdc`；文件均存在。
- 工程成功打开；BD读入部分结构，但 `open_bd_design` 最终返回错误；**Validate Design未执行，不能判定通过。**

为保护原文件，本次选择 `open_project -read_only`。这属于本次验证方法的限制：Vivado明确禁止BD修改，读入时设置IP参数失败。因此本次不能证明普通可写打开时仍会出现相同错误，也不能据此判断参数取值非法。没有把“Successfully read diagram”一行当作整个open_bd_design成功。

## 问题1：只读打开方式下，BD参数恢复失败

- **问题等级**：P0，仅指本次验证流程阻塞；不是已确认的硬件设计缺陷。
- **问题是什么**：Vivado报告项目只读、设计IP锁定；随后加载BD时无法设置多个IP参数，open_bd_design失败，因而未进入Validate Design。
- **证据**：同目录 `vivado.log:24—26`，`[BD 41-1663] ... Project is read-only`；27行起 `[BD 41-1661] ... IPs have been locked`。93—97行两个DMA的 `S_AXIS_S2MM.HAS_TKEEP=1`、`c_sg_length_width=23` 设置失败；137行为 `openwifi_ip/sys_rstgen1.C_EXT_RESET_HIGH=0`，156行为 `clk_wiz_0.USE_LOCKED=true` 设置失败；100—160行还包含AXI互连地址宽度及PS接口属性设置失败。均为 `[IP_Flow 19-2322]`。224—231行记录 `[Common 17-39] 'open_bd_design' failed`。完整阶段记录在 `result.txt`。
- **影响**：本次无法执行BD验证，也未得到可用的Report IP Status，接收链/side_ch/DMA/IRQ/locked复位连线均不能宣称已通过Vivado检查。
- **原因边界**：只读限制已确认；锁定是否还有其他原因，需要正常打开后查看Report IP Status。不能把这些错误解释成40多处独立设计问题或IP许可证故障。现有MMCM XCI的USE_LOCKED本来就是true，reset XCI的C_EXT_RESET_HIGH本来就是0，故“设置失败”本身不证明值不支持。
- **下一步怎么做**：下一轮在Vivado 2022.2以普通模式打开同一主XPR，不调用retarget/build脚本；先查看Report IP Status和BD参数恢复情况。需要同步IP配置时明确记录变更，不盲目Upgrade All。成功打开后再执行一次Validate Design。本轮失败后已停止，未再次启动Vivado。
- **通过标准**：open_bd_design正常返回，Report IP Status能区分实际锁定原因，Validate Design实际执行并无阻塞ERROR。

## 问题2：源BD与现有DMA配置文件长度字段不一致

- **问题等级**：P2，配置一致性问题；尚未证明是正常模式下独立阻塞BD的错误。
- **问题是什么**：源BD要求两个DMA的SG长度字段为23位，两个现有本地XCI仍记录14位。
- **证据**：日志94、97行读入的目标值为23。以下文件的 `ip_inst.parameters.component_parameters.c_sg_length_width[0].value` 均为14：
  - `ow/board/src/ip/system_axi_dma_0_0/system_axi_dma_0_0.xci`
  - `ow/board/src/ip/system_axi_dma_1_0/system_axi_dma_1_0.xci`
- **影响**：BD与现有生成配置尚未统一；不能将旧输出当作23位DMA硬件交付。对后续大IQ窗口及Linux长度属性存在实际匹配风险，但本次没有DMA运行故障证据。
- **下一步怎么做**：主工程正常打开后，在Vivado两个AXI DMA实例中确认目标值23，按BD同步IP配置并重新生成必要输出；同步需要在允许修改配置的后续任务中执行。本轮不将BD降回14来消除报错，也不改设备树。
- **通过标准**：BD与两个DMA的实际IP配置、重新生成的输出统一为23，相关IP无未解决locked/configuration错误；后续软件与同一硬件版本配套。

## 其他检查边界

本次原工程的六条XPR File引用均存在，包括wrapper、两个XDC及旧DCP，见 `xpr_references.json`；文件存在不代表内容与源BD一致。两个本地用户IP仓库由Vivado成功加载。没有发现上一轮暂存目录重叠错误，也没有本次证据证明缺少46个IP包。

没有完成AD9361→rx_intf→openofdm_rx、双IQ→side_ch、AXI地址、DMA、时钟/复位/IRQ和locked链路的Vivado验收；没有将这些未完成项列为已发生的连线错误。未运行综合、时序、上板或Linux测试，不将其列为故障。

`input_preservation_result.json` 显示主XPR及其六条输入引用的文件SHA256未改变、未丢失。没有修改原项目源文件。日志目录是诊断输出，不是独立Vivado工程。

## 执行证据

```powershell
& 'E:\thenewruanjian\vivado\Vivado\2022.2\bin\vivado.bat' -mode batch -source 'F:\2026fpga\openwifi_main_validation_20261024_174400\validate_main_once.tcl' -log 'F:\2026fpga\openwifi_main_validation_20261024_174400\vivado.log' -journal 'F:\2026fpga\openwifi_main_validation_20261024_174400\vivado.jou'
```

退出码：`exit_code.txt` = 1。日志版本为2022.2；退出时间17:46:34。本轮最终结论是**未完成Validate Design，不能判定通过**，先解决正常打开时的参数恢复与IP状态，再判断实际连接问题。

---

# 后续补充：原主工程BD已验证通过（2026-10-24 17:52）

**最新结论：通过。** 用户进一步授权“把BD验证成功”后，已直接在原主工程中完成必要修复、真实Validate Design和保存。本段取代上文“未完成Validate Design”的当前状态，上文失败过程保留作历史证据。本轮不再采用之前只读/失败即停的限制。

## 1. 实际验证对象与执行方式

- 主工程：`F:\2026fpga\zynq7045_ad9361_rid_aoa\dma_project\dma_project.xpr`。
- 实际BD：`F:\2026fpga\zynq7045_ad9361_rid_aoa\ow\board\src\system.bd`。
- 顶层仍为 `system_top`，保留原 `board.xdc`、`openwifi_timing.xdc`。
- 使用本机Vivado 2022.2普通模式打开原工程，没有创建新Vivado工程、复制BD到工作副本或移动工程目录。

日志及备份目录：`F:\2026fpga\openwifi_bd_fix_20261024`。该目录没有另一个Vivado工程，只存诊断脚本、日志和原输入备份。

## 2. 本轮完成的修改

1. **普通模式恢复参数。** 不再使用 `open_project -read_only`；BD成功打开，第一次 `validate_bd_design` 就返回成功。之前只读模式下的IP锁定/参数设置失败未再出现，不能把其作为当前设计故障。
2. **同步两个DMA配置。** 原BD和 `system_axi_dma_0_0.xci`、`system_axi_dma_1_0.xci` 的 `c_sg_length_width` 现均为23；没有将BD降回14或改设备树绕过差异。
3. **修复7个未驱动输入。** 首次验证通过但报 `BD 41-759`，工具默认将未连接输入拉0。依据已有 `openwifi/retarget.tcl` 的定义，补入以下显式常量：

| 输入 | 固定值 | 位宽 |
|---|---:|---:|
| `openwifi_ip/dma_data` | 0 | 64 |
| `openwifi_ip/dma_valid` | 0 | 1 |
| `openwifi_ip/openofdm_rx_0/para_valid` | 0 | 1 |
| `openwifi_ip/openofdm_rx_0/para_rx_sensitivity_th` | 0 | 10 |
| `openwifi_ip/side_ch_0/openofdm_tx_iq1` | 0 | 32 |
| `axi_iic_main/scl_i` | 1 | 1 |
| `axi_iic_main/sda_i` | 1 | 1 |

常量位于相应目标的所属层级。最后两项是未使用的参考I²C核输入，明确固定为闲置高电平；没有更改真实接收IQ输入。

4. **复验并保存。** 修复后再次运行 `validate_bd_design` 成功，随后 `save_bd_design` 成功。保存后的BD为 `design_info.validated=true`。两次验证都通过，第二次用于确认7项修复；没有降低检查等级或屏蔽BD错误。

实际持久化变化为源BD及Vivado同步的15个既有XCI，并新增7个常量IP配置。既有输入变更清单见 `final_evidence.json`。主XPR、顶层Verilog和两个XDC内容哈希未变；固定上游、设备树和驱动未改，没有Git提交或上传。

## 3. 最终通过证据

实际最终命令（PowerShell）：

```powershell
& 'E:\thenewruanjian\vivado\Vivado\2022.2\bin\vivado.bat' -mode batch -source 'F:\2026fpga\openwifi_bd_fix_20261024\attempt2_finalize.tcl' -log 'F:\2026fpga\openwifi_bd_fix_20261024\final.log' -journal 'F:\2026fpga\openwifi_bd_fix_20261024\final.jou'
```

以下文件均位于上述日志目录：

- `final.log:383`：`BD_GATE_FINAL_VALIDATE_PASS`。该标记在真实 `validate_bd_design` 正常返回后输出。
- `final.log:384`：`Wrote : <...\ow\board\src\system.bd>`，确认保存原BD。
- `final_result.txt`：`VALIDATE=PASS`、`SAVE_BD=PASS`、`RESULT=PASS`，同时记录DMA长度、实际信号连接及地址段。
- `final_exit_code.txt`：0；Vivado退出时间为2026-10-24 17:52:57。
- `final_ip_status.rpt`：53个IP均为Up-to-date，原46个IP加7个常量IP；查询没有锁定实例。
- `final_evidence.json`：ERROR列表为空。保存BD的SHA256为 `03ec77c78118d5ddae5f8cbd5d5bdcd1856f4a0c3d7119aaa4d664550f232702`。
- `attempt1.log`、`attempt1_result.txt`：保留首次普通模式验证通过及发现未驱动输入的过程。
- `original_inputs.zip`、`inputs_before.json`：修改前原输入和XCI备份及哈希。
- 主XPR和源BD的 `git diff --check` 通过。

## 4. 实际查询确认的连接

不是仅凭静态JSON推测，以下连接已通过Vivado对象查询记录于 `final_result.txt`：

- 四个AD9361接收分量保留；`rx_intf_0/sample0` 同时连接 `openofdm_rx_0/sample_in` 与 `side_ch_0/sample0_in`。
- `rx_intf_0/sample1 → side_ch_0/sample1_in`，双路共用 `sample_strobe`，未删除RX2。
- `rx_intf_0/m00_axis → axi_dma_1/S_AXIS_S2MM`；`side_ch_0/m00_axis → axi_dma_0/S_AXIS_S2MM`。
- `clk_wiz_0/locked → openwifi_ip/bb_clk_locked → sys_rstgen1/dcm_locked` 层级连接存在；基带复位输出连接保留。
- AXI地址段和IRQ_F2P连接有实际查询记录，本轮没有重分配地址或IRQ。

以上证明本轮BD结构校验和连接查询通过，不证明RF样本、Linux运行或Wi-Fi解调通过。

## 5. 保留的非阻塞警告

当前没有阻止本次BD打开/验证的P0；本轮未发现可确认的P1错误。以下为P2待确认项，未将推测写成硬件故障：

1. **ACP USER宽度提示（BD 41-237）**：PS ACP接口AWUSER/ARUSER宽度5，连接转换器端为0。Vivado允许本次校验通过；没有猜造USER值来消警告。后续综合/一致性审查需核对转换器、ACP事务属性及DMA缓存策略。
2. **时钟/复位元数据传播提示（BD 41-927）**：涉及delay_clk的200 MHz、采样相关时钟40 MHz及ACTIVE_HIGH复位属性，部分自定义IP不接受传播参数改写。本轮未修改固定IP包；后续输出生成与时序检查需核对实际时钟和约束，不能仅据此认定物理时钟错误。
3. **其他提示**：SPI0 EMIO SSIN需高电平、部分ACP非DDR地址段被排除、常量实例名称较长等仍记录在日志，不影响本次返回成功，后续各关卡按实际影响处理。
4. **工具环境回退（Common 17-741）**：本地Tcl store不可写，已回退安装目录。这是最终日志唯一CRITICAL WARNING类别提示，属于环境；最终没有BD类别CRITICAL WARNING，也没有ERROR。

`BD 41-759` 未驱动输入严重警告已消除。DMA 14/23位配置差异已解决。不为追求“零警告”扩大到无依据的硬件修改。

## 6. 最终状态与下一步

**本轮目标已完成：原主工程的原BD真实验证通过，并保存为validated=true。**

没有执行完整BD输出生成、综合、实现、bitstream、Vitis/Linux编译或上板。旧wrapper、DCP、XSA、bit不是此次BD保存后重新生成的产物；先前静态快照JSON中的BD哈希也不能替代本轮 `final_evidence.json`。

下一开发关卡是在当前已通过的BD上生成必要输出，检查ACP USER属性及传播提示，再单独安排综合、时序和硬件验收。当前无需继续重复BD验证。
