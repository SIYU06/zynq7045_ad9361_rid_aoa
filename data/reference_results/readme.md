# 离线复现记录

日期：2026-11-04。本轮不接板，按分层方法检查构建与保存数据重算。
历史最后部署报告位于 `../final_fpga_results`；本轮新输出位于本目录。

| 检查 | 证据 |
|---|---|
| 整理目录中 3 轮算法、HTTP 和一个 FPGA 示例 | `quick_rounds_v2/round_1` 至 `round_3` |
| 重新解压的工程包中再执行 3 轮相同验收 | `package_quick_rounds/round_1` 至 `round_3` |
| 保存数据与受控输入分别核对 | 各轮 `algorithms/offline_verification.json` 的 `kind` 字段 |
| 参考 C 解码和 DOA 数值、ARM 编译 | `c_reference` |
| JavaScript 与历史观测记录 | `frontend_check/frontend_verification.json` |
| 内核准备与 10 个驱动 | `kernel/build.log`，`kernel/source_integrity.json` |
| 完整 ARM uImage 编译、CRC 与版本校验 | `kernel_image/build.log`、`kernel_image/kernel_image_verification.json` |
| 新内核与参考的 10,870 个共有导出符号 CRC 对比 | `kernel_image/symbol_comparison.json`，0 个差异 |
| 提交版匿名内核重建与再次校验 | `kernel_image_anonymous`：镜像 CRC、版本与 10,870 个共有导出符号 CRC 一致 |
| A/B 全流程 FPGA 重建 | `fpga/A`、`fpga/B`；[与参考对比](FPGA_COMPARISON.md) |
| BOOT 分区与 FPGA payload 校验 | `boot/A`、`boot/B` |
| A/B 设备树全部属性与新增地址 | `device_tree/device_tree_verification.json` |
| A/B 运行文件覆盖包生成、重读与 ABI | `board_overlays_rebuilt/overlay_verification.json` |
| 解压后全部文件哈希、源文件一致性 | `package_source_verification.json`、`reproduction_summary.json` |
| 重新解压后两站 BD/IP 生成及输入完整性 | `package_fpga_validate/A`、`package_fpga_validate/B` |
| 实际综合输入路径边界及已打包输入核对 | `hardware_source_verification.json` |

本目录只收录必要报告、校验摘要及最终 FPGA 输出，不收录工具缓存、中间综合文件或多份运行转储。
六轮每轮均通过 34 项算法检查、46 项 HTTP 检查及同一个 DSSS/AXI 示例。
仿真逐字节匹配 134 字节帧，检查错误 FCS、缓存占用保护、过期 ACK、有效 ACK 与禁用操作；
输入是受控 IQ，不是新增空口实收。
JavaScript 检查覆盖 22 个文件，以及 35 条、75 条两份历史观测记录的加载与回放标记。

本轮完整 FPGA 构建分阶段完成：在独立解压目录生成 IP、完成综合，再由新的实现运行完成布局布线与
bitstream/XSA 导出；最终报告核对使用相同 RTL 和约束，没有修改时序例外来满足门控。
本轮新 bitstream/XSA 随报告保存；新 uImage 和生成的 BOOT/覆盖包由脚本重新生成，
包中保存其校验摘要，`board_support` 保留既有启动参考以便对照。
提交匿名审查后，`board_support/boot/common/uImage` 更新为同源码/配置、使用通用构建账号的重建镜像；
对应新校验位于 `kernel_image_anonymous`。原镜像的校验记录仅作为历史构建记录保留。

归档解压复核的收据记录的是加入最终报告前的候选包 SHA256。最终包增加本轮报告后整体哈希会改变；
首次封包时，`reproduction_summary.json` 对全部 3,423 个源文件与候选包测试输入进行了核对。
后续接口移植说明更新及匿名处理，更新了 4 份文档、2 处 HDL 生成头部的主机注释，以及内核镜像脚本的
构建账号/主机名设置。其余 3,416 个源文件与已测试输入一致，RTL 功能、业务运行代码与硬件配置保持一致。
匿名内核已实际重建并核对 CRC/版本/导出符号；报告仅处理主机元数据，资源、时序、告警与数值结果未改动。
摘要分别记录已测试输入与当前文件哈希，并列明各类变更。
最终 ZIP 整体校验值见包外 `.sha256`；全部包内文件（索引自身除外）见 `SOURCE_FILES.csv`。

## 已处理的构建输入问题

- 恢复内核配置解析需要的 `samples` 与 `Documentation/Kconfig`，解决干净解压后配置阶段缺文件。
- 补全工程使用的接口定义目录，解决独立 IP 目录中的总线/抽象接口定义缺失。
- 构建脚本新建 `repro_impl_A/B`，避免旧实现运行元数据在新目录生成空执行脚本。
- A 设备树源码与随包实际参考 DTB 的全部节点属性对应，B 由相同底座及明确的 DSSS overlay 生成。

## 解释范围

保存 IQ 的相位、质量与记录值可以重新计算；DSSS/RID 帧与参考 C 解码字段核对。
受控相位及几何输入用于功能检查，不能据此证明实机场景测向精度。
最近保存的 IQ 数据虽满足质量条件，但对应参考状态不满足发布绝对角度的条件；
复现检查保留这一门控，没有将其改写成有效绝对测向结果。

不接板条件下没有重新确认上电、驱动加载、空口接收、当次相位参考和定位精度。
界面自动化连接不可用，本轮没有完成浏览器按钮点击；HTTP、资源、JavaScript 与记录检查分别记录，
点击回放/暂停/拖动等操作请按复现指南手动验收。
相同 XC7Z045 芯片目标硬件的接口移植清单与验收步骤见
`../source_code/reproduce/HARDWARE.md` 和 `BOARD.md`；完成适配后，在目标硬件上验收启动、接收及测向。

Vivado 的 PS7-6 告警指出 ZC706 预设与当前板级设置不同。工程针对自制板，参数需要按 BD、PS 设置及
实际原理图核对，不能将 ZC706 预设当成该自制板的实机验收。部分板外 RF/GPIO 端口缺少输入/输出延迟，
内部建立/保持/脉宽与总线偏斜检查通过仍不等于板外接口完成时序签核。
DRC Warning/Advisory 与 CDC 报告原样保留，未声称完成全部跨时钟结构的独立签核。
