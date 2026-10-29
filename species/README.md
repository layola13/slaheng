# species/ —— 物种层（衡线 2/6）

草案 §7 P1 交付：化学式 / SMILES 子集 → 分子图 → 规范化 → `species_id`，
产出 INTERFACE.md 的 SpeciesRecord。本目录全部实现为 **SLA**（零 Python、
零脚本文件；运行命令即本文档所列 `sla` 命令本身）。

## 文件

| 文件 | 内容 |
|---|---|
| `species.sla` | 全部实现：元素表、化学式递归下降解析、SMILES 子集解析、芳香感知、WL+回溯规范化、FNV-1a-64、SpeciesRecord 构造 |
| `tests_species.sla` | 验收语料（20 条 @test，失败以 21xxx panic 码定位） |
| `demo.sla` | 演示 main（记录产出 + 等价性判定打印） |

## 运行（验收证据）

环境配方（本机实测；`SA_STD_DIR` 必须指向 sa_std 目录本身）：

```
export PATH=~/workspace/local-sa/zig17:~/workspace/local-sa/sci/zig-out/bin:~/workspace/local-sa/sa_plugin_sla/zig-out/bin:$PATH
export SA_PLUGIN_DEV=1 SA_STD_DIR=~/workspace/local-sa/sci/sa_std
cd ~/workspace/heng/species
sla check species.sla          # 语法/类型检查
sla test tests_species.sla     # 验收语料（默认 SAB 后端，见 GAPS 的后端口径）
sla build-exe demo.sla -o demo.bin && ./demo.bin
```

注：验收口径 = `sla test tests_species.sla`（默认 SAB 后端）单次全量
20/20。`sla build-exe` 的 LLVM AOT 峰值在本机（2 核 7.7G）不可行，
demo.sla 以 `sla check` 通过为静态口径、其调用面已被语料全覆盖
（详见 GAPS.md species 节）。

## 表层写法备案（与 species.sla 文件头同步）

- **化学式**：元素符号 + 计数、`()`/`[]` 分组与倍数；水合分隔 `·`（U+00B7；
  `•` U+2022 为别名）或 `.`+数字，段倍数在段首（`CuSO4·5H2O`）。顶层前导
  系数不收（系数属方程层，err 4）。
- **离子电荷后缀**（本线自定）：`^` + 可选倍数 + `+`/`-` 写在式尾：
  `SO4^2-`、`NH4^+`、`Fe^3+`。Unicode 上标不收（err 8）。
- **SMILES 子集**：有机子集 B C N O P S F Cl Br I + 芳香 b c n o p s；括号
  原子 `[同位素 符号 @/@@ H数 电荷]`（原子映射 `:n` 接受但不入身份）；
  键 `- = # : ~ / \`；分支 `()`；环闭合 1–9；`.` 断开组分。不支持一律
  响亮报错：`%nn` 环闭合（err 6）、通配 `*`、未加括号的 H（err 2/4）。
- **species_id**：图物种 `canon1:<16 位小写 hex>`，hex = FNV-1a-64(规范
  序列化)，序列化首字段即 `canon1`（版本在计算域内）。纯化学式物种用
  INTERFACE 既定占位 `formula1:<Hill 式>@<电荷>`——取 Hill 规范式而非
  输入原文（同组成同 id；原文回显口径会使异写法同物种得到不同占位 id）。
- **composition JSON**：键按原子序数升序（JSON 对象无序语义；规范式字符串
  由 `hill_formula` 单独提供）。
- **相对分子质量输入**：`FormulaInfo { counts[Z], charge }` 即 composition，
  check 线以原子量表点乘即得 Mr，本线不另算。

## 规范化（canon1）要点

- 芳香感知（有界）：原始键级上枚举 5–7 元环，π 规则（6 环 3 双键；5 环
  2 双键 + 环内双单键 O/S/N；7 环 3 双键 + 正电原子）判定后统一标芳香
  键级 9——Kekulé 写法无关性在此闭合（苯/吡啶/呋喃三组等价已验）。
- WL 细化（整数打包标签）+ 个体化-回溯取字典序最小序列化；手性 @/@@
  经书写邻序→规范邻序置换奇偶校正入序列化（丙氨酸对映体不同 id 已验）；
  键 `/ \` 立体按规范端点序校正。
- 上限：80 原子（err 7）；搜索叶上限 200000，命中退化为细化标签序
  （确定性、不保证同构不变，见 GAPS）。

## API 速览（字符串 ABI 纪律见 species.sla 文件头）

- `parse_formula(src: ptr) / parse_formula_view(sp, sn) -> Result<FormulaInfo, i32>`
- `formula_record_json(src: ptr) -> Result<String, i32>`
- `parse_smiles(src: ptr) / parse_smiles_view(sp, sn) -> Result<Graph, i32>`
- `species_id(g: &Graph) -> String`、`smiles_record_json(src: ptr)`
- `smiles_same_species(a: ptr, b: ptr) -> Result<bool, i32>`（species_id_eq 底层）
- `graph_composition(g) -> FormulaInfo`、`hill_formula(info) -> String`

错误码：1 空输入 / 2 未知元素 / 3 括号不配平 / 4 非法字符或计数位置 /
5 环未闭合 / 6 不支持构造 / 7 分子过大 / 8 电荷后缀非法 / 9 内部价态不一致。
