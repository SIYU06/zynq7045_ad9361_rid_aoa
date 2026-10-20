# Zynq XC7Z045 + AD9361：openwifi / RID / AOA

本仓库保存本地 `dma_project` 的当前移植快照：使用 Vivado 2022.2，在 Zynq PL 中运行 openwifi 接收解调，并通过 side_ch 获取 IQ。

**当前仍处于移植阶段，不是可直接下载使用的已验收工程。没有完成上板 Wi-Fi 解码、双通道同步 IQ 或 AOA 验收。**

- 工程入口：[dma_project/dma_project.xpr](dma_project/dma_project.xpr)
- 修改记录和已知问题：[README.openwifi.md](README.openwifi.md)
- 本板适配及构建入口：[openwifi/](openwifi/)
- 锁定源码版本：[openwifi/sources.lock.json](openwifi/sources.lock.json)
- 原始 DMA 工程输入备份：[baseline_before_openwifi/](baseline_before_openwifi/)
- 当前本板 BD 输入：[ow/board/src/system.bd](ow/board/src/system.bd)

Vivado 缓存、生成 IP、运行目录、bit/XSA 及重复的上游源码不纳入 Git。首次克隆后需要按锁定版本恢复 `upstream/` 并重新打包 IP，不能直接依赖缺失的本机生成文件。当前 `prepare.py` 还读取相邻的原 RF 工程 PS 配置，完整重建仍需该本地依赖；本仓库同时保留现有 `ow/board/ps_settings.tcl` 快照。

上游项目：[openwifi-hw](https://github.com/open-sdr/openwifi-hw)、[openwifi](https://github.com/open-sdr/openwifi)、[OpenOFDM](https://github.com/open-sdr/openofdm)、[ADI HDL](https://github.com/analogdevicesinc/hdl)。派生的上游文件沿用其许可，见文件头及各上游仓库；本仓库尚未为自有代码指定单独许可证。
