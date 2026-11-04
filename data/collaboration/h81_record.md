# 双站永久开机启动与IQ常驻验收

2026-11-03 01:09北京时间完成。用户明确要求为此前漏启动的接收链路安装永久开机自启动，并解决IQ一小时到期退出。本轮已在A/B实际板卡安装、分别正常重启整机并验收；没有安装电脑端开机任务，没有重新拟合或替换旧相位参考。

## 已安装并启用

两站均启用`/etc/systemd/system/airspace.target`，挂到`multi-user.target.wants`，上电进入Linux后自动执行：

| 单元 | 职责 | 开机验收状态 |
|---|---|---|
| airspace-rf.service | 一次性初始化现有RF/FIR、40 MSPS、2437 MHz、manual 0/0 dB、sdr0/monitor | active/exited；这是正常oneshot状态 |
| airspace-monitor.service | 前台运行板上既有版本的接收控制、资源与解码服务 | active/running，systemd管理主PID |
| airspace-iq.service | 加载匹配side_ch，运行双RX IQ和同帧候选关联 | active/running，`--seconds 0`常驻 |

接收角色使用原持久文件：A为direction_only，B为capture_decode；B已有的DSSS信道6支持继续启用。A的lightdm由上次仅本次启动有效的mask改为永久mask，避免重启后桌面重新占用CPU。B此前已经是永久mask，本轮未额外改变其桌面配置。

`start_openwifi_rid.sh`新增`OPENWIFI_INIT_ONLY=1`入口，让RF初始化不再后台派生第二个monitor进程，避免与systemd争用。旧手动用法保持默认行为，但装好管理服务后不应并行执行旧启动脚本。IQ程序新增显式`--seconds 0`模式；旧手动入口默认仍是3600秒，10～3600秒的限时模式仍可用于实验。

常驻服务退出后5秒由systemd自动重启，不按小时主动退出或换会话；正常`systemctl stop`会保持停止。120秒内连续失败5次会限流，需要检查日志并解除失败状态，避免硬件故障时无限快速重试。初始化与两个常驻服务有依赖和PartOf关系，完整重初始化会按正确顺序停止、初始化、再启动。

## 真实验证结果

1. 本地18项测试通过：模拟越过3600秒后常驻采集仍继续；旧3600秒限时模式仍结束；停止后恢复增益、寄存器和socket；接收角色切换仅保留最新PCAP，并保留64 MiB写入上限；既有增益和新鲜度检查通过。没有为了验证常驻模式实际等待一小时。
2. 两站安装时均通过`systemd-analyze verify`。其输出包含原系统plymouth单元的KillMode弃用提示，不是本次airspace单元校验失败；安装返回0。
3. **A整机正常软件重启后约48.7秒、B约36.2秒自动恢复接口。** 验证过程中没有补执行任何手动启动命令。板端新开机时长分别约30.08/26.23秒，boot ID均发生变化，证明不是仅重启应用。
4. 两站重启后`airspace.target`均为enabled；RF、monitor、IQ单元均active；实际进程参数包含`--seconds 0`，AD9361实际读回40 MSPS和0/0 dB。
5. 分别向systemd所管理的A/B IQ主进程发送一次SIGTERM做退出恢复测试，两站均自动产生新PID，`NRestarts=1`、active/running。这里的1次是有意测试，不是未解释的异常崩溃。
6. 自动恢复后各采12个新窗口，共24窗，全部通过ESP32完整身份`RIDTEST-ESP32S3-0001`、MAC、FCS、IQ哈希、LTF与TSF关联校验，没有采集脚本错误，也没有安装新参考。

本轮为正常软件重启验收，没有直接切断电源做掉电冲击测试。开机启动配置已永久写入根文件系统并跨重启验证。

## 最终快照

01:09:54，北京时间：

- A：capturing，candidateWindows=58，无服务错误；direction_only；CPU约3.99%。
- B：capturing，candidateWindows=30，无服务错误；capture_decode；CPU约35.25%。
- B的DSSS为available/deployed/receiving/captureActive，1 Mbps长前导、2437 MHz；现有OFDM链路也保留。
- 电脑地面站接收分工确认成功，pipeline通信错误为空。

IQ每次真实重启仍生成新的会话UUID，旧相位参考因会话不匹配继续失效。永久自启动只恢复接收和计算链路，不意味着重启后自动恢复已验证的绝对DOA精度，不能把旧偏置改个session编号直接沿用。

## 存储和日常操作

IQ继续保持32窗内存/原始文件环，放在`/run/airspace-iq/window-ring`。monitor保留当前接收代次的PCAP，沿用64 MiB上限，达到上限继续解析；不无限追加JSONL或反复增加SD卡实验目录。`/run`数据是临时记录，重启或相应服务重建会清理，需要留存的证据应提前导出。服务日志使用journalctl查看。

```sh
# 查看
systemctl status airspace.target airspace-rf airspace-monitor airspace-iq --no-pager
systemctl is-enabled airspace.target

# 仅重启IQ；会改变IQ会话，需重新核验参考
systemctl restart airspace-iq

# 完整重新初始化，相关常驻服务会一起按顺序恢复
systemctl restart airspace-rf

# 停止接收链路；下次开机仍会自启
systemctl stop airspace.target

# 查看本次开机日志
journalctl -u airspace-rf -u airspace-monitor -u airspace-iq -b --no-pager
```

不再需要“一小时后断电再重启”。需要断电时，先在各板执行`shutdown -h now`正常关机，再断电；重新上电后板端服务会自行启动。电脑端网页仍需要电脑上的地面站程序运行。

## 文件、备份与回退

本机源代码和管理说明：`zynq7045_ad9361_rid_aoa/linux_doa/systemd/`；IQ连续模式修改位于同级`target_capture_service.py`，RF初始化入口位于`rid_receiver/start_openwifi_rid.sh`。

板端备份：

- A：`/root/doa_stage/backup_autostart_20261103_4131acdfbb1f/`
- B：`/root/doa_stage/backup_autostart_20261103_bfbfd36316b0/`

每站`/root/doa_stage/systemd/install_receipt.json`记录原文件、原mask状态、安装配置与备份路径。需回退时先`systemctl disable --now airspace.target`，按收据恢复原RF/IQ源码，移除本次新增单元和runtime配置，再`systemctl daemon-reload`；A的桌面状态按原收据恢复，不盲目启用。详细步骤见源目录`systemd/README.md`。

本轮证据在`tmp/autostart_20261103/`：安装包及哈希清单、A/B安装日志和收据、重启串口日志/API、新boot ID、退出自动恢复日志、`postboot_live/`原始IQ及逐窗校验、`final_services.json`。新会话期间未修改地图布站、相位标定或FPGA工程。

systemd依赖、oneshot和Restart行为按[systemd 247服务文档](https://www.freedesktop.org/software/systemd/man/247/systemd.service.html)配置，并以上述板卡实际重启与退出恢复测试验证。
