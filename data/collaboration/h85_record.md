# 信源检测双频轮扫接入与实收验收

2026-11-03，Asia/Shanghai。当前运行入口：`http://127.0.0.1:18770/#/signals`，刷新旧页面按Ctrl+F5。

## 执行前核对

用户要求先核对已有状态，再复用历史能力扩展当前检测。开始时PC服务正常，A测向待命、B完整解码，两站IQ固定2437 MHz。历史5 GHz记录来自短时扫描，不是当时实时轮扫。

复查11月2日未知图传准备/空口报告与`rid_receiver/wifi_survey_service.py`，确认已有独立的有界被动扫描；它未接入当前处理链，会在结束后恢复信道6。两站本次`iw list`均实际列出24个可设HT20信道：

| 频段 | 信道 | 中心频率 |
| --- | --- | --- |
| 2.4 GHz | 1–13 | 2412–2472 MHz |
| 5 GHz | 36、38、40、42、44、46、48、52、56、60、64 | 5180–5320 MHz |

现驱动没有5.8 GHz的149等信道，本轮不改内核/FPGA。历史更高频点导入数据仍保留，不作为当前覆盖证据。

## 当前功能与使用

- 信源检测页新增“接收频段与信道”：双频轮扫、2.4 GHz轮扫、5 GHz轮扫、固定信道。
- 已启用并保存双频轮扫。每频点完成读回确认后驻留3秒，交替扫描两频段，定期回访信道6；完整一轮约两分钟，受网络和切频开销影响。
- 逐信道接收并非同时全频接收。各信源按实际接收年龄显示，离开信道后允许过期，不能把整轮发现的信源都称为当前持续在线。
- 帧列表新增频率列，信源汇总新增距上次观测秒数，继续保留MAC/频点区分与有界缓冲。
- 点击某信源的“AOA测向”会保存固定到目标信道；结束专注后在上方重新应用双频轮扫。
- 配置写入`rid_receiver/ground_station/runtime/channel_scan.json`，刷新/重启PC服务后保留。PC后台负责调度；关闭浏览器不停止轮扫，停止PC服务后板卡停留在最后接收频点。

## 复用与协调

将旧工具的信道集合与`iw dev sdr0 set channel ... HT20`提取为`rid_receiver/wifi_channels.py`，旧扫描工具与新实时调度共用。未启动第二套独立采集进程争用硬件。

新PC模块`ground_station/channel_scan.py`协调两站，`GET/POST /api/channel-scan`同时返回期望范围、确认信道及每站状态。A/B同频切换，B仍承担完整检测/解码，A仍是测向待命；接收站选择仍沿用原功能。其他测向站离线会明确列出错误，不阻断所选检测站；所选检测站切频失败则不声称已经接收成功。

板端`target_capture_service.py`新增服务间`POST /api/iq/channel`。实际切频由原DMA拥有线程执行，先暂停采样，切频并核验AD9361读回，再生成新会话、清空旧目标/原始IQ/参考帧/相位结果。相同信道确认保留会话，不因周期核验重复重置。服务在支持的5 GHz频点重启可以继续运行。

B的`dsss_mailbox.py`按实际射频读回跟随2.4 GHz信道，切频时丢弃旧邮箱帧并等待稳定；5 GHz时停用DSSS支路并令其频率为空。继续只支持原1 Mbps长前导能力，不把DSSS当成OFDM测向。

PC测向队列只调度当前确认频点的目标；板端仍做MAC/FCS/LTF/TSF关联及本地DOA，PC不恢复日常下载原始IQ。跨频率不应用2437 MHz参考。保留用户授权的户外固定参考跨会话复用策略；参考仍要求其他接收与几何条件匹配。本轮没有新增标定，也未验证5 GHz绝对测向精度。

长期轮扫的实时信源缓存满时替换最早观测项，保持256项上限；独立历史扫描的CandidateStore默认拒绝溢出策略不变。

## 实机验收

1. 全部24个信道取得A/B切频及实际频率确认，记录的轮扫阶段无错误。
2. 持续观察约93秒（从已经进入首轮后开始，到24个信道全部确认）记录1934个不重复FCS有效帧，其中5320 MHz有1478帧；其他有效帧来自2412、2417、2422、2427、2432、2437、2442、2447、2452、2457、2462、2467 MHz。最后确认信道13时结束该统计，不能据此认定信道13没有信号；未收到有效帧的其他5 GHz信道也不能推断没有射频活动。
3. 当前5 GHz信源汇总实际出现5320 MHz的`anonymous-wlan`、`anonymous-wlan`、`anonymous-wlan`等OFDM发送端。普通Wi-Fi没有被自动判作无人机。
4. 两站固定信道36/5180 MHz时，B真实执行`systemctl restart airspace-iq.service`，监测和IQ服务均active，两站RF读回约5180000002 Hz且无IQ错误；B的DSSS为`unsupported_frequency`、`captureActive=false`。
5. 切回信道6后，B的DSSS恢复2437 MHz实收，原参考源重新产生A/B两站测向结果，处理链错误为空。此检查仅确认链路恢复，不代表绝对精度重新验收通过。
6. 最终重新启用并保存双频轮扫，新PC实例确认两站在5180 MHz接收，接收分工已确认且切频错误为空。原`doa_config.json`、`receiver_config.json`、`aoa_calibration_A/B.json`四文件SHA256逐项保持不变，地图Key保留。

## 自动检查

最终Python检查：地面站130项、接收模块37项、历史扫描7项、板端DOA5项、常驻服务4项，共183项通过。新增扫描API/调度、切频隔离、回放禁止硬件写入、有界缓存及5 GHz重启均有回归覆盖；修改的4个前端文件语法检查通过。

前端15组检查中，轮扫控制及其他12组通过，2组既有文案断言未通过：`aoa-status.test.mjs`仍期待“重新核验参考”，`tile-fallback.test.mjs`仍期待“连续加载失败”。检查期间`monitor-data.js`与`map-controls.js`发生了本任务之外的同时修改，新文案已不同；保留这些改动，没有为通过旧断言回改文案或修改对应测试。日志中明确保留失败，未宣称全前端检查通过。早先一轮该15组曾全部通过；最终状态以上述13/15为准。本轮未做完整浏览器目视验收，控件行为通过自动交互测试和真实HTTP核对。

## 证据与回退

本机目录：`F:/2026fpga/tmp/multiband_20261103/`。

| 文件 | 内容 |
| --- | --- |
| `before/`、`before_hashes.json` | 修改前源文件备份 |
| `manifest.json`、`multiband.zip` | 实际板端部署包及SHA256清单 |
| `A_install.txt`、`B_install.txt` | 板端校验、备份、安装及角色恢复回执 |
| `live_scan_records.json`、`live_scan_summary.json` | 本次实际轮扫确认与有效帧频率统计 |
| `restart_iq_5GHz_B.txt`、`fixed_5GHz_after_restart.json` | 5 GHz服务重启与DSSS停用证据 |
| `channel6_restored.json` | 信道6接收/测向恢复 |
| `final_live_state.json` | 最终双频轮扫、接收分工、配置校验 |
| `qa_*.log`、`qa_results.json` | 最终自动检查的真实结果，含两项前端旧文案失败 |

板端修改前备份：A为`/root/doa_stage/backup_multiband_20261103_b7ce735d`，B为`/root/doa_stage/backup_multiband_20261103_4886c5e8`。回退时先在页面固定信道6，再停止PC服务；在各板停止IQ/监测服务，按备份`receipt.json`恢复原Python文件（原本不存在的`wifi_channels.py`按回执处理），再启动原systemd服务；PC恢复本机备份的修改文件。未变更FPGA、BOOT、设备树、内核或systemd单元。
