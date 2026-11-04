# 单站解码与双站测向接续提示

继续“空域知微——无人机侦测定位系统”。优先读同时间的《单站解码分工与空间清理报告》、`tmp/receiver_role_20261102_1429/final_acceptance.json`，再读14:18非RID图传报告。

1. 当前默认B站完整检测／解码／RID与特征解析，A站测向待命。网页信源页可选择A/B并实际控制板端。必须保留两站独立双RX IQ与本地目标帧关联，不可用B角度冒充A角度。
2. 主机角色配置为 `rid_receiver/ground_station/runtime/receiver_config.json`，板端为 `/root/openwifi_rx1/rid_service/receiver_role.json`。切换使用 `POST /api/receiver/config`，带 `selectedStation` 和当前 `revision`，不是列表筛选。不要忽略硬件确认、旧会话过滤、部分失败、回放隔离。
3. 板端完整解码服务可用 `sh /root/openwifi_rx1/rid_service/start_monitor_role.sh A` 或 `B` 恢复。该脚本保留已有角色文件，不管理IQ服务，也不重置RF会话。
4. A的桌面登录服务本轮临时屏蔽，已退出；重启会恢复。手动恢复用 `systemctl unmask --runtime lightdm.service` 后 `systemctl start lightdm.service`。不要将约67%到约5%的总CPU下降全部解释为解码迁移；仅迁移时约52%。
5. 仍待实际6.0厘米／2.8米摆位和同频新会话标定。当前信道1用于非RID无人机图传，信道6用于之前ESP32 RID；用户开启无人机前先准备接收端，再弹对话框。图传采完立即通知关机。
6. 本轮保留了双站原IQ会话，其约15:17的受控时长到期后需要重新准备；完整解码服务仍可运行。重建IQ会话后不要套用旧相位标定。
7. 已删除完成写卡后的 `rootfs_B.ext4` 和 `boot_B.fat32` 本地镜像，实际释放约6.66GB。源码、启动文件、manifest、定制脚本与真实数据保留。未来烧卡先重建镜像；不要将已清理路径当成仍存在。
8. 浏览器与原生UI宿主不可用，不要凭前端单元测试声称已完成整页目视验收。维持现有首页、地图与布站设计，只处理实际发现的问题。

下一阶段优先完成真实布站、同信道参考和左右独立位置验收，再提高非RID有效载荷帧配对率，遵守NULL帧不能凑成同一次发射的限制。按 `月.日_时.分标题.md` 格式继续保存提示与报告。
