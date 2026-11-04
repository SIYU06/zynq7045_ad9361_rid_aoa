# 任务：构建 OpenWiFi Linux 软件栈，生成可部署的 SD 卡文件包

## 一、任务目标

项目根目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa`

硬件平台：Zynq-7045 + AD9361。

本轮任务：

基于目前已经验证通过的 FPGA 硬件和 ADI Linux 5.15 工程，构建支持 OpenWiFi 的新 Linux 内核、必要设备树和驱动模块，最终整理成一套可以直接手动复制到 SD 卡的部署文件。

**本轮只完成电脑端编译和 SD 卡部署文件准备，不实际修改 SD 卡，不上板验证。**

用户会在文件准备完成后，按照说明手动进行 SD 卡操作。

## 二、已有成果

优先阅读以下报告中的相关结论：

- `10.26_10.03openwifi审计.md`
- `10.26_10.20openwifi首次推进.md`
- `10.27_17.08时序问题整改.md`
- `10.27_22.20DOAlinux启动.md`

当前已确认：

1. OpenWiFi PL 接收链路 `AD9361 → rx_intf → OpenOFDM → DMA1` 静态连接完整。
2. RX AXI Stream 的 TLAST 背压问题已修复，相关仿真通过。
3. FPGA 内部时序已收敛，WNS +0.559 ns、TNS 0、建立违例 0。
4. Bitstream、XSA、BOOT.BIN、DTB 已存在可启动组合。
5. Zynq-7045 已成功启动 Linux，AD9361 与 DMA 已实板验证。
6. DOA/side_ch 双通道 IQ 已经成功采集，本轮不处理。
7. OpenWiFi 完整 Linux 驱动尚未成功运行，主要阻碍是当前内核缺少 cfg80211/mac80211。
8. 真实 OpenWiFi OFDM MAC 帧尚未接收验证。

不重复处理已经完成的 FPGA 时序、RTL 和 DOA 工作。

## 三、当前 Linux 与软件环境

当前已验证 Linux 内核：

`5.15.0-175919-g427c94e8faa5`

ADI Linux 源码提交：

`427c94e8faa57cb224bd40f1a0c8fe25168be2e5`

现有内核配置缺少：

```text
CONFIG_CFG80211
CONFIG_MAC80211
CONFIG_RFKILL
CONFIG_XILINX_DMA
```

OpenWiFi `sdr.c` 依赖 mac80211，因此需要构建匹配的新内核与模块组合。

先确认现有内核源码、工具链、构建目录、`.config`、`Module.symvers` 和设备树配置，优先复用已存在的构建环境。

不要重新下载已有源码。

## 四、阶段一：构建新 Linux 内核

基于现有 ADI Linux 5.15 精确提交和已验证配置，创建独立 OpenWiFi RX 构建版本。

目标启用：

```text
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_RFKILL=y
CONFIG_XILINX_DMA=m
```

处理必要依赖，但不启用无关功能。

注意：

- 核对 `CONFIG_XILINX_DMA` 与已有外部 `xilinx_dma.ko` 的实现和模块名，避免重复驱动冲突。
- 优先保留当前可用的板级配置、AD9361 驱动、IIO、SPI、MMC、文件系统和串口支持。
- 不因启用 mac80211 而破坏现有启动所必需的功能。
- 使用独立内核 release 标识，例如 `-openwifi-rx1`，并确认实际 `kernelrelease` 与模块安装路径一致。
- 所有模块使用同一次内核构建对应的 `Module.symvers`，保证 ABI 一致。

编译生成：

- 新 `uImage`。
- 对应的内核模块。
- 必要的 `cfg80211.ko`、`mac80211.ko` 及实际依赖。
- 对应内核版本的完整模块依赖文件。

只构建一次必要的内核和模块，不重复执行已成功的构建步骤。

## 五、阶段二：编译 OpenWiFi 驱动

基于新内核编译 OpenWiFi 相关模块。

重点包括：

- `sdr.ko`
- `rx_intf.ko`
- `openofdm_rx.ko`
- `tx_intf.ko`
- `openofdm_tx.ko`
- `xpu.ko`
- 必需的 DMA 模块。

根据实际驱动依赖选择模块，不强制编译没有必要或不存在的文件。

核对：

1. `vermagic` 与新内核版本匹配。
2. 外部模块正确使用新内核的 `Module.symvers`。
3. cfg80211/mac80211 的符号依赖满足要求。
4. 驱动所需的 DMA 通道名、设备树节点和 compatible 与现有硬件一致。
5. 不存在明显的同名模块、重复驱动或符号版本冲突。

不得混用此前 DOA 内核的旧 `.ko` 文件。

如果必须修改 OpenWiFi 驱动源码，只进行当前编译所必需的最小修改，并记录实际变更。

## 六、阶段三：检查并准备设备树

优先使用此前已经能够成功启动 Linux 的设备树作为基础。

只检查 OpenWiFi 运行所必需的硬件节点：

- AD9361。
- AXI DMA。
- `rx_intf`。
- `openofdm_rx`。
- `tx_intf`。
- `openofdm_tx`。
- `xpu`。
- OpenWiFi `sdr`。
- 中断和 DMA 通道引用。
- DMA1 S2MM 对应的 `rx_dma_s2mm`。

特别核对 DMA0 与 DMA1 的职责，不要把已经验证的 side_ch IQ DMA 当成 OpenWiFi 解码帧 DMA。

如当前设备树已经满足要求，直接复用现有 DTB。

如确实需要修改：

1. 修改对应 DTS/DTSI。
2. 编译生成新的 `system.dtb`。
3. 检查 DTS 编译错误、节点引用和必要属性。
4. 记录修改内容及原因。

不要为了重新构建而无意义地修改设备树。

不修改 FPGA Bitstream 或 BOOT.BIN，除非发现新 Linux 组合确实无法复用现有硬件启动文件；这种情况只报告，不自行扩展 FPGA 任务。

## 七、阶段四：生成 SD 卡部署文件包

在工程根目录下新建：

`deploy_openwifi_rx1/`

将本轮最终需要部署的文件统一整理在此目录。

要求按照 SD 卡目标位置组织，避免用户手动判断复制路径。

建议结构：

```text
deploy_openwifi_rx1/
├── boot/
│   ├── uImage
│   └── system.dtb
├── rootfs/
│   └── lib/
│       └── modules/
│           └── <实际kernel-release>/
│               ├── kernel/
│               ├── extra/
│               ├── modules.dep
│               ├── modules.alias
│               └── ...
├── manifest.txt
└── README_手动部署.md
```

具体结构根据实际构建结果调整，不需要生成无用占位文件。

注意：

- `boot/` 对应 SD 卡 FAT32 启动分区。
- `rootfs/` 对应 SD 卡 ext4 Linux 根文件系统。
- `BOOT.BIN` 原则上继续使用现有验证版本，不复制无关的旧文件。
- `system.dtb` 只有在实际构建或确认兼容后才加入部署包，不能随意放入不匹配的文件。
- 保证新内核和模块目录中的 release 完全一致。
- 确保模块依赖文件正确生成。
- 不放入旧内核不兼容的模块。

如果根文件系统中还缺少实际运行所必需的配置文件或固件，应只打包必要内容，并明确其目标路径。

## 八、阶段五：部署前离线检查

完成文件包后，进行一次必要的离线检查：

1. `uImage` 格式正确，架构为 ARM/Zynq-7000。
2. 新内核 release 与模块安装路径一致。
3. cfg80211/mac80211 配置确实生效。
4. OpenWiFi 外部模块的 vermagic、依赖和符号版本匹配。
5. 设备树能够正确编译，所需节点及 DMA 引用存在。
6. SD 卡部署包文件完整，无明显缺失。
7. `manifest.txt` 列出实际生成文件、版本和 SHA-256。
8. 现有 `BOOT.BIN`、`uEnv.txt` 与新内核启动方式是否需要调整；如需调整，只生成候选文件和说明，不覆盖原件。

只验证可以离线证明的项目。

不得声称：

- 新内核已经上板启动。
- `sdr.ko` 已成功 probe。
- `sdr0` 已经出现。
- OpenWiFi 已经收到真实 MAC 帧。

这些必须等用户手动部署后才能验证。

## 九、人工操作说明

在 `README_手动部署.md` 中，用简洁、准确的步骤告诉用户：

1. 需要备份 SD 卡上的哪些原文件。
2. FAT32 分区需要复制或替换哪些文件。
3. ext4 根文件系统分区需要放入哪些模块目录。
4. 新内核是否需要修改 `uEnv.txt` 或启动参数。
5. Windows 环境下如何识别 FAT32 与 ext4 分区；若 Windows 不能直接写 ext4，给出一套可靠的手动操作方法。
6. 如何确认文件复制正确。
7. 如何插卡启动和观察串口日志。
8. 启动失败时怎样恢复原来的 Linux 和启动文件。

必须写出实际的源文件路径和 SD 卡目标路径。

不要只说“把文件复制到 SD 卡”。

用户会手动进行 SD 卡操作。

## 十、严格人工部署边界

本轮 Codex 可以：

- 修改必要源码。
- 修改内核配置。
- 修改必要设备树源码。
- 执行编译。
- 整理部署文件。
- 检查构建产物。
- 编写人工部署说明。

本轮 Codex 不得：

- 自动格式化、分区或写入 SD 卡。
- 自动替换 SD 卡启动文件。
- 自动写入板端根文件系统。
- 自动烧录 FPGA。
- 自动通过串口或 SSH 部署新内核、DTB 或模块。
- 自动重启开发板。
- 自动覆盖已验证的 BOOT.BIN、uImage、DTB。
- 在未得到用户明确部署完成确认前进行依赖新内核的上板测试。

本轮做到部署包准备完成就停止。

## 十一、Token 与工程效率要求

**严格控制 Token 消耗，禁止过度防御性代码。**

具体要求：

1. 先利用现有报告，避免全面审计仓库。
2. 只读取本轮直接相关的源码、配置和日志。
3. 优先使用已有 Linux 源码、工具链、构建脚本与缓存。
4. 不重复下载源码和依赖。
5. 不重新编译已经正确且可直接复用的无关组件。
6. 不重复运行相同构建。
7. 不输出大段完整编译日志。
8. 不增加通用异常处理框架、复杂兼容层或过度封装。
9. 不编写多余的自动化测试、冗余脚本和重复文档。
10. 仅执行必要的配置检查、编译验证和部署包核对。
11. 不修改 FPGA、RTL、XDC、DOA、RID 或地面站。
12. 不执行 Git add、commit、push。
13. 如遇到明确阻塞，定位首个关键错误并完成其余可独立完成的内容，不进行无意义反复尝试。
14. 不为了节省 Token 而省略会导致 SD 卡无法启动的必要兼容性检查。

开发原则：

**最小修改、复用现有成果、一次性构建、一次性整理部署文件。**

## 十二、最终交付与停止条件

本轮交付：

`F:\2026fpga\zynq7045_ad9361_rid_aoa\deploy_openwifi_rx1\`

其中包含：

- 实际构建生成的内核文件。
- 必要的设备树文件。
- 匹配内核版本的 OpenWiFi 及依赖模块。
- 模块依赖信息。
- 文件清单与校验信息。
- 准确的人工 SD 卡部署步骤。
- 原系统备份与恢复方式。

最终对话只需要简要汇报：

1. 构建是否成功。
2. 新内核版本是什么。
3. 是否修改设备树。
4. 部署文件包的完整路径。
5. FAT32 分区需要复制哪些文件。
6. ext4 分区需要复制哪些文件。
7. 用户下一步需要进行的人工操作。

**文件准备完成后立即停止，不自动部署、不继续进行上板验证。**

## 十三、执行结果（2026-10-31）

### 1. 完成状态

电脑端构建、OpenWiFi 模块编译、设备树核对、部署包整理和离线校验均已完成。

最终交付目录：

`F:\2026fpga\zynq7045_ad9361_rid_aoa\deploy_openwifi_rx1\`

本轮没有写入 SD 卡、没有连接或重启开发板、没有替换板端文件，也没有声称新内核已启动、`sdr.ko` 已 probe、`sdr0` 已出现或已经收到真实 MAC 帧。

### 2. 内核构建结果

- ADI Linux 源码提交：`427c94e8faa57cb224bd40f1a0c8fe25168be2e5`
- 交叉编译器：`arm-linux-gnueabi-gcc`
- 新内核 release：`5.15.0-175919-g427c94e8faa5-openwifi-rx1`
- `uImage`：构建成功，ARM Linux legacy uImage，加载地址/入口地址均为 `0x00008000`
- 已安装完整同版本模块树并生成 `modules.dep`、`modules.alias`、`modules.symbols` 等索引

实际生效的关键配置：

```text
CONFIG_LOCALVERSION="-175919-g427c94e8faa5-openwifi-rx1"
# CONFIG_LOCALVERSION_AUTO is not set
CONFIG_CFG80211=m
CONFIG_MAC80211=m
CONFIG_RFKILL=y
CONFIG_XILINX_DMA=m
CONFIG_NL80211_TESTMODE=y
CONFIG_DRM_ADI_AXI_HDMI=m
```

`CONFIG_DRM_ADI_AXI_HDMI` 从内建改为模块，是因为 `CONFIG_XILINX_DMA=m` 后，内建 HDMI 驱动不能合法引用模块符号；该调整只用于保持内核链接依赖一致。

### 3. OpenWiFi 模块结果

以下 6 个模块均编译、`modpost` 和链接成功：

- `sdr.ko`
- `rx_intf.ko`
- `openofdm_rx.ko`
- `tx_intf.ko`
- `openofdm_tx.ko`
- `xpu.ko`

所有上述模块以及 `cfg80211.ko`、`mac80211.ko`、`xilinx_dma.ko` 的 `vermagic` 均为：

`5.15.0-175919-g427c94e8faa5-openwifi-rx1 SMP preempt mod_unload modversions ARMv7 p2v8`

`sdr.ko` 的依赖已正确写入 `modules.dep`，包括 5 个 OpenWiFi 子模块、`mac80211`、`cfg80211` 和 `libarc4`。

### 4. 为完成构建所做的最小修改

1. Linux 5.15 mac80211/platform API 适配：
   - 修正 `openwifi_stop`、`ieee80211_beacon_get`、`bss_info_changed`、`conf_tx` 和 AMPDU 能力字段用法。
   - 移除 Linux 5.15 不存在的 `wake_tx_queue`/chanctx helper 赋值，继续使用现有 TX 回调。
   - 将 `sdr`、`openofdm_tx`、`tx_intf`、`xpu` 的 platform `remove` 回调改为 Linux 5.15 所需的 `int` 返回类型。
   - 修正随 `changed` 类型调整产生的打印格式警告。
2. 补入锁定 OpenWiFi 提交所需的生成头文件：
   - `ow/linux/driver/pre_def.h`
   - `ow/linux/driver/git_rev.h`
   - `ow/linux/user_space/sdrctl_src/nl80211_testmode_def.h`
3. 按 OpenWiFi 官方内核补丁依据，仅导出 `sdr.ko` 实际需要的 4 个既有 AD9361 函数：
   - `ad9361_set_tx_atten`
   - `ad9361_get_tx_atten`
   - `ad9361_ctrl_outs_setup`
   - `ad9361_do_calib_run`
4. `wgd.sh` 改为使用已安装的 `xilinx_dma`/`mac80211` 模块树，并在继续前确认内建 AD9361/ADC/DDS 驱动已经绑定。

AD9361 导出修改的精确记录位于：

`deploy_openwifi_rx1/build_info/ad9361_openwifi_exports.patch`

没有引入官方补丁中的额外 AGC 行为或采样率行为修改。

### 5. 设备树结果

设备树未修改，部署包原样复用：

`F:\2026fpga\openwifi_linux_boot_20261027_2220\sd_card\system.dtb`

SHA-256：

`ba25360085b1597e0283e09d595f37720768208eb38a63689431e8aceb485e6b`

该 DTB 可正常反编译，并确认包含两个 AXI DMA、`rx_intf`、`openofdm_rx`、`tx_intf`、`openofdm_tx`、`xpu`、`sdr` 以及 `rx_dma_s2mm`/`tx_dma_mm2s` 引用。反编译仍显示原设备树已有的板级 warning，但没有错误；本轮未改动这些既有内容。

### 6. 离线校验结果

- `uImage` 头、ARM 架构、加载地址和入口地址检查通过。
- 完整 release 与模块安装目录一致。
- 关键内核配置检查通过。
- 外部模块 `modpost` 通过。
- `depmod -e -F System.map` 无未解析符号输出。
- OpenWiFi、cfg80211、mac80211、xilinx_dma 的 `vermagic` 和依赖检查通过。
- DTB 节点及 DMA 引用检查通过。
- 最终包中 204 个交付文件的 SHA-256 全量复核通过。
- 所有运行脚本语法检查通过。
- 包内没有 `BOOT.BIN` 或 `uEnv.txt`，避免误覆盖现有已验证启动文件。

首次尝试曾错误使用 `arm-linux-gnueabihf-`，产生 ARM 指令编译错误；随后已切换到现有工程实际使用的 `arm-linux-gnueabi-` 并从干净构建状态成功完成。失败尝试的产物没有进入部署包。

### 7. 部署内容与下一步

FAT32 分区只复制：

- `deploy_openwifi_rx1/boot/uImage` → `/uImage`
- `deploy_openwifi_rx1/boot/system.dtb` → `/system.dtb`

ext4 分区复制：

- `deploy_openwifi_rx1/rootfs/lib/modules/5.15.0-175919-g427c94e8faa5-openwifi-rx1/` → `/lib/modules/5.15.0-175919-g427c94e8faa5-openwifi-rx1/`
- `deploy_openwifi_rx1/rootfs/root/openwifi_rx1/` → `/root/openwifi_rx1/`

`BOOT.BIN` 和 `uEnv.txt` 保持 SD 卡现有版本不变。用户下一步应严格按照 `deploy_openwifi_rx1/README_手动部署.md` 先备份、再手动复制 FAT32/ext4 文件，通过 115200 8N1 串口启动并人工验证。文件部署完成前不进行任何依赖新内核的上板测试。
