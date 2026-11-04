# A/B两站上电自启动复查报告

复查日期：2026年11月3日，北京时间。最终在线验收快照为04:59:57，报告整理于05:00。

## 1. 复查结论

**A/B当前所需的板端业务均已纳入永久开机启动链路，并通过本次分别正常软件重启整机的验证。重启后没有补执行任何业务启动命令，两站自动恢复RF初始化、接收服务、常驻双RX IQ与单站DOA，以及后续新增的识别服务。**

本轮未发现遗漏自启动的板端业务，无需补装或重新启用服务。未改写板端systemd单元、应用源码、BOOT.BIN或持久接收角色。两站重启前后业务文件及BOOT.BIN哈希一致，角色与识别配置一致。

本次验证采用正常软件重启，**没有直接切断电源做掉电测试**。结论覆盖Linux正常启动后的自动拉起和当前在线恢复情况，不代表绝对测向精度验收，也不包含新增的一小时连续运行试验。

## 2. 复查范围与当前分工

| 项目 | A站 | B站 |
|---|---|---|
| RF、FIR、OpenWiFi及接收接口初始化 | 自动完成 | 自动完成 |
| monitor接收控制与资源接口 | 自动运行，保留`direction_only`角色 | 自动运行，保留`capture_decode`角色 |
| 完整空口帧解码、RID与载荷字段提取 | 完整全量解码保持关闭；测向所需目标帧关联仍由本机IQ链路执行 | 完整解码运行，OFDM与已有DSSS接收支路正常 |
| recognition服务 | 执行识别评分、分类和定位路径判断 | 导出已解码的观测供A站识别 |
| 双RX IQ及单站DOA | 自动常驻，按任务采样和计算 | 自动常驻，按任务采样和计算 |

每站各有3个常驻业务进程：monitor、IQ/DOA、recognition。RF是一次性初始化服务，不需要长期保留一个工作进程；其`active/exited`为正常状态。

PC地面站仍负责同步切频、目标轮询和任务续租、B→A观测转发、结果汇总及地图显示。**板端自启不等于PC程序也已配置开机自启。** PC未运行或没有任务时，板端可能显示`waiting_feed`、`waiting_target`；这与业务服务未启动是不同情况。

## 3. 永久启动链路核对

两站均确认以下持久关系存在于`/etc/systemd/system`，不是只对本次开机生效的临时配置：

1. `multi-user.target.wants/airspace.target`链接存在，`airspace.target`为`enabled`。
2. `airspace.target`通过`Requires`拉起`airspace-rf.service`，通过`Wants`拉起monitor、IQ和recognition。
3. `airspace.target.wants/airspace-recognition.service`链接存在，后续新增的recognition服务为`enabled`，没有漏挂开机目标。
4. monitor和IQ在RF初始化之后启动；recognition在monitor和IQ之后启动。
5. 各单元`NeedDaemonReload=no`，磁盘上的单元与systemd已加载配置一致。

RF、monitor、IQ的`UnitFileState=static`属于当前设计：它们由已启用的`airspace.target`依赖拉起，**不表示没有自启动**。monitor、IQ、recognition均保留`Restart=always`，RF保留`Restart=on-failure`；本次重启后各业务服务的`NRestarts`均为0。

两站的`systemd-analyze verify`均返回0，`systemctl --failed`均为0个失败单元。校验输出保留了原系统plymouth单元的`KillMode=none`弃用提示；该提示不属于本轮airspace业务单元校验失败，本轮没有修改该系统单元。

## 4. 本次整机重启验证

两站依次执行身份核对、`sync`和`systemctl reboot`。A站业务恢复后再重启B站。重启期间PC地面站保持运行，没有发送额外的板端业务启动命令。

### 4.1 确认发生了整机重启

| 站点 | 重启前boot ID | 重启后boot ID |
|---|---|---|
| A | `08f5b351-01d9-4f73-9635-97aeab1620bc` | `06831969-a3af-4e9f-91ae-35e7dd7932ad` |
| B | `589149a7-98ed-43ae-8e2a-36f5c3952158` | `7bcf4071-bb34-4b7c-9bed-51f96ff5afce` |

boot ID均改变，结合系统运行时间和本次启动日志，确认不是仅重启应用进程。

### 4.2 本次开机的服务状态与启动时间

下表时间来自`ActiveEnterTimestampMonotonic`，表示**相对本次内核启动**进入active的时间，不包含上电到内核启动前的引导时间，也不是从发出重启命令开始计时。

| 单元 | A站状态 | A站启动时间/s | B站状态 | B站启动时间/s |
|---|---|---:|---|---:|
| `airspace-rf.service` | active/exited | 20.710 | active/exited | 20.504 |
| `airspace-monitor.service` | active/running | 23.392 | active/running | 23.391 |
| `airspace-iq.service` | active/running | 24.710 | active/running | 24.432 |
| `airspace-recognition.service` | active/running | 24.746 | active/running | 24.473 |
| `airspace.target` | active | 24.751 | active | 24.483 |

B站从发出重启命令到验收脚本确认三个HTTP服务可用约39秒。A站首次轮询脚本把空`errors`对象误判为失败，导致该轮轮询未生成恢复耗时结论；已修正此判断，并用新boot ID、本次开机服务时间、串口审计和在线接口完成A站验证。**该脚本误判没有触发手动启动或第二次重启，不作为A站自启失败的依据。**

### 4.3 进程归属与常驻参数

| 站点 | monitor PID | IQ/DOA PID | recognition PID | 重复手工业务进程 |
|---|---:|---:|---:|---:|
| A | 531 | 530 | 599 | 0 |
| B | 521 | 520 | 585 | 0 |

上述PID仅为本次快照，后续重启会变化。三个进程均归属对应systemd单元，父进程为PID 1。两站IQ实际进程参数均包含`--seconds 0`，不是旧的3600秒限时模式。

## 5. 重启后的在线业务验证

最终快照确认：

- 接收分工`confirmed=true`；A保持测向待命，B保持完整检测/解码。
- B站`receiving=true`；DSSS为`available/deployed/captureActive=true`、`state=receiving`，1 Mbps长前导接收正常。快照中DSSS硬件FCS通过计数为236，属于本次重启后的累计值。
- B→A观测转发重新获得`acknowledged=true`，A站重新进入`classifying`，来源为B站。
- A/B的IQ均回到`capturing`，两站IQ会话编号均为本次重启后的新值。
- 最后约4秒的两次采样中，A/B的`doaAccepted`分别增加4、3，说明重启后产生了新的板端处理结果，并非只显示历史缓存。该计数不等于绝对角度精度通过。
- 处理链`direction.errors={}`，两站没有未解释的业务启动失败或自动重启循环。
- 两站实际RF读回约2437 MHz、采样频率40 MS/s，双路增益均为manual 0 dB。

正常开机后不需要再执行旧的手动monitor/IQ启动脚本，也不应并行启动第二套采集进程。后续检查使用systemd与实际HTTP接口。

## 6. 日常复核命令

在各板终端执行：

```sh
systemctl status airspace.target airspace-rf airspace-monitor airspace-iq airspace-recognition --no-pager
systemctl is-enabled airspace.target airspace-recognition.service
systemctl --failed --no-pager
journalctl -b -u airspace-rf -u airspace-monitor -u airspace-iq -u airspace-recognition --no-pager
```

需要断电时先正常关机，待关机完成后再切断电源。板端启动与PC地面站程序启动分开管理；本轮没有新增PC开机任务，也没有重新拟合相位参考。

## 7. 证据与相关文件

证据主目录：[tmp/boot_recheck_20261103/]（见对应归档说明）。

| 文件 | 内容 |
|---|---|
| [summary.json](../evidence/6f843b10b4169c2d.json) | 最终结构化结论、boot ID对比、服务状态、哈希一致性和在线观测增量 |
| [A_before.json](../evidence/4c9d50827e450204.json)、[B_before.json](../evidence/c8f50868005595de.json) | 重启前真实单元、依赖链接、进程、角色、RF及文件哈希 |
| [A_after.json](../evidence/c66013498c6fc58a.json)、[B_after.json](../evidence/66aebf5a39cd25f7.json) | 本次重启后的同项审计与启动日志 |
| [A_reboot_console.txt](../evidence/36b6ec349fac6ed3.txt)、[B_reboot_console.txt](../evidence/3c5322f5823f4362.txt) | 整机重启串口记录 |
| [A_recovered_api.json](../evidence/75fb1b793867365f.json) | A站重启后的独立接口复核；其中B站重启期间的`waiting_feed`为当时真实状态 |
| [B_reboot_api.json](../evidence/e3b949afa432c334.json) | B站约39秒自动恢复的接口记录 |

运行维护说明已同步补充到[systemd/README.md](../evidence/2ba324cb1cd8c66c.md)。此前永久自启安装背景见[11.03_01.09_双站永久开机启动与IQ常驻验收.md](h81_record.md)，本报告以本次实测复查结果为准。
