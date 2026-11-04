# 启动文件与板端部署

`board_support.tar.xz` 保存两站基准 BOOT/DTB、匿名重建内核、FSBL/U-Boot ELF、匹配模块及基础运行文件。准备脚本解包到 `<workspace>/board_support/`；大小写敏感的启动文件名在该工作区保留原样。

**不包含完整 SD 整卡镜像或 Linux 根文件系统。** 目标板需要兼容的 ARM Linux、systemd、Python/NumPy、tcpdump、iw/ip、kmod 与 AD9361/IIO 支持。根文件系统和模块 ABI 不匹配时，复制几个启动文件不能恢复完整业务。

## 1 由 bitstream 打包 BOOT

在仓库根目录执行，参数中的安装路径与 bitstream 必须替换为实际值：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\out\workspace_01\source_code\reproduce\build_boot.ps1 `
  -Station A -Bitstream .\out\fpga_01\A\system_top.bit `
  -PythonExe .\.venv\Scripts\python.exe `
  -VivadoBin 'C:\tools\vivado\2022.2\bin' -OutputRoot .\out\boot_a_01
```

B 站选择 `-Station B` 和对应 bitstream。该工具组合参考 FSBL/U-Boot，核对头部、分区、地址和指定 PL 内容。换用不同硬件时，应先重新生成匹配 DDR/MIO 的启动组件，原 ELF 不能作为通用组件。

## 2 构建设备树

在安装 dtc 与 fdtoverlay 的 WSL/Linux、仓库根目录执行：

```bash
bash out/workspace_01/source_code/reproduce/build_device_tree.sh \
  "$PWD/out/workspace_01/source_code" "$PWD/out/device_tree_01"
```

A/B 节点属性对照使用工作区 `reproduce/verify_device_tree.py`，参考 A 为 `out/workspace_01/board_support/boot/A/system.dtb`，新 A/B 为输出目录中的 `station_A.dtb`、`station_B.dtb`。B 需有 `0x83c60000/0x10000` 的 DSSS 节点；在旧 FPGA 上不能随意访问这个尚不存在的地址。

## 3 生成运行覆盖包

根目录 README 给出 `board/prepare_runtime.py` 的调用。它组合工作区源码与基础文件，为 A/B 生成配对覆盖包、文件清单和离线完整性校验，不安装到板卡。指定 `--modules` 时检查重建模块 ABI；否则使用随包参考模块。

## 4 实机验收顺序

以下是待执行的现场步骤，不因离线文件生成成功而自动通过。

1. 按目标原理图和 XSA 核对 XC7Z045 封装、DDR、MIO、引脚、电平、时钟、复位、RF、DMA 和中断。详细移植检查表保留在工作区 `source_code/reproduce/HARDWARE.md`。
2. 备份目标板启动介质与服务，安装对应站匹配的 BOOT、DTB、内核和启动环境。基准使用 FAT 启动分区与 ext4 根分区；确认目标实际分区布局。
3. 进入 Linux，核对内核版本及模块 ABI，再安装本批次对应站的覆盖包并刷新模块和 systemd 配置。A/B 覆盖包的配对信息必须来自同一次生成。
4. 先检查 `airspace-rf`、`airspace-monitor`、`airspace-iq`、`airspace-recognition` 与 `airspace.target` 的依赖和状态；RF oneshot 的 `active/exited` 属正常状态。
5. 在 PC 配置实际板端地址和角色，核对真实帧、双 RX IQ 窗口、识别与角度结果的计数和新鲜度。没有目标时允许 `waiting_target`，不能据此认定服务退出。
6. 实测几何、独立核验当前参考和非零位置，再评价单站角度和双站交汇。文件匹配不等于模拟相位稳定；默认授权复用不等于全部新建基准都有效。
7. 正常软件重启、直接掉电、长期运行和精度验收是不同测试，分别记录。不要并行启动旧手动采集进程与 systemd 服务争用 DMA。

PC 地面站仍负责调度与转发；板端自启动不代表电脑程序自启动。原始 `/run` 窗口是有界临时缓存，需要永久留存时另行导出。
