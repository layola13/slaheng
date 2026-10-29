# kb —— 衡引擎知识底座 v0.1

条目格式见 [SCHEMA.md](SCHEMA.md)（依仓根 INTERFACE.md 契约）。 
纪律：**数据正确性优先于数量，宁可少收、不可错收**；不确定的条目标 `assumed` 并写明疑点。

## 内容与计数（校验器实测，见 validation_report.txt）

| 文件 | 内容 | 条数 |
|---|---|---|
| data/species_junior.json | 初中物种（单质/氧化物/酸/碱/盐/常见有机物等） | 71 |
| data/equations_junior.json | 初中核心方程式（化合/分解/置换/复分解/光合/呼吸/金属活动性等） | 53 |
| data/species_senior.json | 高中增补物种（含离子 23 种） | 68 |
| data/equations_senior.json | 高中方程式（氧化还原/离子方程式/元素化合物/有机基础） | 56 |
| data/atomic_masses.json | 常用元素相对原子质量（课本取整 + IUPAC 精确值双列） | 30 |
| **合计** | | **278** |

校验结论：**ALL PASS** —— 全部 species 的 composition 与化学式独立解析结果一致；
全部 109 条方程式引用完整且元素守恒、电荷守恒；id 全局唯一；provenance 格式合法。

复现：`python3 tools/validate_kb.py`（退出码 0；报告写入 validation_report.txt）。

## 存疑与注记清单（诚实账）

| 条目 | 处置 |
|---|---|
| 物种 H2SO3、方程式 SO2+H2O→H2SO3（eq-jr-013） | 标 `assumed`：式子本身配平无误，但初中课本对酸雨成因多为文字叙述，是否明列此式各版本不一 |
| 单质磷以 P 计量（formula1:P@0） | 课本口径；白磷实际分子 P4 已在高中集单列（formula1:P4@0），物种注记互相指明 |
| Fe3O4 中铁的价态 | 注记明示 +2/+3 混合价态，valences 记 [2,3] |
| 氨水以 NH3·H2O 建模 | 氨水为混合物，条目身份为一水合氨式，注记说明 |
| 蔗糖水解（eq-sr-052）右端 2×C6H12O6 | 葡萄糖与果糖互为同分异构体、分子式相同，以系数 2 表示并在 note 中写明 |
| 偏铝酸钠表述 | 新旧教材表述不一（NaAlO2 / Na[Al(OH)4]），本集回避该物种、统一用离子 Al(OH)4− 建模 |
| 原子量精确列个别元素（如 Pb 207.2） | 为 IUPAC 区间值的代表值，课本计算以取整列为准 |
