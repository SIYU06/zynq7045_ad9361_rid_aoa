
## 1. 实际状态与汇总

日期：2026-10-24。**本次关卡未通过。** 已真实启动本机Vivado 2022.2并完成唯一一次尝试，进程退出码为 **1**；项目创建成功，但BD未成功打开，尚未执行Validate Design。

问题数：**P0 1项，P1 0项已确认，P2 2项待处理/待确认。** 这不表示不存在P1问题，而是本次在BD加载前已被阻断，尚无证据判定内部IP/连线存在P1故障。

最优先的三个问题依次为：

1. 暂存脚本把BD放在项目目录内部，Vivado拒绝将其加入工程（P0-01）。
2. 暂存副本缺少BD引用的46个本地XCI文件，其恢复/重新生成尚未验证（P2-01）。
3. 关键接收、双路IQ、DMA和新增锁定/复位连接未获得本轮Vivado验收，不能据旧输出进入硬件阶段（P2-02）。

开始时 `ow/project` 目录及 `ow/project/dma_project_openwifi.xpr` 均不存在。按补充要求优先放到Git仓库外，本次新建：

`F:\2026fpga\openwifi_validation_20261024_171700\project\dma_project_openwifi.xpr`

该XPR现已存在，但没有成功加入BD，因此不是已经打开设计的可用主工程。未另开一次GUI或batch重试。本次没有修改原HDL、BD、XDC、设备树、驱动或固定上游；没有删除现有文件、综合、实现、生成bitstream、运行仿真、编译内核或进行板端测试，没有执行git add/commit/push或上传。

## 2. 验证证据

诊断目录，下文记为 `D`：`F:\2026fpga\openwifi_validation_20261024_171700`。

实际命令（PowerShell）：

```powershell
& 'E:\thenewruanjian\vivado\Vivado\2022.2\bin\vivado.bat' -mode batch -source 'F:\2026fpga\openwifi_validation_20261024_171700\run_once.tcl' -log 'F:\2026fpga\openwifi_validation_20261024_171700\vivado.log' -journal 'F:\2026fpga\openwifi_validation_20261024_171700\vivado.jou'
```

版本实证：`D/vivado.log:2` 显示Vivado v2022.2，SW Build 3671981。退出时间为2026-10-24 17:20:34，退出码记录于 `D/exit_code.txt`，值为1。精确命令另存 `D/invocation.txt`。

已阅读原 `openwifi/build.tcl`：默认validate；创建项目、加载IP仓库、复制四份板级输入、add/open BD、执行retarget、校验、输出生成、wrapper和报告；只有action非validate才进入综合。独立副本 `D/build_external.tcl` 仅调整script_dir定位和project_dir目的地，保留原validate流程；未改动仓库内脚本。`D/run_once.tcl` 捕获失败并收集当前项目/IP状态，不再次调用validate或自动修复。

实际到达与未到达的步骤：

| 步骤 | 本次结果与证据 |
|---|---|
| Vivado 2022.2启动、工具版本判断 | 成功，日志版本头；版本检查之后成功创建项目 |
| create_project及IP仓库加载 | 成功；日志19、20行为两个本地用户IP仓库加载成功 |
| 复制源BD、顶层、两个XDC | 四文件均存在于 `D/project/board_src`；源BD副本228444字节 |
| add_files BD | 失败，日志68—75行；filemgmt 20-1381、Vivado 12-1464 |
| open_bd_design | 失败，日志76行BD 41-1333、103—111行Common 17-39与调用栈 |
| retarget及新增MMCM复位处理 | 未到达：原脚本28行在失败点之后 |
| Validate Design | 未执行：retarget内的validate及原脚本32行均未到达 |
| IP状态报告 | 失败后只读尝试report_ip_status；日志112行IP_Flow 19-4317说明当前项目没有IP实例，没有生成报告 |
| generate_target、wrapper、新地址报告 | 未执行：原脚本34行及以后均未到达 |

附带环境警告 `Common 17-741` 指本地Tcl store不可写，工具随后回退至安装目录并继续创建工程。没有证据证明它是此次终止原因，不单独列为阻塞问题。

## 3. 问题分级与处置

### P0-01：BD副本目录与项目目录重叠

- **问题编号与等级**：P0-01 / P0。
- **问题是什么**：脚本将BD复制到项目目录下的普通 `board_src` 子目录，随后用add_files作为外部子设计加入；Vivado拒绝这种目录重叠，BD没有成为工程源文件，因而无法打开。
- **证据**：`D/vivado.log:68`：`[filemgmt 20-1381] ... overlap between the sub-design directory structure and the project directory structure`。日志72、73行给出project location=`D/project`、sub-design source location=`D/project/board_src/system.bd`；75行 `[Vivado 12-1464] ... cannot be added to the fileset 'sources_1'`；76行 `[BD 41-1333] ... as it is not part of this project`。`D/failure.txt`记录 `open_bd_design $local_bd` 在派生脚本27行失败。原 `openwifi/build.tcl:20` 本身就使用 `$project_dir/board_src`，本次外置Git目录没有改变这一父子关系。
- **影响**：阻止BD打开及Validate Design；后面的输出生成、时钟/连接校验和综合均不能继续。
- **可能原因**：已确认是当前脚本的目录布局不符合本次Vivado添加子设计时的要求。不是已确认的AD9361/OpenWiFi RTL错误，也不能归因于板卡。
- **下一步操作**：在下一轮代码修改中，将外部诊断目录下的项目目录和板级源副本目录分开为同级，例如新目录 `project/` 与 `board_src/`，或者使用Vivado支持的受管sources/import流程；先只改暂存脚本路径。使用新的暂存目录，保留本次失败证据。本轮不修改、不重试。
- **通过标准**：add_files不再出现20-1381/12-1464，BD确实进入sources_1且open_bd_design成功；之后才判断Validate Design是否通过。
- **是否需要我操作**：**Codex 可继续处理**（后续单独一轮）；用户也可在Vivado GUI用新的外部工程和同级BD副本复核。

### P2-01：暂存BD引用的46个XCI未就位

- **问题编号与等级**：P2-01 / P2，恢复能力待确认。
- **问题是什么**：构建脚本只复制BD、顶层和两个XDC，没有复制BD原来引用的 `ip/.../*.xci`。新目录下这些文件不存在。本次尚未到能够生成输出的阶段，不能断言它们全部不可恢复，也不能认定安装缺少46个IP。
- **证据**：`D/vivado.log:22` 至67行，共46条 `[BD 41-2576] ... referenced by design 'system' could not be found`；包括 `system_axi_ad9361_0`（22行）、`system_openofdm_rx_0_0`（31行）、`system_side_ch_0_0`（32行）、`system_axi_dma_0_0`/`system_axi_dma_1_0`（36、37行）、`system_sys_rstgen1_0`（49行）、`system_clk_wiz_0_0`（62行）。日志19、20行证实两个用户IP仓库成功加载。
- **影响**：本次是警告，已确认终止原因是P0-01。修复P0之后仍须判定IP是否能重建、是否锁定/版本不符以及输出是否完整；若确实无法恢复，届时按实际影响升为P0或P1。
- **可能原因**：已确认新副本没有本地XCI；推测Vivado可能根据BD参数和现有catalog恢复部分或全部实例，但本次没有执行到该步骤，不将推测写成通过。
- **下一步操作**：解决目录布局后，在Vivado打开BD，先查看Report IP Status和实例的locked状态，再按报告决定恢复实例或仅复制/重新生成匹配的本地IP配置；不要下载大依赖、盲目Upgrade All或修改固定上游。恢复成功后才生成必要BD输出。
- **通过标准**：关键实例能被识别，没有无法解决的missing/locked IP，Report IP Status给出有效实例列表，必要输出生成无ERROR；无需完整综合才能完成此检查。
- **是否需要我操作**：**Codex 可继续处理**（P0解决之后）；若出现实际许可证缺失，再由用户确认许可环境。

### P2-02：关键链路、约束及新旧输出尚不能交付硬件验证

- **问题编号与等级**：P2-02 / P2，验收证据缺口，不是已确认连线错误。
- **问题是什么**：此次没有打开BD，因而接收、双IQ、DMA、AXI/IRQ和新增locked复位链都没有得到Vivado校验；新XDC未登记到暂存XPR，也没有生成本轮wrapper或XSA/bit。旧工程文件存在不代表它们对应本轮源BD。
- **证据**：`D/live_state_failure.txt` 只有 `PROJECT: dma_project_openwifi`，没有BD或IP实例；日志112行确认没有IP实例。原脚本27行已失败，顶层/约束add_files及wrapper生成位于34—38行之后，未执行。`D/main_xpr_references.json`记录原主XPR仍引用 `ow/board/src/hdl/system_wrapper.v` 和旧 `system_wrapper.dcp`，这些文件存在，但本轮没有证明与当前源BD相符。
- **影响**：不构成当前加载失败的独立原因；若绕过当前关卡使用旧产物，可能影响接收、复位、DMA、Linux资源匹配及AOA数据解释。
- **可能原因**：已确认是验证在前置步骤停止导致的证据不足。以下均待确认：`AD9361→rx_intf→openofdm_rx`、`sample0/sample1→side_ch`、DMA/AXI/IRQ，以及 `clk_wiz_0/locked→openwifi_ip/bb_clk_locked→sys_rstgen1/dcm_locked` 是否在Vivado中正确接受；不将前次静态报告当作本轮通过。
- **下一步操作**：BD恢复并通过Validate Design后，在Vivado逐项查看以上路径、100 MHz基带/40 MHz采样时钟、复位极性、地址和中断；核对新wrapper端口、XDC引用及层级路径。只在完成后续必要综合/实现关卡后，才用同一XSA组织Vitis/Linux配套；本轮不运行这些流程。
- **通过标准**：Vivado Validate Design无阻塞错误，有当前IP状态、地址/IRQ及输出生成记录；顶层和两个XDC在sources/constrs中有效。时序通过、硬件启动、Wi-Fi解调和AOA还需要各自独立证据，不能由BD通过替代。
- **是否需要我操作**：源工程检查为 **Codex 可继续处理**；之后的RF时钟、PN校准及真实接收为 **需要用户确认/上板验证**，当前先不进入板端。

## 4. 已通过项及边界

- **真实Vivado结果**：2022.2启动，创建xc7z045fbg676-1暂存项目，两个本地用户IP仓库及工具IP catalog加载成功。仅到此为止，未获得BD/IP实例校验通过结论。
- **文件引用检查**：原主XPR的六条File引用均存在（包括旧DCP）；四个暂存输入副本存在。记录于 `D/main_xpr_references.json`。这是文件存在性检查，不是Vivado约束或网表一致性验收。
- **输入保护检查**：执行前后的已记录输入SHA256无变化、无缺失，见 `D/input_preservation_result.json`；验证前后Git工作区状态完全一致，见 `D/git_status_before.txt` 与 `D/git_status_after_validation.txt`。报告是验证后新增的文件，不在这一比较时段内。
- **限制落实**：只执行一次Vivado进程；未重复运行上轮静态审计；没有自动修复、重试、下载/安装、提交或远端操作。没有IP状态报告文件是因为工具拒绝生成，不用10月20日旧报告替代。

## 5. 下一步操作顺序

明天建议先完成桌面关卡，不急着连接板卡；当前不需要在Vitis或Linux中尝试补救这个Vivado加载错误。

| 顺序 | 软件与具体动作 | 预期结果/通过标准 | 失败后的下一步 |
|---|---|---|---|
| 1 | 代码/Vivado：调整下一份暂存入口，将project和board_src设为同级；在全新外部目录创建项目并添加BD副本，保留本次失败目录 | sources_1包含system.bd，BD成功打开，无20-1381/12-1464/41-1333 | 若仍报目录问题，收集新命令/路径和报错；不要改RTL或覆盖主工程 |
| 2 | Vivado：查看Report IP Status，核对46条XCI引用的恢复情况、六个OpenWiFi核和ADI接口/DMA实例；执行Validate Design | 关键IP实例存在、无未解决missing/locked项，Validate Design无阻塞ERROR | 按具体实例和报错处理；若缺许可/版本，先确认环境，不批量升级或下载依赖 |
| 3 | Vivado：核对接收、双IQ、AXI/DMA/IRQ及locked复位路径，生成必要BD输出，核对wrapper、顶层和两个XDC | 有本轮的输出/地址/中断/IP报告及有效源引用，明确尚未做时序和上板验收 | 接口/约束问题按具体路径修复，再单独安排综合实现与RF/板端验收；不使用旧bit/XSA绕过 |

步骤1、2可继续交给Codex处理；用户亲自操作时按表中GUI结果复核即可。未解决前无需尝试加载新驱动、启动抓包或校准AOA。

## 6. 最终状态

**未通过。** 唯一一次真实Vivado尝试退出码1，停在BD加入/打开阶段；Validate Design、IP完整性检查和必要输出生成尚未执行完成。已定位当前P0目录布局问题，按要求保留全部输入和失败证据，停止本轮修复与重试。
