# 空域知微 无人机侦测与双站测向系统

空域知微以两台 **Zynq XC7Z045 与 AD9361 软件无线电平台**为核心，通过被动接收 Wi-Fi 信号完成检测采集、特征识别、RID 身份解析，以及受支持信号的单站 DOA 与双站 AOA 几何交汇。系统服务于低空信源观测、无人机广播身份接收和测向实验，PC 地面站提供目标、轨迹、信源证据与设备状态展示。

本仓库同时交付完整源码、构建入口、仿真输入、历史实收回放、板端文件生成方法、复现说明、技能包和大模型协作记录。**可以先不接板完成离线验证；绝对测向精度需要独立的现场标定和真值验收，不能用回放或软件测试代替。**

## 1 系统原理与设备分工

```text
B 站 AD9361 与 FPGA  → OFDM/部分 HT20、1 Mbps 长前导 DSSS 完整帧及本机双 RX IQ
B 站 Linux CPU      → 可见协议字段、RID 解析、本机单站 DOA
                          │ 结构化观测经 PC 原样转发
A 站 Linux CPU      ← 信源分类、六项候选证据评分、RID/AOA 分流
A 站 AD9361 与 FPGA  → 本机双 RX 同步 IQ → A 站 Linux CPU 单站 DOA
                          │
PC 地面站           ← 同频调度、任务续租、结果汇总、同目标同帧校验、几何交汇与显示
```

FPGA 承担接收基带、站内同步采样、缓存和 DMA；识别、RID 解析及单站角度计算运行在板端 Linux CPU。PC 保留调度和必要的 B→A 转发。当前两板分别连接电脑的独立网段，不能宣称脱离 PC 后仍具备完整双站协同。

RID 广播具有新鲜有效位置时直显广播位置；没有有效 RID 位置但有识别依据时，进入受支持的 AOA 分支。非 RID 分数是规则证据分，不是无人机确认概率。加密载荷不进行解密，未知目标不补造身份；身份结构解析成功也不等于真实性认证。

### 已验证范围与限制

| 项目 | 当前记录支持的能力 | 使用边界 |
| --- | --- | --- |
| 接收 | A 保留 OFDM 测向采样，B 完整解码 OFDM/已实收 HT20，并有 1 Mbps DBPSK 长前导 DSSS | 不覆盖全部 802.11n、全部 DSSS/CCK 制式或专有图传 |
| 频段 | 2.4 GHz 信道 1–13；5 GHz 信道 36、38、40、42、44、46、48、52、56、60、64 逐信道轮扫 | 不同频点接收存在间隙；当前未覆盖 5.8 GHz，不是同时全频接收 |
| 单站测向 | 两站各自 Linux 处理 OFDM LTF、同帧关联、相位及参考修正 | 当前 DSSS 接收不代表 DSSS 测向；HT20 IQ 关联仅完成短 GI、MCS 0–5 的对应验证 |
| 双站定位 | 验证过同源同帧交汇及独立移位响应 | 两天线存在方向多解；异帧、过期或参考失配时拒绝输出 |
| 常驻运行 | systemd 管理两站 RF、monitor、IQ/DOA 与识别服务，IQ 使用 `--seconds 0` | 常驻不等于连续无间隙满带宽处理；没有目标可正常等待 |
| 实验参考 | 历史固定布局为 A 右 B 左、基线 2.8 m、站内阵距 6 cm、参考点在中点前方 3 m | 新硬件和新现场必须测量并核验，不将历史偏置直接当作当前标定 |

总纲领的公开匿名副本见 [data/collaboration/project_brief.md](data/collaboration/project_brief.md)。晚期专项修订和参考策略差异见[协作记录](report/llm_collaboration.md)。

## 2 仓库目录及源码交付方式

```text
README.md                    项目简介与完整复现入口
src/                         完整设计源码归档、内核分卷、逐文件 SHA256
sim/                         仿真运行入口和验证说明
build/                       源码准备、FPGA/内核/离线验证入口
board/                       启动及运行文件归档、A/B 覆盖包生成与部署说明
data/                        历史测试数据说明、协作原件匿名副本及验证记录
skill/                       提示词工程流、工作流、模板、校验工具与踩坑指南
report/                      大模型协作记录，设计报告可另行放入
out/                         本机生成的工作目录与新结果，不提交到 Git
```

仓库外层采用小写英文、数字和下划线，`README.md` 保留入口惯例。为保持已经验证的 XPR/IP 相对引用、`Makefile` 与 `Module.symvers` 等大小写敏感约定，完整源码以归档交付，准备工具在新的 `out/` 工作区恢复原生树，而不批量改写上游文件名。`src/source_manifest.json` 列出各文件及哈希，内核完整归档分为三个不超过 48 MiB 的卷；无需 Git LFS 或额外下载源码。

解包后的对应关系：

| 新仓库位置 | 准备后的工作目录 | 用途 |
| --- | --- | --- |
| `src/project_sources.tar.xz` | `out/workspace_01/source_code/` | 业务、算法、RTL、IP、BD/XPR、约束和原验证脚本 |
| `src/linux_source.part000` 等 | `out/workspace_01/source_code/third_party/linux-427c94e8faa5-source.tar.xz` | 固定版本完整内核源码 |
| `board/board_support.tar.xz` | `out/workspace_01/board_support/` | BOOT、DTB、匿名重建内核、FSBL/U-Boot 参考和基础驱动 |
| `build/reproduce.ps1` | 调用工作目录 `source_code/reproduce/run_reproduction.ps1` | 为新目录提供统一复现入口 |

## 3 复现前提

- Windows 下使用 PowerShell 与 Python；参考离线验证环境为 CPython 3.8.10、NumPy 1.22.1。已有可用 Python/NumPy 环境可以先运行检查，兼容结果以实际输出为准。
- FPGA 仿真和构建使用 Vivado 2022.2、XC7Z045 器件支持及工程所需 IP 授权。部分接收链 IP 需要有效授权，许可证不在仓库中。
- 内核与驱动构建使用 Ubuntu 22.04 或 WSL、GNU Make 和 ARM 交叉编译器；还需 flex、bison、bc、OpenSSL/ELF 开发库、kmod，完整内核镜像打包另需 `u-boot-tools`。
- 浏览器用于地面站显示；在线地图是可选联网资源，离线网格与算法回放不依赖地图服务。
- 实机需要兼容硬件及匹配的 ARM Linux 根文件系统。仓库提供的启动文件不是整张 SD 卡镜像，也不包含完整根文件系统。

所有命令均在**仓库根目录**执行。示例中的 Vivado 路径应替换为本机实际安装位置。每次验证选新的输出目录，保留前次证据；准备脚本拒绝覆盖已有工作目录。

## 4 第一步 恢复完整源码并核对文件

将仓库下载或克隆到较短英文路径，确认 `src/linux_source.part000`、`part001`、`part002` 三个分卷均为实际文件。然后执行：

```powershell
python .\build\prepare_sources.py --out .\out\workspace_01
```

应看到 `ok: true`、`source_files_verified: 3423` 和 `kernel_parts: 3`。工具先校验输入归档与分卷，重组内核，再核对解包后的源码清单；校验失败保留结果，不继续构建。此步骤只证明字节完整性，不代表仿真、构建或实机已通过。

若使用新的 Python 3.8 环境，可在根目录创建虚拟环境：

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r .\out\workspace_01\source_code\reproduce\requirements-offline.txt
```

参考锁定依赖用于上述 Python 3.8 环境；其他 Python 版本应安装与其兼容的 NumPy，并单独记录实际版本。下面的 `-PythonExe` 可替换为已有可导入 NumPy 的解释器，不要求重新安装已有环境。

## 5 第二步 一轮快速离线验收

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\reproduce.ps1 `
  -Workspace .\out\workspace_01 -Mode quick -Rounds 1 `
  -PythonExe .\.venv\Scripts\python.exe `
  -VivadoBin 'C:\tools\vivado\2022.2\bin' `
  -OutputRoot .\out\quick_01
```

| 检查 | 期望输出 | 新生成证据 |
| --- | --- | --- |
| 历史采样与独立控制输入 | `OFFLINE PASS 34 / 34` | `out/quick_01/round_1/algorithms/offline_verification.json` |
| 隔离地面站 HTTP 与静态资源 | `WEB PASS 46 HTTP checks` | `out/quick_01/round_1/web/web_verification.json` |
| DSSS 接收与 AXI 示例 | 两条 `PASS`，134 字节有效载荷逐字节相同 | `out/quick_01/round_1/fpga_simulation/result.txt` |
| 当轮汇总 | `REPRO_PASS quick round 1` | `out/quick_01/round_1/summary.json` |

没有 Vivado 时，可加 `-SkipSimulation` 先验证算法和网页；此时汇总中的 `Simulation=false`，不代表 HDL 仿真通过。回放和构造输入分别标记，不能写成新空口实收。单独运行仿真见 [sim/README.md](sim/README.md)。

## 6 第三步 查看地面站与回放

```powershell
.\.venv\Scripts\python.exe -X utf8 -B .\out\workspace_01\source_code\rid_receiver\ground_station\serve.py --port 18770
```

浏览器打开 `http://127.0.0.1:18770/#/home`。未接板时，真实模式应等待连接，不生成虚构目标；可选择历史双站观测记录，检查播放、暂停、进度拖动、单站质量和双站几何显示，之后切回真实模式确认历史数据不冒充当前观测。底图不可用时切换离线网格。

保留“历史”“临时参考”“未校准”等状态。自动 HTTP 检查不等于已经点击验收全部浏览器按钮；现场显示和操作应另外记录。

## 7 第四步 FPGA 从源码构建

对第一次完整构建建议另准备 `out/workspace_fpga_01`，避免混用已有生成状态，然后运行：

```powershell
python .\build\prepare_sources.py --out .\out\workspace_fpga_01
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\reproduce.ps1 `
  -Workspace .\out\workspace_fpga_01 -Mode fpga -Station both -FpgaPhase bitstream `
  -VivadoBin 'C:\tools\vivado\2022.2\bin' -OutputRoot .\out\fpga_01
```

阶段可选 `validate`、`synth`、`impl`、`bitstream`；A/B 顺序执行。A 工程入口为工作区的 `source_code/zynq7045_ad9361_rid_aoa/dma_project/dma_project.xpr`，B 为同根下 `dsss_receiver/build/integrated_r2/dsss_b.xpr`。

验收不仅看工具是否打开。逐站检查 `ip_status.rpt`、`impl_timing.rpt`、`impl_utilization.rpt`、`impl_drc.rpt`、`check_timing.rpt` 及 `timing_gate.txt`。时序与 DRC 门控通过才生成 `system_top.bit` 和 `hardware.xsa`；相关 CDC 与外部 I/O 约束缺口仍需审查。历史结果在 `data/reference_results/`，新结果保存在 `out/fpga_01/`，不覆盖历史结论。

## 8 第五步 Linux 内核与驱动

在已准备好交叉工具链的 WSL 环境下，从根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\reproduce.ps1 `
  -Workspace .\out\workspace_01 -Mode kernel -WslDistro Ubuntu-22.04 `
  -OutputRoot .\out\kernel_01
```

内核工具在 WSL 新工作目录解压源码、应用补丁、恢复配置并编译外部接收模块和网络/DMA 模块，核对目标 `5.15.0-175919-g427c94e8faa5-openwifi-rx1` 的 ABI。完整镜像步骤、C 参考校验和设备树构建见 [build/README.md](build/README.md)。内核 CRC、版本和符号校验不代替上电启动。

## 9 第六步 启动文件和板端部署

准备源码后，可从根目录生成两站当前业务覆盖包：

```powershell
.\.venv\Scripts\python.exe -B .\board\prepare_runtime.py `
  --workspace .\out\workspace_01 --out .\out\runtime_01
```

可选 `--modules out/kernel_01/modules` 使用新编模块。生成过程检查 ABI、逐文件内容与配对配置，不向板卡写文件；每次生成独立配对密钥，不能混用不同批次的两站配置。

BOOT 打包、设备树及实际部署见 [board/README.md](board/README.md)。同一 XC7Z045 芯片不代表不同硬件能直接使用已有 BOOT；DDR、MIO、引脚、电平、时钟、RF、设备树和启动组件必须匹配。仓库 FSBL/U-Boot ELF 是基准参考；硬件变化后需要相应目标组件。

实机验收依次检查 Linux 与网络、RF、帧接收、双 RX IQ、身份与参考、单站角度和同帧交汇；独立保存真值来源。没有有效参考时保持空角度或待校准，不将历史偏置或网页出数当精度通过。

## 10 结果记录与贡献范围

既有离线验证包括 34 项算法回放/控制输入、46 项 HTTP/资源检查、DSSS AXI 示例、A/B 重建、内核/驱动与启动文件核验；它们是对应原版本的历史证据。当前 GitHub 目录准备后的实测范围另见 [data/release_validation.json](data/release_validation.json)，不会将未重新执行的全量 FPGA 构建或现场实验记为本轮完成。

- [技能包](skill/README.md)：提示词工程流、工作流、案例模板、校验脚本与踩坑指南。
- [大模型协作记录](report/llm_collaboration.md)：提示词、回答、纠错、人机技术分工及历史来源。
- [数据说明](data/README.md)：公开副本、原始采样与构造输入的区别。
- [第三方说明](third_party_notices.md)：版本及许可的保存方式。

设计报告可另行放入 `report/`；本次未将未经重新检查的二进制文档自动作为对外报告上传。公开文件只使用技术角色，不记录参赛单位或人员身份；来源副本匿名处理后重新计算哈希。
