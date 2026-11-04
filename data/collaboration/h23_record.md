# 任务：排查 Zynq-7045 以太网 PHY 复位信号 MIO8 从高电平变为低电平的问题

本轮只解决板载以太网无法识别 PHY 的问题，与 DOA 算法、OpenWiFi 接收链和地面站开发无关。不要修改其他项目配置，不要扩大任务范围。

**工程目录：**
`F:\2026fpga\zynq7045_ad9361_rid_aoa`

## 一、当前故障

开发板运行 Linux 5.15，网卡 eth0 无法识别 PHY，启动日志：

```text
[0.392782] gpio-914 (ethernet-phy-reset): hogged as output/high
[0.545352] libphy: Fixed MDIO Bus: probed
[0.553862] libphy: MACB_mii_bus: probed
[0.556572] mdio_bus e000b000.ethernet-ffffffff: MDIO device at address 7 is missing.
[0.563143] macb e000b000.ethernet eth0: Cadence GEM rev 0x00020118
[15.076626] macb e000b000.ethernet eth0: Could not attach PHY (-19)
```

## 二、已经确认的硬件和软件信息

1. 原理图中 Zynq PS_MIO8 连接 `PS_ETH_RESET#`，该信号连接以太网 PHY 复位网络。
2. RESET# 为低电平有效。
3. R109 为 20K，上拉至 VCCP1V8。
4. R121 为 20K/NC，属于可选下拉电阻位置。
5. 第二版 DTB 已经部署并实际启动，包含：

```dts
ethernet-phy-reset-hog {
    gpios = <0x08 0x00>;
    gpio-hog;
    line-name = "ethernet-phy-reset";
    output-high;
};
```

6. 内核启动日志明确显示：

```text
gpio-914 (ethernet-phy-reset): hogged as output/high
```

7. 当前 GPIO 调试信息却显示：

```text
gpio-914 ( |ethernet-phy-reset ) out lo
```

8. 当前 pinmux 信息：

```text
pin 8 (MIO8): e000a000.gpio
function gpio0
group gpio0_8_grp
```

说明 MIO8 已经配置为 GPIO 功能。

9. 当前 pinconf：

```text
input bias disabled, pin power source (1 selector),
slew rate (0), IO-standard (1)
```

10. 当前 `/etc/rc.local` 只有 `hostname -I` 和打印 IP 的代码，没有 GPIO 操作。

11. 当前没有发现运行中的 `devmem`、`gpioset`、GPIO 控制程序。

## 三、需要重点检查的内容

请直接检查本地工程，不要让我继续手动翻文件。

**重点一：查明 GPIO 为什么从高变低。**

全工程搜索：

- `ethernet-phy-reset`
- `PS_ETH_RESET`
- `MIO8`
- `gpio-914`
- `0xE000A000`
- Zynq GPIO 控制寄存器操作
- `devmem`、`/dev/mem`
- `gpio_set_value`、`gpiod_set_value`
- `XGpioPs_WritePin`
- 其他可能改变 GPIO 输出状态的初始化代码。

检查所有启动脚本、systemd 服务、rc.local、内核驱动、设备树和 BSP 初始化代码。

特别关注 GPIO Hog 执行后，是否有其他代码重新配置 GPIO 数据寄存器、方向寄存器或输出使能寄存器。

**重点二：检查设备树是否存在配置冲突。**

检查：

- GPIO Hog 是否放置正确。
- MIO8 pinctrl 配置是否正确。
- PHY 节点是否存在重复的复位 GPIO 配置。
- 是否存在其他节点占用 GPIO8。
- 是否存在启动阶段不同配置覆盖的问题。

**重点三：检查 PHY 无法识别的原因。**

结合现有设备树和原理图，核对：

- PHY 地址是否确实为 7。
- MDIO/MDC 配置是否正确。
- PHY RESETn 的控制逻辑。
- MACB 与 PHY 的连接关系。
- PHY 供电和参考时钟相关设计。

不要因为 MDIO 地址 7 找不到设备，就直接认定 PHY 地址错误。

## 四、本轮执行限制

1. 本轮只读审查，不修改任何文件。
2. 不重新编译内核、DTB 或 BOOT.BIN。
3. 不烧录 SD 卡，不重启开发板。
4. 不修改 GPIO 实际电平。
5. 不改动 FPGA Bitstream、RTL、XDC。
6. 不处理 DOA、OpenWiFi 和地面站。
7. 不增加复杂的防御性代码，不进行无关重构。
8. 严格控制 Token 消耗，优先使用本地搜索和针对性阅读，不要反复扫描无关目录。

## 五、最终要求

请给我一份简洁的审查报告：

1. 找到所有可能修改 MIO8/GPIO8 的代码，列出文件路径和具体行号。
2. 判断是否存在 GPIO Hog 与其他初始化代码冲突。
3. 解释启动时 output/high、运行时 out lo 的可能原因，并区分已证实与推测。
4. 找出最可能的故障点，按证据强弱排序。
5. 给出最小修改方案，但本轮不要执行修改。
6. 给出修改后的最短 UART 验证步骤。

**核心目标只有一个：查明为什么 MIO8 在 Linux 启动时被设置为高电平，之后却变成低电平，以及这是否是 PHY 无法识别的直接原因。**