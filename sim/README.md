# 仿真与离线功能验证

## HDL 示例

先恢复源码，再从仓库根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\sim\run.ps1 `
  -Workspace .\out\workspace_01 `
  -VivadoBin 'C:\tools\vivado\2022.2\bin' -OutputRoot .\out\simulation_01
```

测试平台、合成 IQ 向量及期望载荷位于工作区 `source_code/zynq7045_ad9361_rid_aoa/dsss_receiver/sim/`。输入为 20 MS/s、1 Mbps DBPSK 长前导，FPGA 处理时钟 100 MHz。测试验证完整 134 字节有效载荷、错误 FCS 拒绝、缓存忙时保护、过期 ACK 拒绝、正确 ACK 与关闭状态。

正常生成 `result.txt`、仿真日志和回读载荷。两条 PASS 的定义来自逐字节对照及测试平台断言；不是收到真实空口帧，也不是角度精度验证。

## 算法与网页

完整离线快速流程从根目录 `build/reproduce.ps1 -Mode quick` 启动，包含历史 IQ/RID 保存样本、已知相位与几何控制输入、错误输入拒绝、隔离 HTTP/静态资源检查和上述 HDL 示例。使用 `-SkipSimulation` 时必须保留跳过标志。

根目录 README 列出输出位置与期望计数。每次选择新结果目录，不将原有保存结果复制为新验收。

## 参考结果

历史复现输出位于 `data/reference_results/`，本次新目录运行范围见 `data/release_validation.json`。二者均标记离线范围；新全量 FPGA 或实机验证需另行执行。
