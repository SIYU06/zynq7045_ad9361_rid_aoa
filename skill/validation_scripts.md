# 校验脚本

本类技能提供可运行的只读检查工具 [scripts/verify.py](scripts/verify.py)，适用于黄金 JSON 结果对照、Vivado 时序资源提取、证据文件完整性和 Markdown 交付检查。使用 Python 3.8 或更新版本的标准库，无需安装第三方依赖。

工具只读取指定输入；仅在显式传入 `--output` 时创建新的结果 JSON，不覆盖已有文件。工具不连接板卡，不修改工程、参考或服务，也不进行上传。历史案例中的验证由当时工程脚本完成；本工具是此次技能包整理新增的交付物。

## 快速入口

下面的路径以同时包含 `skill/` 与 `report/` 的目录为当前目录。`data/`、`build/` 等输入应替换为自己的实际文件。输出目录需事先存在，结果文件不能已经存在。

```sh
python skill/scripts/verify.py --help
python skill/scripts/verify.py docs skill report
python skill/scripts/test_verify.py
```

| 子命令 | 输入 | 输出 | 通过条件 |
| --- | --- | --- | --- |
| `compare` | 参照和候选 JSON、绝对与相对容差、可选精确排除字段 | 差异数量、字段位置、比较口径 | 字段结构、列表顺序和有效数值在声明条件下一致 |
| `vivado` | 设计级 timing summary，可选 utilization report | 建立、保持、脉宽指标及 LUT/FF/BRAM/DSP 等静态资源 | 支持格式成功解析，报告约束内时序满足且资源不超容量 |
| `manifest` | 证据清单及明确的根目录 | 每个文件是否存在、哈希与可选字节数是否一致 | 所列文件均匹配，清单路径合法且无重复 |
| `docs` | 一个或多个 Markdown 文件或目录 | 本地链接、标题锚点、代码围栏及匿名信息候选 | 未发现上述结构问题或敏感候选；仍需人工复核 |

统一返回码：`0` 为本项检查通过，`1` 为发现不一致或检查失败，`2` 为输入、格式或输出写入错误。结果不包含待比较的原始字段值；对外分享结果仍需检查路径与字段名。

## 1 黄金参考 JSON 比较

**适用场景：** 算法重构、板端迁移、协议解析改写后，对照修改前实现。来源经验见[板端 DOA 迁移案例](../report/llm_collaboration.md#411-doa-迁移使用黄金参考和实时计数双重证明)。

```sh
python skill/scripts/verify.py compare data/golden.json data/candidate.json --abs-tol 1e-12 --rel-tol 0
python skill/scripts/verify.py compare data/golden.json data/candidate.json --exclude /checkedAt --output data/comparison_result.json
```

**使用方法：**

1. 独立保存修改前参考及修改后结果，注明来源和样本数量。避免用同一新函数同时生成两份输入。
2. 使两份输入采用相同字段与列表排序；列表按位置比较，不自动猜测样本身份或重新配对。
3. 根据算法和数值环境预先说明容差。默认绝对与相对容差均为零；非零容差使用 `math.isclose`，满足任一有效误差尺度即可。
4. 只对明确不属于算法输出的元数据使用 `--exclude`。参数采用精确 JSON Pointer，例如 `/checkedAt`、`/rows/0/elapsed`；`~1` 表示字段中的斜杠，`~0` 表示波浪号。不支持通配符，不存在的排除路径报错。
5. 保存比较结果，并分别说明新实收、历史回放与构造输入的覆盖情况。

**检查细节：** 缺失字段、类型变化、列表长度变化和空值变化均不视为数值容差。布尔值与整数严格区分，`true` 不等于 `1`。拒绝重复 JSON 键、NaN、Infinity 和无效容差。报告最多显示前 100 个差异位置，`difference_count` 保留发现的全部差异数量。

**失效条件：** 两份结果来自同一有误实现、样本覆盖不足、样本排列不同或排除了关键字段时，即使通过也不能证明算法正确。该工具检查输出等价，不证明物理精度、实时吞吐或身份真实性。

## 2 Vivado 时序与资源提取

**适用场景：** 完成一次综合实现后核对设计级结果，避免把局部路径或单核 OOC 资源当整机结果。来源经验见[时序与 CDC 案例](../report/llm_collaboration.md#44-根据真实-cdc-协议修正时序分析)。

```sh
python skill/scripts/verify.py vivado build/impl_timing_summary.rpt --utilization build/impl_utilization.rpt --output data/vivado_result.json
```

支持当前项目 Vivado 2022.2 文本报告中的设计级 12 列 timing summary，以及包含 `Slice LUTs`、`Slice Registers`、`Block RAM Tile`、`DSPs` 等行的 utilization 表。其他版本或器件族的表格可能不同；缺少必需表或必需资源行时返回输入错误，不能默默填零。

提取 WNS/TNS、WHS/THS、WPWS/TPWS 及相应违例端点。提供 utilization 时再提取已用数量、可用容量与报告占用率。资源属于静态容量，不是实时运算活动率。工具只输出指标与检查范围，不复制报告中的主机名等环境页眉。

**通过范围：** `ok=true` 表示报告里已约束路径的建立、保持、脉宽条件满足，已提取的资源未超容量。`board_signoff` 固定为 `false`，因为该工具没有验证 PCB 延迟、CDC 协议或约束是否合理。`external_io_delay_gaps` 保留未约束外部输入输出的数量；没有提供相关检查段时为 `null`，不能当作零。

**失效条件：** 报告与部署版本不符、约束放宽、漏约束或并非期望的实现阶段时，正 WNS 不能作为签核结论。工具不独立证明设计已经 Fully Routed，不验证 false path、例外覆盖或时钟架构，需配合 [Skill 02](prompt_workflows.md#skill-02-时序与-cdc-定点排查) 人工审查。

## 3 证据清单与文件哈希

**适用场景：** 冻结实验、归档原始 IQ 或报告、复制交付包后，验证内容未变。清单格式见[证据清单模板](case_templates.md#黄金比较与证据清单模板)。

```sh
python skill/scripts/verify.py manifest data/manifest.json --root . --output data/manifest_check.json
```

清单必须使用 `schema=evidence-manifest-v1`，`files` 至少有一项。每项包含相对 POSIX 路径 `path`、64 位十六进制 `sha256`，可选非负整数字节数 `size`。根目录通过 `--root` 明确指定，不自动猜测为清单所在目录。

清单应在可信采集或冻结时生成，并与被检查副本分开维护。检查时流式读取文件，禁止绝对路径、越出根目录的路径、重复文件和无效哈希；符号链接解析后越界也拒绝。

**失效条件：** 若参照清单与被改文件同时重建，哈希一致不能证明未被篡改；漏列文件也不在检查范围内。哈希证明字节对应关系，不证明来源真实性、测量准确或构建可复现。

## 4 Markdown 结构与匿名候选检查

**适用场景：** 拆分文档、改名或准备 GitHub 目录后，检查引用关系和发布内容。

```sh
python skill/scripts/verify.py docs skill report --output data/doc_check.json
```

脚本递归检查指定目录的 `.md` 文件，验证实际链接及 GitHub 风格标题锚点，忽略代码围栏中的示例链接，检查未闭合围栏。外部 HTTP 链接不联网检查；外部资源不可访问不影响本地检查结果。

匿名候选覆盖邮箱、手机号形式、设备 MAC、本机用户目录及机构名称形式。只报告文件名、行号与候选类别，不回显候选原文。对真实姓名、地点暗示、地图截图、广播身份和所有机构缩写没有完整识别能力，仍需人工通读；`ok=true` 不等于完整的隐私保证。

**失效条件：** 动态 HTML 锚点、复杂 Markdown 扩展、引用式链接及图片像素内容不在自动检查范围内。将文档复制到新仓库后应重新运行，尤其核对原始证据目录的路径映射。

## 5 自测和已验证效果

[scripts/test_verify.py](scripts/test_verify.py) 使用临时目录建立正反例，覆盖数值容差、缺字段、类型与长度变化、非法数值、清单错哈希和路径越界、损坏链接和匿名候选，以及时序通过与负余量。运行时不连接设备。

本次还使用项目实际 `impl_timing_summary.rpt` 和 `impl_utilization.rpt` 进行只读提取，核对 WNS `+0.559 ns`、TNS `0`、LUT `40487`、FF `54571`、BRAM `161`、DSP `154`，并保留外部输入/输出延迟缺口 `15/13`。完整 `skill/`、`report/` 的本地链接与匿名候选检查实际执行，结果见本目录[验证结果](validation_results.json)。

这些测试证明工具在已测输入上的行为。尚未测试所有 Vivado 版本、所有 Markdown 方言或所有新项目数据格式；新增适配应先补反例再更新能力说明。

返回[技能包入口](README.md)，或查看[踩坑指南](pitfalls.md)以解释检查通过仍可能存在的工程风险。
