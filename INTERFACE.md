# INTERFACE.md —— 衡 v0.1 六线共享契约（主会话定，改动须经主会话）

## 分层与所有权
- `found/` 精确数与量纲：bigint、rational、dimension/quantity。
- `species/` 物种层：化学式/SMILES 子集 → 分子图 → 规范化 → species_id。
- `check/` C1 检验：配平（元素/电荷）、化合价、相对分子质量、反应类型判定。
- `kb/` 知识底座：课程物种与方程式数据（内容寻址、带来源标签）。
- `grade/` 判分运行时：题目 = 模型 + 断言集 + 评分要点 → 判定 + 溯源报告。
- `lang/` L0/L1 语言面：学生表层语法 → 内核模型；教学级报错话术。

## 跨线数据契约（v0.1，JSON 为线间交换格式）
- **SpeciesRecord**：`{ "id": string, "formula": string, "composition": {元素符号: 计数}, "charge": int }`。`id` 由 species 线定义：`canon` 版本前缀 + 规范哈希，如 `"canon1:<hex>"`；在 canon 就绪前，formula 级 id 用 `"formula1:<FORMULA>@<charge>"` 占位，格式须在本文件备案后替换。
- **EquationRecord**：`{ "lhs": [[species_id 或 formula, 系数], ...], "rhs": [...], "arrow": "->" | "<=>" }`。
- **Quantity**：`{ "value": rational 字符串 "p/q" 或十进制字符串, "unit": string }`；量纲以 7 元整数向量表示（kg, m, s, A, K, mol, cd 的指数），found 线定义单位表。
- **Assertion（v0.1 三种）**：`{"kind":"balanced","equation":EquationRecord}`；`{"kind":"value_eq","expr":string,"expect":Quantity,"tol":string}`；`{"kind":"species_id_eq","a":string,"b":string}`（两式同物种）。
- **VerdictReport**：`{ "problem_id": string, "results": [ { "assertion_index": int, "pass": bool, "detail": string, "provenance": [label,...] } ], "all_pass": bool }`。label ∈ `derived` / `measured:<ref>` / `assumed` / `extern:<name>`。
- **KB 条目**：`{ "id": string, "kind": "species"|"equation"|"fact", "payload": {...}, "provenance": label, "curriculum": "初中"|"高中", "topic": string }`。

## 语义纪律
- 一切判定结论必须携带 provenance；数值不用浮点做判定（显示可转十进制近似，判定走 rational）。
- 错误一律响亮：不静默兜底、不默认 0、不跳过。
- 规范身份带版本（canon 版本进 id 计算域）。
