# 空域知微 无人机侦测与双站测向系统

空域知微以两台 **Zynq XC7Z045 与 AD9361 软件无线电平台**为核心，通过被动接收 Wi-Fi 信号完成检测采集、特征识别、RID 身份解析，以及受支持信号的单站 DOA 与双站 AOA 几何交汇。系统服务于低空信源观测、无人机广播身份接收和测向实验，PC 地面站提供目标、轨迹、信源证据与设备状态展示。

本仓库同时交付完整源码、构建入口、仿真输入、历史实收回放、板端文件生成方法、复现说明、技能包和大模型协作记录。**可以先不接板完成离线验证；绝对测向精度需要独立的现场标定和真值验收，不能用回放或软件测试代替。**

## 阅读导航

- [1 总体方案与固定布站](#1-总体方案与固定布站)
- [2 PC地面站启动架构与配置](#2-pc地面站启动架构与配置)
- [3 A/B平台分工与资源利用率](#3-ab平台分工与资源利用率)
- [4 仓库目录及源码交付方式](#4-仓库目录及源码交付方式)
- [5 复现前提](#5-复现前提)
- [6 第一步 恢复完整源码并核对文件](#6-第一步-恢复完整源码并核对文件)
- [7 第二步 一轮快速离线验收](#7-第二步-一轮快速离线验收)
- [8 第三步 FPGA 从源码构建](#8-第三步-fpga-从源码构建)
- [9 第四步 Linux 内核与驱动](#9-第四步-linux-内核与驱动)
- [10 第五步 启动文件和板端部署](#10-第五步-启动文件和板端部署)
- [11 结果记录与贡献范围](#11-结果记录与贡献范围)

## 1 总体方案与固定布站

### 1.1 四级处理链与系统架构

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


### 1.2 四级处理链的实现与验证

| 处理层级 | A 站职责 | B 站职责 | 结果与使用边界 |
| --- | --- | --- | --- |
| 检测采集 | 保留 OFDM 接收硬件，按目标采集本机同步双 RX IQ | 完整 OFDM/已验证 HT20 帧接收及新增 DSSS 支路，同时采集本机双 RX IQ | 帧、时间、频点和对应 IQ 窗口；B 历史 DSSS 实收硬件 FCS 通过 2035 帧、主机复制 1648 帧，二者不能混为已上传数量 |
| 特征识别 | 汇总 B 的结构化观测，执行候选评分、分类与逐项证据判定 | 提取 802.11、可见 IPv4/UDP、SSID、帧长、重传及载荷结构 | 输出 RID 类、图传候选、普通或未知 Wi-Fi；加密载荷不据此加明文协议分 |
| 身份解析 | 汇总身份与位置时效，判断 RID 直显或 AOA 分流 | 识别 RID 封装并解析身份、位置、高度、速度等广播字段 | 保留来源与接收时效；没有 RID 不虚构实名，结构校验不等于身份认证 |
| 测向定位 | 本机 Linux CPU 完成 LTF 搜索、同帧校验、52 子载波相位、参考修正和单站 DOA | 本机 Linux CPU 独立完成同样处理，提供第二站角度 | PC 核对目标、帧、时效和配置后做交汇；接收与解析 DSSS 不表示已经支持 DSSS 测向 |

A/B FPGA 均接入 AD9361 双 RX 数字 IQ，完成站内数据对齐、窗口缓存与 DMA。B 的 DSSS 支路当前限定 **1 Mbps DBPSK、长前导**，A 未集成该支路。HT20 完整帧已观察到短 GI、MCS 0–7 的有效帧，IQ 测向关联仅对短 GI、MCS 0–5 完成对应验证，两项能力分别记录。

单站 DOA 的板端迁移曾以 **590 个历史真实窗口**逐字段对照；24 个新实收窗口独立复算最大差约 `1.4e-14`。正常约 20 秒观察中，两站各新增 20 个有效结果，PC 原始 IQ 请求和下载字节增量均为 0。这证明计算位置与链路行为，不能据此认定绝对测向精度已经通过。详见[板端迁移记录](data/collaboration/h82_record.md)。

### 1.3 固定布站与前向参考

总纲领约定的固定布局为 **A 右 B 左，两站中心距 2.8 m，每站双天线中心距 6 cm，参考点在两站中点共同正前方 3 m**。站间距按两组双天线的中点计算，不能与站内阵距混淆。

```text
                       参考点
                       (0, 3 m)
                          ↑ 共同前向

          B 站            中点             A 站
       (-1.4 m, 0)       (0, 0)         (+1.4 m, 0)
          左侧       ← 站间 2.8 m →         右侧

                  每站内部双天线间距 0.06 m
```

这是以两站中点为原点的局部示意，不表示测得了地理北向或精确站址。中点前方 3 m 的参考点对 A/B 的理想相对来向约为 **−25.0169°／+25.0169°**，不能同时把两站该位置的真实来向设为 0°。

固定参考按明确授权保留历史采集来源，可跨普通重启重新用于新采集；频率、采样率、增益、阵距与几何等条件仍需匹配。默认授权复用与面板新建基准的会话核验分开管理。文件一致或下发成功不等于模拟通道相位仍匹配，也不等于精度重新通过。

随包保存配置是历史联调快照，文字布站说明与数值坐标需要现场核对；新硬件或新现场应按实测几何填写，不能直接把历史配置当精确测量。参考策略及后续状态隔离修订见[协作记录](report/llm_collaboration.md#413-基准文件不变仍可能需要拒绝当前角度)。

### 1.4 已验证范围与限制

| 项目 | 当前记录支持的能力 | 使用边界 |
| --- | --- | --- |
| 接收 | A 保留 OFDM 测向采样，B 完整解码 OFDM/已实收 HT20，并有 1 Mbps DBPSK 长前导 DSSS | 不覆盖全部 802.11n、全部 DSSS/CCK 制式或专有图传 |
| 频段 | 2.4 GHz 信道 1–13；5 GHz 信道 36、38、40、42、44、46、48、52、56、60、64 逐信道轮扫 | 不同频点接收存在间隙；当前未覆盖 5.8 GHz，不是同时全频接收 |
| 单站测向 | 两站各自 Linux 处理 OFDM LTF、同帧关联、相位及参考修正 | 当前 DSSS 接收不代表 DSSS 测向；HT20 IQ 关联仅完成短 GI、MCS 0–5 的对应验证 |
| 双站定位 | 验证过同源同帧交汇及独立移位响应 | 两天线存在方向多解；异帧、过期或参考失配时拒绝输出 |
| 常驻运行 | systemd 管理两站 RF、monitor、IQ/DOA 与识别服务，IQ 使用 `--seconds 0` | 常驻不等于连续无间隙满带宽处理；没有目标可正常等待 |
| 实验参考 | 历史固定布局为 A 右 B 左、基线 2.8 m、站内阵距 6 cm、参考点在中点前方 3 m | 新硬件和新现场必须测量并核验，不将历史偏置直接当作当前标定 |

总纲领的公开匿名副本见 [data/collaboration/project_brief.md](data/collaboration/project_brief.md)。晚期专项修订和参考策略差异见[协作记录](report/llm_collaboration.md)。

## 2 PC地面站启动架构与配置

### 2.1 启动与访问

先完成[源码准备](#6-第一步-恢复完整源码并核对文件)及 Python/NumPy 环境配置。新目录下地面站位于 **`out/workspace_01/source_code/rid_receiver/ground_station/`**。从仓库根目录执行：

```powershell
.\.venv\Scripts\python.exe -X utf8 -B -u .\out\workspace_01\source_code\rid_receiver\ground_station\serve.py --port 18770
```

| 页面 | 地址与用途 |
| --- | --- |
| 首页 | `http://127.0.0.1:18770/#/home`，状态摘要与模式入口 |
| 态势地面站 | `http://127.0.0.1:18770/#/monitor`，站点、目标、轨迹及交汇 |
| 信源检测 | `http://127.0.0.1:18770/#/signals`，接收信道、信源和处理链 |

工作区内 `start.bat`、`start_openwifi.bat` 也可启动同一地面站，需确认其选用的解释器可导入 NumPy。已有服务时直接访问，不重复启动；前台服务按 Ctrl+C 结束，关闭终端也会终止该前台实例。后台实例应按实际命令行和端口核对，不依赖历史 PID；页面缓存未更新时按 Ctrl+F5。

前端为本地保存的 HTML/CSS/JavaScript ES modules、Leaflet 与字体，**正常启动无需 npm、Node、Vite 或 Flask**。后端使用 Python 标准库 `ThreadingHTTPServer` 提供静态文件与同源 `/api/*`。必须经 HTTP 访问，不能直接双击 `index.html`；当前主前端入口为 `workspace.js`，旧 `app.js` 是兼容文件。

板端已配置 systemd 自启动；PC 网页服务仍需在电脑上单独运行。电脑仅监听 `127.0.0.1:18770`，未提供现成的公网服务模式。

### 2.2 实机接入与配置位置

以下路径均相对于 `out/workspace_01/source_code/`；更换工作区时整体替换该前缀。

| 路径 | 职责与核对要点 |
| --- | --- |
| `rid_receiver/ground_station/serve.py` | PC 服务入口、API 与板端轮询协调 |
| `rid_receiver/ground_station/workspace.js` | 页面壳、地图、信源、测向及记录入口 |
| `rid_receiver/` | 接收观测、RID/协议解析和识别相关模块 |
| `zynq7045_ad9361_rid_aoa/linux_doa/` | IQ 采样、同帧关联、参考与板端单站 DOA |
| `rid_receiver/ground_station/runtime/doa_config.json` | 两站 IQ URL、共享锚点、位置、朝向、阵距及实际参考路径；修改后核对生效配置 |
| `rid_receiver/ground_station/runtime/channel_scan.json` | 扫描范围、固定信道与驻留时间；实际频点看 `/api/channel-scan` 确认 |
| `rid_receiver/ground_station/runtime/receiver_config.json` | 持久接收站选择；保存选择不等于已获板端角色确认 |
| `rid_receiver/ground_station/runtime/` 的参考 JSON | 默认参考及按记录另存的 A/B profile；以 `doa_config.json` 当前引用为准，文件存在不代表当前适用 |
| `rid_receiver/ground_station/records/` | 历史 JSON 回放；浏览器导出位置服从下载设置，不能把内存缓冲当长期归档 |

随包基准接入地址如下，移植时按实际网段修改配置：

| 站点 | 监测与接收角色接口 | 本机双 RX IQ 与 DOA 接口 |
| --- | --- | --- |
| A | `http://169.254.92.202:18771` | `http://169.254.92.202:18788` |
| B | `http://192.168.20.2:18771` | `http://192.168.20.2:18788` |

监测地址通常由布站配置中的 IQ 主机地址推导到 18771。需要单独覆盖 A 监测地址时，可在启动命令添加 `--board-url 'http://169.254.92.202:18771'`；**只改此参数不会同时更新两站 IQ 地址**。两站识别配置和配对信息须与同一批运行覆盖包一致。

### 2.3 处理链与显示语义

- **新鲜有效 RID 位置：**绿色目标和 RID 广播轨迹，不占用 AOA 队列。
- **无有效 RID 位置且有识别依据：**调度本机同源 IQ，满足双站有效性检查后显示黄色 AOA 目标及估计轨迹；普通 Wi-Fi 或没有 RID 本身不能直接判为无人机。
- **依据或位置不足：**保留身份、观测与等待状态，不补造坐标。接收角色切换要下发并确认；列表站点筛选只改变显示。

PC 后台负责确认角色、同步切频、轮询与续租、B→A 观测原样转发、A 站结果汇总、双站检查和几何交汇。地图须区分广播位置、AOA 估计、方向候选与历史回放；过期、异帧、跨频率或配置失配的结果不组成有效交点。

信源检测页的“暂停列表”冻结当前浏览器快照和显示时间，后台采集、识别、测向继续运行；暂停时停止该页列表请求，恢复只读取最新有界窗口，不排队补播。暂停不是长期录制，见[暂停与恢复验证记录](data/collaboration/h88_record.md)。

在线底图及地点搜索依赖网络，离线网格可以继续展示有效的局部米制坐标与目标。底图失败不代表 RID/AOA 断流；电脑位置、站点坐标和无人机位置是不同数据来源，不相互替代。

### 2.4 启动后的快速检查与回放

```powershell
Invoke-RestMethod 'http://127.0.0.1:18770/api/health'
Invoke-RestMethod 'http://127.0.0.1:18770/api/receivers'
Invoke-RestMethod 'http://127.0.0.1:18770/api/pipeline'
```

`health.available=true` 只说明 PC 服务可用。实机还要核对接收分工 `confirmed`、选站 `connected/receiving`、IQ 窗口和结果计数是否更新；A 为测向待命时，`standbyReady=true` 可以是正常状态，不能仅凭其完整解码接口 `connected=false` 判定板卡离线。

未接板时，真实模式应等待连接，不生成虚构目标。可以选择历史双站观测记录，检查播放、暂停、进度拖动、单站质量和双站几何；切回真实模式后，历史数据不得继续冒充当前观测。保留“历史”“临时参考”“未校准”等标记。自动 HTTP 检查不等于浏览器全部按钮已点击验收，现场操作另行记录。

## 3 A/B平台分工与资源利用率

本节依据总纲领第 6 节整理。**资源快照属于 2026 年 11 月 3 日对应负载的历史实测，本次 README 更新没有重新采集板端 CPU，也没有重新综合 FPGA。**

### 3.1 功能实际执行位置

| 功能 | 执行位置 |
| --- | --- |
| 接收基带、站内双 RX 同步采样、IQ 缓存及 DMA | A/B FPGA；A 主要测向采样，B 另承担完整 OFDM 与已集成 DSSS 接收 |
| 802.11/可见 IPv4/UDP 字段、载荷结构提取、RID 解析与帧缓冲 | B 站 Linux CPU |
| 信源识别、候选证据评分、RID/AOA 分流、导入抓包解析 | A 站 Linux CPU |
| 实际切频、读回确认和 IQ 会话管理 | A/B Linux CPU 控制 AD9361 |
| LTF 搜索、同帧校验、跨 RX 相位、参考修正与单站角度 | A/B 各自 Linux CPU |
| 同频调度、目标轮询、IQ 租约、B→A 原样转发、双站检查与交汇 | PC CPU |
| 地图、目标与轨迹、信源证据及交互 | PC 浏览器 |

A 的 `direction_only` 表示未重复开启完整帧解码，不表示 A 未执行识别。A/B 的 `airspace-recognition.service` 分别处理识别与观测导出，PC 实时使用 `BoardRecognitionPipeline`；A 识别服务不可用时不静默回退到 PC 评分。停止 PC 后板端仍留在最后频点，但当前接线下 B→A 转发、同步轮扫与目标调度不再完整进行；证据超时和租约到期后允许等待新任务。

### 3.2 A站六项候选评分

| 特征 | 加分 | 实际门限或限制 |
| --- | ---: | --- |
| SSID 关键词 | 30 | drone/fpv/uav/tello 等，保留 UFO 线索；属于弱证据 |
| 持续大帧 | 20 | 至少 20 个长度 ≥700 字节的非重传数据帧，跨度 ≥1 秒 |
| 可解析 UDP | 15 | 至少 10 个可解析的非重传明文 UDP 帧 |
| 集中接收端 | 10 | 至少 20 个大帧集中在 1～2 个已知单播接收端；未知或广播地址不冒充已知地址 |
| RTP/MPEG-TS 结构 | 55 | 同一 UDP 流的连续 RTP 视频型特征，或多包 MPEG-TS 同步结构 |
| 历史私有 UDP 分片布局 | 55 | 多包匹配固定布局，至少 4 包、2 个序号，并满足同流与方向约束 |

统计窗为最近 **10 秒、最多 1200 条**有效观测；重复哈希、重传不凑数量，不同 UDP 流不混计序号，会话改变清除旧证据。当前明文协议字段支持 IPv4/UDP，不宣称 IPv6 已同等解析；加密载荷不据此加明文或媒体结构分。

展示分上限 **75**，保留原始合计与逐项依据；总分 **≥50** 为图传候选。SSID 单独命中为 30 分弱线索，普通大 UDP 流的 20+15+10=45 分不足以单独证明无人机。分数不是确认概率。真实历史抓包在 A 回放命中私有分片 162 包、111 个序号，加 55 分；RTP/TS 的构造报文验证与空口实收分开记录。详见[A站评分与部署验收](data/collaboration/h89_record.md)。

### 3.3 FPGA静态资源占用

两站器件为 `xc7z045fbg676-1`。下表来自布局布线后的基准报告：A 为 2026-10-27 构建，B 为 2026-11-02 集成 DSSS 构建。识别与 DOA 的 Linux 计算迁移不自动改变这些硬件容量指标。

| 资源 | A站已用／总量 | A占用率 | B站已用／总量 | B占用率 |
| --- | ---: | ---: | ---: | ---: |
| LUT | 40,487／218,600 | 18.52% | 43,138／218,600 | 19.73% |
| FF | 54,571／437,200 | 12.48% | 57,162／437,200 | 13.07% |
| Slice | 17,104／54,650 | 31.30% | 18,167／54,650 | 33.24% |
| BRAM 36 Kb Tile 当量 | 161／545 | 29.54% | 163／545 | 29.91% |
| DSP48E1 | 154／900 | 17.11% | 192／900 | 21.33% |
| IOB | 58／250 | 23.20% | 58／250 | 23.20% |
| BUFGCTRL | 5／32 | 15.63% | 5／32 | 15.63% |
| MMCM | 1／8 | 12.50% | 1／8 | 12.50% |

这是**资源容量占用**，不是 FPGA 实时活动率、功耗或 CPU 利用率，不能相加生成单一“FPGA 总使用率”。基准曾核对启动文件对应关系，未据此宣称完成活动配置全量读回。原始数值见[A资源报告](build/reference/baseline/a_ofdm_20261027/impl_utilization.rpt)与[B资源报告](build/reference/baseline/b_ofdm_dsss_20261102/impl_utilization.rpt)；本次目录迁移后的 A/B 校验及此前全量重建范围见[验证记录](data/release_validation.json)。

### 3.4 Linux CPU与内存实测

采样时间为北京时间 **2026-11-03 04:19:52.080918～04:20:28.250144**，固定信道 1、2412 MHz，两站运行新增识别/观测导出服务；共 25 次资源快照，按各区间时长加权，代表时长两站均约 37.1 秒。

| 指标 | A站 | B站 |
| --- | ---: | ---: |
| CPU 平均，两核合计归一化 | **27.83%** | **57.20%** |
| 区间 CPU 均值范围 | 20.54%～36.73% | 52.12%～65.07% |
| 最后一次 CPU | 27.00% | 55.63% |
| 最后一次内存使用率 | 18.82% | 27.26% |
| 最后一次负载均值，1／5／15分钟 | 0.69／0.87／0.88 | 1.28／1.49／1.51 |
| 不同计数样本 | 25 | 25 |

CPU 来自 `/proc/stat`，两核全忙合计为 100%，不将 idle/iowait 计作忙碌；表中范围是区间均值，不是瞬时峰值。内存按 `MemTotal-MemAvailable` 计算。该快照不代表满带宽或全部机型性能上限，也不能拿迁移前不同负载的低 CPU 直接比较算法效率。

本次快照未新建标定；固定信道 1 的负载统计不表示可将 2437 MHz 参考跨频率用于绝对测角。详细条件和数据见[A站部署记录](data/collaboration/h89_record.md)。

### 3.5 IQ常驻与采样占空比的对照

以下是**识别迁移前的另一组对照**，先约 45 秒双频轮扫，再固定信道 6 约 35 秒，结束后恢复扫描。不同于上一节固定信道 1 的负载，不能合并为同一均值。

| 对照状态 | A CPU均值 | B CPU均值 | A新增IQ／有效DOA | B新增IQ／有效DOA |
| --- | ---: | ---: | ---: | ---: |
| 双频轮扫，约45秒 | 5.57% | 35.51% | 5／5 | 4／4 |
| 固定信道6目标采样，约35秒 | 24.59% | 54.23% | 35／35 | 35／35 |

A 在轮扫 39 次快照中，`waiting_target` 为 28 次、`capturing` 为 6 次、`tuning` 为 5 次；固定信道的 31 次均为 `capturing`，两站窗口和有效 DOA 持续增加，未记录 IQ 错误。较低轮扫 CPU 主要来自目标采样占空比下降，不能推导为算法算力需求下降。

`airspace-iq.service` 的 `--seconds 0` 表示进程与接口常驻，仍按有效目标租约采集短窗口。核验长期运行应同时看服务、任务租约、`candidateWindows`/`doaAccepted` 增量与结果新鲜度；仅看 active 或 CPU 低都不足以证明链路运行。这不是 Linux CPU 持续处理完整 20 MSPS IQ 流的性能验收。

## 4 仓库目录及源码交付方式

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

## 5 复现前提

- Windows 下使用 PowerShell 与 Python；参考离线验证环境为 CPython 3.8.10、NumPy 1.22.1。已有可用 Python/NumPy 环境可以先运行检查，兼容结果以实际输出为准。
- FPGA 仿真和构建使用 Vivado 2022.2、XC7Z045 器件支持及工程所需 IP 授权。部分接收链 IP 需要有效授权，许可证不在仓库中。
- 内核与驱动构建使用 Ubuntu 22.04 或 WSL、GNU Make 和 ARM 交叉编译器；还需 flex、bison、bc、OpenSSL/ELF 开发库、kmod，完整内核镜像打包另需 `u-boot-tools`。
- 浏览器用于地面站显示；在线地图是可选联网资源，离线网格与算法回放不依赖地图服务。
- 实机需要兼容硬件及匹配的 ARM Linux 根文件系统。仓库提供的启动文件不是整张 SD 卡镜像，也不包含完整根文件系统。

所有命令均在**仓库根目录**执行。示例中的 Vivado 路径应替换为本机实际安装位置。每次验证选新的输出目录，保留前次证据；准备脚本拒绝覆盖已有工作目录。

## 6 第一步 恢复完整源码并核对文件

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

## 7 第二步 一轮快速离线验收

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

## 8 第三步 FPGA 从源码构建

对第一次完整构建建议另准备 `out/workspace_fpga_01`，避免混用已有生成状态，然后运行：

```powershell
python .\build\prepare_sources.py --out .\out\workspace_fpga_01
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\reproduce.ps1 `
  -Workspace .\out\workspace_fpga_01 -Mode fpga -Station both -FpgaPhase bitstream `
  -VivadoBin 'C:\tools\vivado\2022.2\bin' -OutputRoot .\out\fpga_01
```

阶段可选 `validate`、`synth`、`impl`、`bitstream`；A/B 顺序执行。A 工程入口为工作区的 `source_code/zynq7045_ad9361_rid_aoa/dma_project/dma_project.xpr`，B 为同根下 `dsss_receiver/build/integrated_r2/dsss_b.xpr`。

验收不仅看工具是否打开。逐站检查 `ip_status.rpt`、`impl_timing.rpt`、`impl_utilization.rpt`、`impl_drc.rpt`、`check_timing.rpt` 及 `timing_gate.txt`。时序与 DRC 门控通过才生成 `system_top.bit` 和 `hardware.xsa`；相关 CDC 与外部 I/O 约束缺口仍需审查。历史结果在 `data/reference_results/`，新结果保存在 `out/fpga_01/`，不覆盖历史结论。

## 9 第四步 Linux 内核与驱动

在已准备好交叉工具链的 WSL 环境下，从根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build\reproduce.ps1 `
  -Workspace .\out\workspace_01 -Mode kernel -WslDistro Ubuntu-22.04 `
  -OutputRoot .\out\kernel_01
```

内核工具在 WSL 新工作目录解压源码、应用补丁、恢复配置并编译外部接收模块和网络/DMA 模块，核对目标 `5.15.0-175919-g427c94e8faa5-openwifi-rx1` 的 ABI。完整镜像步骤、C 参考校验和设备树构建见 [build/README.md](build/README.md)。内核 CRC、版本和符号校验不代替上电启动。

## 10 第五步 启动文件和板端部署

准备源码后，可从根目录生成两站当前业务覆盖包：

```powershell
.\.venv\Scripts\python.exe -B .\board\prepare_runtime.py `
  --workspace .\out\workspace_01 --out .\out\runtime_01
```

可选 `--modules out/kernel_01/modules` 使用新编模块。生成过程检查 ABI、逐文件内容与配对配置，不向板卡写文件；每次生成独立配对密钥，不能混用不同批次的两站配置。

BOOT 打包、设备树及实际部署见 [board/README.md](board/README.md)。同一 XC7Z045 芯片不代表不同硬件能直接使用已有 BOOT；DDR、MIO、引脚、电平、时钟、RF、设备树和启动组件必须匹配。仓库 FSBL/U-Boot ELF 是基准参考；硬件变化后需要相应目标组件。

实机验收依次检查 Linux 与网络、RF、帧接收、双 RX IQ、身份与参考、单站角度和同帧交汇；独立保存真值来源。没有有效参考时保持空角度或待校准，不将历史偏置或网页出数当精度通过。

## 11 结果记录与贡献范围

既有离线验证包括 34 项算法回放/控制输入、46 项 HTTP/资源检查、DSSS AXI 示例、A/B 重建、内核/驱动与启动文件核验；它们是对应原版本的历史证据。当前 GitHub 目录准备后的实测范围另见 [data/release_validation.json](data/release_validation.json)，不会将未重新执行的全量 FPGA 构建或现场实验记为本轮完成。

- [技能包](skill/README.md)：提示词工程流、工作流、案例模板、校验脚本与踩坑指南。
- [大模型协作记录](report/llm_collaboration.md)：提示词、回答、纠错、人机技术分工及历史来源。
- [数据说明](data/README.md)：公开副本、原始采样与构造输入的区别。
- [第三方说明](third_party_notices.md)：版本及许可的保存方式。

设计报告可另行放入 `report/`；本次未将未经重新检查的二进制文档自动作为对外报告上传。公开文件只使用技术角色，不记录参赛单位或人员身份；来源副本匿名处理后重新计算哈希。
