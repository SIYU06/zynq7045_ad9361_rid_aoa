# 构建与复现入口

所有命令从仓库根目录执行。先按根目录 README 运行 `build/prepare_sources.py`，得到独立工作区。本目录提供新目录入口，具体的已验证构建逻辑保留在工作区 `source_code/reproduce/` 中。

## 快速离线与 FPGA

使用 `build/reproduce.ps1 -Workspace <工作区> -Mode quick|fpga|kernel -OutputRoot <新结果目录>`。PowerShell 中参数值不能含竖线；按根目录示例选择一个 Mode。

FPGA 的 `-Station A|B|both`、`-FpgaPhase validate|synth|impl|bitstream` 控制构建对象与终止阶段。脚本需要 Vivado 2022.2，显式传入 `-VivadoBin`。各阶段的 IP、时序、资源、DRC、CDC 和输出校验不因目录迁移而省略。

首次完整构建使用新的源码工作区，避免复用已有运行状态。参考结果在 `data/reference_results/fpga/`，新结果写入自己的 `out/`。实际构建产物可较大，默认不提交 Git。

## WSL 内核与完整镜像

根目录 README 的 `-Mode kernel` 会把工作区路径转换给 WSL，生成新的内核构建目录并在控制台输出位置。内核分卷已由准备脚本重组，无需另下载上游源码。

在 WSL 中进入解包后的 `source_code`，或从根目录按下例指定路径：

```bash
source_root="$PWD/out/workspace_01/source_code"
bash "$source_root/reproduce/build_kernel_image.sh" \
  /var/tmp/airspace_reproduction_actual/linux-427c94e8faa57cb224bd40f1a0c8fe25168be2e5 \
  "$PWD/out/kernel_image_01"
```

上例的 `/var/tmp/airspace_reproduction_actual` 必须替换为前一步真实输出目录，不能凭空创建一个空目录。构建需对应配置、已准备的内核树及 `mkimage`。生成 `uImage` 后使用工作区 `reproduce/verify_kernel_image.py` 检查 CRC 和内核版本。随包匿名重建镜像是历史离线产物，本次不据此声称新上电启动通过。

## C 参考与 ARM 编译

在 WSL/Linux、仓库根目录执行：

```bash
bash out/workspace_01/source_code/reproduce/verify_c.sh \
  "$PWD/out/workspace_01/source_code" "$PWD/out/c_reference_01"
```

检查 C 数值参考、保存的 RID 字段和 ARM ELF 输出。该验证依赖 gcc 与 `arm-linux-gnueabi-gcc`，属于离线实现对照。

## 文件完整性与验证工具

- `src/archives.json` 定义归档、内核分卷及完整内核哈希。
- `src/source_manifest.json` 定义原生源码文件的大小与哈希。
- `data/package_manifest.json` 定义本次公开交付文件的大小与哈希，不递归包含清单自身与可变 `out/`。
- `skill/scripts/verify.py` 可运行黄金 JSON、Vivado 报告、哈希与 Markdown 检查，详见技能文档。

构建结果、原始参考和本轮验证范围需分别记录；现有源码中部分外部 I/O 延迟与 CDC 告警仍需工程审查，不把布局布线完成当全板签核。
