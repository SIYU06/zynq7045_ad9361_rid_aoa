# 户外固定参考持久沿用与重启验收

2026-11-03 02:08（北京时间）。按用户明确要求，默认沿用此前户外参考：A右B左、两站间距2.8米、各站阵距6厘米、参考点位于两站中点共同正前方3米。此次没有重新采集标定数据、拟合偏置或把实时角度拉到理论角度。

## 已部署行为

A/B板端共享参考模块和PC验证逻辑均已更新，网页已显示固定参考状态。`aoa_calibration_A/B.json`持久保存 `reuse_policy=operator_fixed_outdoor_reference`、`operator_authorized_reuse=true`。重启后的新会话由PC随目标上下文自动同步参考；无需每次上电重新测参考。PC仍需运行地面站程序，单站DOA仍在两站Linux CPU计算。

| 项目 | A站 | B站 |
|---|---|---|
| 原始相位偏置 | 108.38687536304712° | 132.53013020854803° |
| 原参考已知角 | -25.01689347810002° | +25.01689347810002° |
| 原始采集会话 | `5e859cd129ee47adaac3bd6b3afdae79` | `1724c849fbe74dfb87372ab2614b50e6` |
| 历史重复性检查 | 未通过，原样保留 | 通过，原样保留 |
| 本次重启后角度快照 | -32.504690127566526° | -11.169876826979772° |

原始 `capture_metadata`、`capture_session_id`、偏置和精度验收字段保留。原参考的局部站点几何另存 `historical_station_geometry`，当前参考的操作几何绑定现有地图配置；现有地图位置、朝向及 `doa_config.json`没有改动，计算站距仍为2.8米。此绑定依据用户指定的固定布局假设，未重新进行物理测量。

当前观测的 `referenceSessionId` 等于当前采集会话，`referenceCaptureSessionId`记录原始采集会话；不能把历史会话改成当前UUID来伪装新标定。只有显式授权的固定参考放宽跨会话限制。RF频率、IQ采样率、手动增益、阵距、几何、站点、帧关联、配置哈希和数据新鲜度仍需符合原检查。

网页提示改为“沿用户外固定参考 · 站距2.8米／参考点前3米 · 精度未重新核验”；目标状态为“AOA测向中／固定参考”。`productionAccepted=false`、`geometryVerified=false`，保持历史参考估计属性。这解决重启会话造成的参考阻断，不代表已解决原始测向波动或完成跨上电绝对精度验证。

## 实机验收

两站分别执行 `systemctl restart airspace-iq.service`，不是整机断电测试。两站均生成新会话，自动恢复新鲜角度，`referenceMatched=true`，历史偏置、原参考采集会话和参考哈希不变。验收时PC接口 `connected=true`，单站结果 `processingLocation=board`，无参考失配错误。

| 项目 | A站 | B站 |
|---|---|---|
| 重启前会话 | `a914c27cb3654e6c8f526d36ebd0807c` | `97357f668d684b60b35a711c91a165b9` |
| 重启后会话 | `71f05d1217f54ac8a4c33828273b02da` | `7ebecf7e4bfe4085b7d9d696a8af6002` |
| 参考哈希 | `58ea7c9678093729f15c01356e2601a27cc654b32ba904055e0ed8282f3a46db` | `ef006f6fea8ae124cec0afa8ae477d5088c5190d9c38b60055283070146e4ba9` |

验收时两站 `airspace.target`均为enabled，RF、monitor、IQ三项服务均为active。此次未改systemd单元、RF初始化、FPGA、A测向/B完整解码分工。板端模块SHA256均为 `0f54c3f41b8cfe165ca10bc23def996e8be51c5441c363f14388d194c78cd4da`，算法整体代码哈希为 `9457c8584ff19f080bd0bbd87c580e495292d09599897cb0373e2a50da011a6a`。重启后的状态计数未出现原始IQ下载，正常链路继续接收紧凑DOA结果。

真实PC接口经过前端数据归一化和态势卡片渲染校验：两站保留固定参考来源，角度连接有效，目标状态正确，卡片不再显示“参考失效／重新核验参考”。浏览器已有缓存时按Ctrl+F5。

## 测试与证据

- 新增4项固定参考测试：授权跨重启、未授权继续严格拒绝、RF/增益/阵距/几何不匹配拒绝、连续两次新会话保持偏置及哈希。
- 参考、板端传输、处理链、DOA桥接及选站定向回归56项通过；板端核心58项通过；前端14个测试文件通过；实机重启和真实接口渲染验收通过。
- 两次完整PC测试均执行117项，各有1个拒绝外部Origin的HTTP用例出现Windows `WinError 10053`连接中止，服务端已记录403。失败分别出现在不同模块；相关模块单独复测均通过。未为此修改HTTP服务逻辑，也未将完整测试声称为全通过。

证据目录：[tmp/persistent_reference_20261103]（见对应归档说明）。其中 `promotion.json`记录偏置和原会话，`restart_acceptance.json`记录实际重启验收，`board_status_after.json`和`doa_after_restart.json`记录实机数据，`ui_acceptance.json`记录前端归一化与卡片验收，`pc_switch.json`确认PC重启未改配置。串口最终服务检查记录在 `tmp/autostart_20261103/persistent_final_A/B.txt`。

部署前本地备份位于该证据目录的 `before/`。板端模块备份：A为 `/root/doa_stage/backup_persistent_reference_20261103_7027a566eb9e`，B为 `/root/doa_stage/backup_persistent_reference_20261103_d43705c8c945`。各站 `/root/doa_stage/systemd/persistent_reference_receipt.json`记录部署收据。回退时必须同步恢复参考策略与板端/PC验证逻辑，不能只删除网页提示。
