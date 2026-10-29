# kb 条目 JSON 规范（v0.1，衡线 4/kb 定，依 INTERFACE.md「KB 条目」契约）

## 通用信封（每条必备）

```json
{ "id": "string", "kind": "species" | "equation" | "fact",
  "payload": { ... }, "provenance": "label",
  "curriculum": "初中" | "高中", "topic": "string" }
```

- `provenance` label ∈ `derived` / `measured:<ref>` / `assumed` / `extern:<name>`（INTERFACE.md）。
  本库约定：课本标准内容用 `measured:初中化学课本` / `measured:高中化学课本` /
  `measured:初中生物课本`；**拿不准的一律 `assumed` 且必须在 payload.note 写明疑点**，
  不许把不确定数据标成确定。
- `topic` 为教材章节级自由文本（如「金属与金属材料」「离子反应」）。
- 数据文件为 JSON 数组，一文件一集合，置于 `kb/data/`；文件内顺序无语义。

## species 条目

`payload`（SpeciesRecord 扩展，核心四字段与 INTERFACE.md 一致）：

```json
{ "name": "氢氧化钙", "formula": "Ca(OH)2",
  "composition": {"Ca": 1, "O": 2, "H": 2}, "charge": 0,
  "category": "碱", "valences": {"Ca": [2], "O": [-2], "H": [1]},
  "state_note": "白色固体，微溶于水", "note": "俗称熟石灰……" }
```

- `id` = `"formula1:<formula>@<charge>"`（INTERFACE.md 备案的 formula 级占位格式；
  species 线 canon 就绪后按其规范替换，替换须走主会话改契约）。
- `formula`：教材化学式；结晶水合物/氨水用中圆点分段，如 `CuSO4·5H2O`、`NH3·H2O`；
  支持括号与方括号分组下标。离子以裸骨架式 + `charge` 表示（如 formula `SO4`、charge −2）。
- `composition`：由 formula 唯一决定，必须与校验器的独立解析结果逐项相等（校验项 4）。
- `category` ∈ 单质 / 氧化物 / 过氧化物 / 酸 / 碱 / 盐 / 有机物 / 离子 / 其他自由注记。
- `valences`：元素符号 → 常见化合价数组（无把握可给 `{}`，但不得编造）。
- `state_note`：常温状态/颜色/溶解性等课本级注记；`note`：俗称、用途、存疑说明。

## equation 条目

`payload` 即 INTERFACE.md 的 EquationRecord 加教学字段：

```json
{ "lhs": [["formula1:Fe@0", 1], ["formula1:CuSO4@0", 1]],
  "rhs": [["formula1:FeSO4@0", 1], ["formula1:Cu@0", 1]],
  "arrow": "->", "name": "湿法炼铜", "conditions": "常温",
  "reaction_type": "置换反应", "note": "" }
```

- `id` 命名空间：`eq-jr-NNN`（初中）/ `eq-sr-NNN`（高中），序号仅作标识、无语义。
- 两侧每项为 `[species_id, 正整数系数]`；所引 species 必须在物种全集（初+高）中存在。
- 每条方程式必须同时通过**元素守恒**与**电荷守恒**验算（校验项 5）。
- `reaction_type`：化合/分解/置换/复分解，或如实标注「其他」（如有机物燃烧、
  还原反应不属四大基本类型者，不得硬套）。
- `conditions` 为自由文本（点燃/加热/催化剂等），结构化条件枚举候后续契约。

## fact 条目（原子量表）

```json
{ "symbol": "Cl", "name": "氯", "mass_textbook": 35.5, "mass_precise": 35.45 }
```

- `id` = `"mass:<symbol>"`。
- `mass_textbook`：人教版课本元素周期表的取整口径（初中相对原子质量计算用）；
  `mass_precise`：IUPAC 标准原子量。两列并存、来源在 provenance 中并列标明。
- 校验项 6：`|mass_textbook − mass_precise| ≤ 0.6`（取整自洽）。

## 校验

校验器为 SLA 实现（`kb/tools/validate_kb.sla`，零 Python）：构建
`sla build-exe kb/tools/validate_kb.sla -o kb/tools/validate_kb`，仓根运行 `kb/tools/validate_kb kb`
（退出码 0 = 全过），报告落 `kb/validation_report.txt`。
所用 JSON 解析器为 `kb/tools/json.sla`（对象/数组/字符串/数字/布尔/null + 转义，数字保精确十进制），
自带测试 `kb/tools/test_json.sla`；原 Python 校验器已删除，迁移经过记于仓根 `GAPS.md`。
