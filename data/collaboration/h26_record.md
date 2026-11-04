# 任务：方案A全链路推进——OpenWiFi OFDM → monitor → RID → 地面站

开始时间：2026-10-31 21:40，Asia/Shanghai。

## 本轮目标与范围

继续“空域知微——无人机侦测定位系统”，将现有OpenWiFi接收链推进至真实RID解析和PC地图地面站实时显示。驱动加载、监听与首帧只是过程，不以其完成作为本轮预设停止点。

优先读已有报告及执行结果，复用已完成的部署、构建和校验，不全面重查或重复编译。允许连接开发板、加载匹配模块、配置monitor/固定信道、被动收包，以及实现必要的RID捕获/数据桥接与地面站最小改动。出现明确错误时，定位并修复首个阻塞，记录实际证据。

本轮不开发DSSS、不改DOA算法、不做双站定位、不主动发射测试包；不格式化、不覆盖BOOT.BIN、不自动重启。确有必要扩展到内核/RTL/启动文件时，先完成诊断并记录具体变更依据，避免扩大范围。

## 已知条件

- 工程：`F:\2026fpga\zynq7045_ad9361_rid_aoa`。
- RID软件与地图：`F:\2026fpga\rid_receiver`。
- 当前内核：`5.15.0-175919-g427c94e8faa5-openwifi-rx1`。
- 模块目录与`/root/openwifi_rx1`已部署，196文件复制后校验通过，depmod已执行；不重复该工作。
- 当前含网口修复的DTB SHA256：`56bf5810d0d50883b16b127cd8560ec6c0bfa4f60828f1d7cd6701f4505ba32f`，不以旧部署包DTB覆盖。
- 串口COM9/115200；上次IP `169.254.92.202`，运行状态以轻量回读为准。
- 已分析的队友模块样本：`tmp/esp32_gps(1).pcapng`，信道6/2437 MHz、6 Mbps OFDM、Wi-Fi Beacon。
- 源MAC/BSSID：`mac_aa98f353b5`；SSID：`RID-TEST`；Basic ID：`RIDTEST-ESP32S3-0001`。
- 样本FCS正确，现有解析器成功提取Basic ID/Location/System；它是参考机抓包，不是本板接收证据。

## 执行要求

1. 文件名一律采用`日期_时间简要标题.md`，日期与时间之间使用下划线。
2. 直接利用当前已有状态，只核对运行环境、依赖和冲突，不将历史未验证状态当作必须重做的清单。
3. 优先使现有驱动与monitor运行；保持串口控制，注意wgd.sh的网络服务操作。
4. 捕获真实帧，保存原始数据及FCS依据，核对已知模块指纹。未接收到目标时区分发射源条件、PHY/DMA和上层链路问题。
5. 复用现有RID解析，明确处理radiotap、尾部FCS、未知值、起飞点/操作者位置语义与时间基准。
6. 打通板端到PC的以太网事件传输，接入现有地图地面站；真实、回放与模拟模式明确分开。避免新增复杂框架、数据库或云服务。
7. 验证原始帧→RID事件→接口→地图输入的一致性，提供启动方式、数据来源、过期/断开行为、实验日志和剩余限制。
8. 只运行有意义且与修改相关的检查；不Git add/commit/push。不编造实测、距离、定位或接收率。
9. 真实空口条件暂缺时，继续完成不依赖空口的捕获工具、协议桥接与真实PCAP回放验证；准确记录哪一段仍需实测，不把回放冒充实时接收。

## 执行结果

### 1. 当前结论（2026-10-31晚间实测）

**已打通“AD9361/OpenWiFi OFDM → monitor → 真实RID解析 → 以太网 → PC地面站API/前端目标状态”的实时身份链。尚未完成有效实时当前位置绘图验收，原因是ESP32发射端正在主动把Location位置字段编码为未知值，并持续报告GNSS unavailable/stale。用户已明确将GPS接收问题留到后续，本轮按实际可接收到的数据完成接收与展示，不再继续排查GPS。**

这次没有以加载驱动或出现sdr0作为停止条件。实际收到的目标是队友的ESP32-S3模块：

```text
源MAC/BSSID：mac_aa98f353b5
SSID：RID-TEST
Basic ID：RIDTEST-ESP32S3-0001
承载：Wi-Fi Beacon / 2437 MHz / 信道6 / 6 Mbps OFDM
消息：Basic ID、Location、System
```

一次保存的实时快照含208条该目标RID、353个通过校验的接收帧，解析错误0；脚本重新启动后又收到27条新RID，地面站API与前端状态再次核对通过。上述为不同采集时刻的计数，不是收包率或发送端总量。环境中其他坏帧也被原样记录并拒绝进入RID解析结果。

最终归档时，重新启动后的同一段采集增长至**3091个原始帧、291个通过校验的帧、167条目标RID、解析错误0**，其余2800个原始帧校验失败。这里混有环境流量，不能把291/3091当作ESP32的接收率。

当前Location的经纬度、速度及高度仍未知；早期实时System包含起飞点坐标，发射模块重启后该参考点也可能未知。地面站分别处理当前位置和广播参考点，未用旧PCAP或System坐标填补实时无人机位置。

### 1.1 本轮实际收到的其他数据

下表取自最终`board_state.json`的目标消息，不以旧参考PCAP补齐缺失值：

| 层级/字段 | 实际结果 | 说明 |
| --- | --- | --- |
| 802.11源MAC/BSSID | `mac_aa98f353b5` | 外部发射模块，不是本机sdr0地址 |
| SSID | `RID-TEST` | 从通过校验的Beacon帧提取 |
| 频率/信道 | 2437 MHz / 6 | 当前固定接收条件 |
| 速率/PHY | 6 Mbps / legacy OFDM | 来自修复后的radiotap |
| RSSI | 最终状态快照−7 dBm，部分已关联帧为−10 dBm | 驱动报告值，未在本轮做绝对功率校准 |
| 接收校验 | 通过硬件CRC32＋保留CRC24交叉检查 | 原始PCAP仍含OpenWiFi状态尾部 |
| RID承载 | Wi-Fi Beacon，Vendor IE `FA:0B:BC/0D` | 不是蓝牙或NAN |
| Message Pack | 版本2，3条消息，每条25字节 | Basic ID / Location / System |
| 消息计数器 | 最终目标快照为64 | 当前帧计数值，持续变化并可回绕 |
| UAS ID | `RIDTEST-ESP32S3-0001` | 广播声明，未做身份签名认证 |
| ID类型 | 1，序列号类型 | 不等于已验证的官方注册身份 |
| 设备类别 | 2，直升机/多旋翼 | 发射端声明 |
| 飞行状态 | 1，地面 | 本次不是飞行轨迹实测 |
| 航迹方向、水平/垂直速度 | 未知 | 不用0°/0 m/s替代 |
| Location经纬度 | 未知 | 不绘制实时无人机当前位置 |
| 气压高度、几何高度、相对高度 | 未知 | 不把起飞点高度替代飞行高度 |
| 相对高度参考类型 | 起飞点 | 类型存在不代表高度值有效 |
| 位置/高度/速度/时间精度 | 编码0，未知 | 不解释为误差0或0秒精度 |
| Location时间 | 未知 | 编码`ffff`，不当作Unix时间 |
| System位置类型 | 0，起飞点 | 与操作者实时位置分开 |
| System起飞点经纬度/几何高度 | 最终快照未知 | 早期保留值不作为最终GPS有效证据 |
| System区域数量/半径 | 1 / 0 m | 广播字段，不据此声称定位范围或误差 |
| System区域上下限 | 未知 | 缺失值保留 |
| 分类类型 | 未声明 | 不根据类别码0臆测分类 |
| System时间戳 | 原始值0，未就绪 | 不解释为当前真实时间 |
| Authentication/Self ID/Operator ID | 本段目标消息中未收到 | 不推断模块在所有模式下都不支持 |

原始消息十六进制、最后接收时间、源地址与接收参数完整保存在JSONL和板端状态中。地面站重点展示ID、类别、状态、位置有效性、来源及接收参数；其余原始字段保存在报告与日志，避免用默认值补造遥测。

### 2. 本轮真正遇到并处理的问题

1. **默认网络服务抢占monitor接口。** dhcpcd/WPA反复将sdr0切回managed，导致捕获报Network is down。现在为临时名wlan0及最终名sdr0增加`denyinterfaces sdr0 wlan0`，停止Wi-Fi关联服务；以太网仍由dhcpcd维护。原配置备份在板端`/root/openwifi_rx1/rid_service/dhcpcd.conf.before_rid`。首次应用需要重启dhcpcd以重新读取规则，曾短暂等待网口恢复。
2. **热重配没有复现首次成功启动的RF顺序。** 最终脚本使用RF/FIR初始化在先、sdr主驱动重新加载在后的顺序，之后再设置monitor/信道。只操作已有模块，不重载FPGA。
3. **mac80211 radiotap存在一行偏移错误。** 原字段指针指向最后一个presence word而非其后，TSFT对齐填充覆盖位图。实抓位图曾为`0x25`，造成速率/FCS/RSSI误读。改为`it_present + 1`后，常规legacy帧位图恢复为`0x482f`，频率/速率及坏FCS标记正常。参考[Linux上游修正后的代码](https://github.com/torvalds/linux/blob/master/net/mac80211/rx.c)。
4. **OpenWiFi尾部含硬件状态，不能当作普通完整FCS。** `byte_to_word_fcs_sn_insert.v`会把最后一个FCS字节替换为`{fcs_ok, rx_pkt_sn}`。实时服务同时核对硬件CRC32结果及保留的24位CRC，保留原始PCAP字节；参考网卡PCAP仍做完整软件CRC32。没有重写/补造一个可通过的软件FCS。
5. **固定增益不适合当前近距离源。** 起初ESP与接收天线仅几厘米，46 dB手动增益时出现大量错误帧。后续改用fast_attack AGC，并由用户把ESP移到约1米后成功收到连续RID。两个条件先后变化，本轮不把改善完全归因于其中单一因素。
6. **独立GPS数据未就绪。** ESP32串口反复打印`GNSS unavailable/stale; Location fields are encoded as unknown`，与实时广播一致。GPS放窗外是必要实验条件之一，但仍需核对GPS→ESP的数据接线、波特率及实际定位状态；不能仅凭GPS已供电推断UART数据有效。

另外，开发过程中一次把TX衰减拉满的设置触发了该驱动的radio硬阻断判断，已撤销；最终沿用驱动正常radio-on机制，采集程序自身不发送无线帧。

### 3. 修改和新增文件

工作区相对路径：

| 文件 | 作用 |
| --- | --- |
| `rid_receiver/capture_io.py` | 标准库PCAP/PCAPNG读取、radiotap拆包、FCS/硬件尾部检查、原始PCAP写入 |
| `rid_receiver/monitor_service.py` | 板端AF_PACKET被动捕获、复用RID解析、JSONL留存、只读HTTP状态/抓包下载；也支持明确标记的PCAP回放 |
| `rid_receiver/receiver.py` | 原Store增加单调时钟时间与接收元数据，沿用已有字段解码和聚合 |
| `rid_receiver/start_openwifi_rid.sh` | 一次性配置既有接收链、网络管理排除、fast_attack增益，启动捕获服务 |
| `rid_receiver/ground_station/rid_bridge.py` | PC按网口读取板端状态，处理字段新鲜度、当前位置/参考点及时间基准 |
| `rid_receiver/ground_station/serve.py` | 为现有静态地图增加`/api/rid`，支持`--board-url` |
| `rid_receiver/ground_station/rid-live.js` | 同源HTTP轮询接入已有ingestRID，处理断开与模式隔离 |
| `ground_station/app.js`、`data.js`、`index.html` | 显示空口源MAC、接收参数、实时/回放标志、位置缺失和独立参考点 |
| `rid_receiver/ground_station/start_openwifi.bat` | PC实时接入启动入口 |
| `rid_receiver/OPENWIFI_LIVE.md` | 板端/PC启动、停止、回放、FCS含义与限制 |
| `rid_receiver/tests/test_monitor.py`、`ground_station/rid-live.test.mjs` | 真实样本、CRC、HTTP桥接、新鲜度和前端输入核对 |

现成WSL缓存`/root/openwifi_rx1_build/linux/net/mac80211/rx.c`只应用上述一行修复，仅重编`mac80211.ko`；原Module.symvers与部署包完全一致。没有重编uImage、FPGA或修改DTB/BOOT.BIN。DOA源码和算法没有修改。

修复模块：570188字节，SHA-256：

```text
541685f5bf9bf0d55b36e6f55676af1274d6472eaea5c328a98e8ab97cb438f8
```

板端原mac80211备份：`/root/openwifi_rx1/rid_service/mac80211.before_radiotap.ko`。补丁在`tmp/openwifi_a_20261031_2140/mac80211_radiotap_cursor.patch`及部署包`build_info/`。

### 4. 验证结果与证据

- 14项Python测试通过，含原9项与新增真实样本/CRC、OpenWiFi状态尾部、空PCAP、HTTP链路、位置过期和不以起飞点替代当前位置的检查。
- 前端JS语法、既有data.test和真实API→RID连接器→前端目标状态检查通过，包含断开后不刷新旧数据、模拟模式隔离。
- 使用用户原始PCAP验证参考回放→RID→HTTP→地图API，ID与原始经纬度一致，明确标记回放。
- 使用本板实时数据验证同一网络/API/前端接入，`mode=live`、`demo=false`、`replay=false`，源MAC和ID正确，观测年龄小于10秒。
- 已把一条地面站实时观测匹配到本板PCAP第2260帧，源MAC、Basic ID和Location值一致；对应关系见`live_frame_evidence.json`。此帧同样携带未知Location，不因绘图需求改写其内容。
- 对现有40 MSPS数字接口做了RX PN时序眼图分析，存在通过区域；随后RX数字调谐返回成功，延时寄存器由0x08选至0x09。该测试只验证数字接口时序，不代表RF解调或DOA精度；原0x08也在观察到的通过区内，不把这次调谐称为误码的已证实根因。
- 最终启动脚本重新运行后，monitor、自动增益与真实RID均恢复；服务源码及启动脚本在板端与电脑端SHA-256一致。
- 当前会话没有可用的交互式浏览器执行入口，未取得新页面截图；本轮页面验证覆盖真实HTTP、数据适配与前端目标状态，不冒称完成浏览器视觉验收。

电脑端证据目录：

```text
F:\2026fpga\tmp\openwifi_a_20261031_2140\
  board_state.json              板端实时状态快照
  capture.pcap                  从本板下载的原始空口记录
  map_live_verified_208.json     208条RID阶段的地面站实时API
  map_live_api.json              最终重新启动后的地面站实时API
  map_replay_api.json            参考抓包的回放API，独立标记
  live_frame_evidence.json       地面站观测对应本板PCAP第2260帧
  board_uart_final.log          当前接口、启动文件/模块哈希、40 MSPS眼图
  mac80211_radiotap_cursor.patch
  mac80211_radiotap.ko
  mac80211_build.log
```

板端本轮各次实验位于`/root/openwifi_rx1/experiments/`；最终目录以`/root/openwifi_rx1/rid_service/last_run`为准。板端时钟曾为2023年，目录和PCAP日期不是精确实测时间基准；PC显示使用接收时刻与板端单调年龄进行映射。

### 5. 现在怎么使用

本轮PC地面站已启动：**http://127.0.0.1:18770/**。

页面外部输入模式显示当前真实身份与接收状态。Location没有有效坐标时保留目标列表/详情，并显示缺少当前位置；GPS恢复后通过同一接口更新当前位置。地图上可点击目标或“全部目标”定位到有效广播坐标。

以后开发板启动后运行：

```sh
sh /root/openwifi_rx1/start_openwifi_rid.sh
```

PC双击：

```text
F:\2026fpga\rid_receiver\ground_station\start_openwifi.bat
```

也可按`rid_receiver/OPENWIFI_LIVE.md`使用命令行指定板卡IP。无需安装Scapy或ESP32编译环境；本轮未安装ESP32 SDK，也未修改或烧写ESP32固件。

部署包已同步mac80211修复和新运行服务，更新后210个交付文件纳入manifest。当前SD已具备这些运行内容，不需要用户再次复制整卡。尤其不要用旧boot/system.dtb覆盖已修复网口的板端DTB。

### 6. 剩余事项与当前边界

1. **有效实时坐标尚待发射端GNSS恢复，用户已明确后续再处理。** 本轮停止GNSS排查，不盲目更改接线、GPIO、波特率或烧写发射端固件。当前工作区未找到其源工程。
2. 读取原生USB串口COM12时触发ESP32一次USB_UART_CHIP_RESET；已观察其重新启动并恢复广播。COM11读取到上述GNSS告警，未修改固件。COM9/COM11/COM12均已释放。
3. 真实浏览器交互和有效实时GPS坐标的地图标点仍需最后确认；真实PCAP的位置回放、实时身份接入及前端状态已验证，二者不能混称。
4. 本轮没有做正式距离/接收率指标、DOA身份关联、双站定位或频段兼容扩展。以后继续推进时从实际未完成项出发，不重复驱动部署或重新开展G1/G2。
