# INTEGRATION.md —— 衡引擎 v0.1 集成验收报告

集成线于 2026-10-30 在基线链 tip `47a53ee` 上执行：全树复验、跨线接线、
端到端一题、缺陷立账。本文件是本线的唯一交付记录；INTERFACE.md 未作任何
改动，契约层面的分歧只在 §3 以修订案形式提出，候主会话裁决。

工具链口径（全线统一）：本机 local-sa（sa 0.1.8 + LLVM14 垫片
`LD_LIBRARY_PATH=~/workspace/local-tools/llvm14/extracted/usr/lib/x86_64-linux-gnu`，
`SA_STD_DIR=~/workspace/local-sa/sci/sa_std`，`SA_PLUGIN_DEV=1`）；check 语料
用 gosyntax 线 sla 二进制（与 check 线原验收同一构建）。全部构建/测试串行。
判读口径：rc=0 + 输出含预期结果行 + 失败名字集为空；后端按各线既定口径标注
（found=text、species=SAB、其余默认 SAB），双后端缺口见 §6 DEF-2。

## §1 全树复验（接线后最终树，合并树零回退）

| 子树 | 结果 | 名字集 / 证据 |
| --- | --- | --- |
| found | ALL PASS | 三库 sla check OK；test_bigint 6/6、test_rational 5/5、test_quantity 5/5（合计 16 条）；负例 neg_dim 期望 panic 8303、neg_unit 期望 panic 8301 均如设计（text 后端） |
| check | 1/1 + 23/23 | test_parse 1/1；test_c1 23 条全过（名字见下） |
| species | 20/20 | 清 .sla-cache 冷跑，SAB 后端（名字见下） |
| lang | ALL PASS (14/14) | 正例 ex01_photosynthesis、ex02_respiration、ex03_electrolysis、ex04_charcoal、ex05_oxygen_lab、ex06_neutralization、ex07_unbalanced；错误例 err01_lowercase、err02_equals、err03_paren、err04_plus_lhs、err05_plus_rhs；hint O、hint Ca |
| kb | ALL PASS | test_json 4/4；validate_kb 对 278 条（物种 139 = 初中 71 + 高中 68、方程式 109 = 初中 53 + 高中 56、fact 30）报 `RESULT ALL PASS（失败 0 项）`，validation_report.txt 与基线逐字节一致 |
| grade | 8/8 passed | 样例 L0-bal-001（应过/应败各一）、L0-spc-002（应过/应败）、L0-mr-003（应过/应败）、L0-val-004（应过/应败）VERIFY OK ×8（接线后口径，见 §2） |

check test_c1 23 条名字：balance respiration / balance missing H reports
element only / balance photosynthesis / balance charge only mismatch /
balance both element and charge mismatch / balance ionic equations pass /
balance missing coeff is structural error / balance unparseable species is
structural error / solve water formation / solve methane combustion /
solve respiration / solve photosynthesis / solve iron oxidation /
solve no solution / solve underdetermined / solve bad sign /
solve zero coeff spectator / valence valid compounds / valence valid ions /
valence invalid compounds / valence organic out of model fails loudly /
molar mass exact / reaction types。

species 20 条名字：formula water / fnv1a64 known vectors / formula glucose /
formula calcium hydroxide / formula hydrate copper sulfate /
formula ferric sulfate / formula ions / formula acetic acid /
formula record json / formula errors loud / smiles ethanol composition
and id / smiles acetic acid / smiles pyridine kekule equivalence /
smiles furan kekule equivalence / smiles alanine enantiomers differ /
smiles salts and charged species / smiles errors loud /
smiles same species helper / smiles record json shape /
smiles benzene kekule equivalence。

结论：接线改动（§2）之后最终树与接线前基线逐项同口径全绿，**零回退**。

## §2 接线 A（完成）：grade 的 balanced 切换到 check 线 C1 口径

原状态：grade 的 balanced 守恒判定为契约级自备实现（grade/README 明言
「未借 check 线 C1 的 check_balance」）。

改动（只动消费侧与 check 子树自有文件）：

- check 侧（`check/formula.sla`、`check/c1.sla`）：
  - `formula.sla` 新增 `parse_species_view(s, n, charge)`：与 parse_species
    同口径、长度显式传入的 (ptr, len) 视图入口（Species.formula 存传入的
    指针本人）。
  - `c1.sla` 新增静默结构化口径：`struct C1Balance {code, reason, bad_side,
    bad_idx, lt:[i64;36], rt:[i64;36], lc, rc}` + `c1_balance_new()` +
    `c1_balance_compute(eq, &rep)`——不打印；code 与 check_balance 同义
    （0 守恒 / 1 元素 / 2 电荷 / 3 两者 / −1 结构错误），reason 区分解析失败
    （1）与缺系数（2），以 bad_side/bad_idx 定位。`check_balance` 重构为
    compute + 打印，**消息文本与顺序逐字不变**（复验：check 语料仍 1/1 +
    23/23；demo 输出与 check/README 文档逐字一致，含漏 H 的
    `error[C1-element]` + ` H: 左 4 右 2`、电荷码 2、光合求解 [6,6,1,6]、
    多解 status 2、Mr(NaCl)=117/2、葡萄糖 180、复分解码 4）。
  - `c1.sla` 新增 `eq_add_lhs_view/eq_add_rhs_view`（(ptr,len)+电荷的加项
    入口；>8 项 panic 3101/3102 与 check 既有上限同码）；新增转发面
    `c1_elem_symbol(e)`、`c1_nelem()`（tables 的符号对隔层下游不可见——
    @import 只穿一层，GAPS check 节 ⑦——经 c1 转发）。
- grade 侧（`grade/src/grade.sla`）：`@import "../../check/c1.sla"` 同编译
  单元调用；符号碰撞仅 6 个（Comp/PState/Rat/comp_add_scaled/parse_seq/
  rat_make），grade 侧改名 GComp/GPState/GRat/grat_make/gcomp_add_scaled/
  gparse_seq 避让。judge_balanced 重写：骨架对齐（多重集/箭头）仍在 grade；
  守恒段逐项经 `ref_split`（与 check 的 parse_species_ref 同切分规则）切出
  (本体, 电荷)，以视图入口构造 check 的 Equation 后调
  `c1_balance_compute`；detail 由结构化报告翻译（如
  「元素 O 未守恒：左侧共 2 个，右侧共 1 个」）。删除 grade 自备守恒
  side_tot。文档已同步：grade/README 的 balanced 节、GAPS grade 节该条
  标注「集成线关闭」。
- 边界（响亮 fail，不静默降级）：C1 每侧 ≤8 项、36 元素表、L0 式形子集
  （括号/点号水合物等 check 解析器口径）；学生方程任一侧 >8 项在 grade 侧
  先行 fail 并在 detail 点名两侧项数。
- 复验：grade 样例包切换后仍 **8/8 passed**；字节级核验（防显示层伪影）：
  错答 verdict 文件内精确串「元素 O 未守恒：左侧共 2 个，右侧共 1 个」
  grep 命中，对答 detail 为「配平成立：两侧物种与题面一致，各元素原子数
  与总电荷守恒（2 种元素）」。
- 诚实注记：grade 层的「纯电荷不守恒」错答在多重集对齐后结构上近乎不可
  构造（改电荷即改物种 id），未单独造例；电荷 detail 分支是 rep.lc/rc 的
  直译，其判定本身在 check 语料 codes 2/3（charge only / both）已覆盖。

## §3 接线 B（核对完成，规范未统一 → 修订案）：species_id 对齐

### 实测对照（同一组成，四方产出）

探针：species 侧以 `formula_record_json` 取 id；grade 侧以 CLI
species_id_eq 的 detail 回显取 id；lang/kb 为原文产出（lang 输出 JSON、
kb 数据文件 id 字段）。

| 输入 | species 线 | grade | lang / kb |
| --- | --- | --- | --- |
| H2SO4 | `formula1:H2O4S@0` | `formula1:H2O4S@0` | `formula1:H2SO4@0` |
| C2H5OH | `formula1:C2H6O@0` | `formula1:C2H6O@0` | `formula1:C2H5OH@0` |
| SCl2 | `formula1:SCl2@0` | `formula1:Cl2S@0` | （原文）`formula1:SCl2@0` |
| Ca(OH)2 | `formula1:H2O2Ca@0` | `formula1:H2CaO2@0` | `formula1:Ca(OH)2@0` |
| Al2O3 | `formula1:O3Al2@0` | `formula1:Al2O3@0` | `formula1:Al2O3@0` |
| SO4^2- | `formula1:O4S@-2` | `formula1:O4S@-2` | kb 离子按数据原文 |
| NaOH | `formula1:HONa@0` | `formula1:HNaO@0` | `formula1:NaOH@0` |
| Fe2(SO4)3 | `formula1:O12S3Fe2@0` | `formula1:Fe2O12S3@0` | （原文形） |

分歧根源：占位式本体的排序规则三家不同——species 为 Hill 变体（C、H 先，
其余按原子序数 Z 升序；species 线 GAPS 自认是 Z 序近似）；grade 为
C/H 优先 + 其余字母序（接近严格 Hill）；lang 不规范化（发原文）、kb 为
数据原文（课本式，含括号形如 `formula1:Ca(OH)2@0`、`(NH4)2SO4`）。
8 例中 species 与 grade 一致 3 例（H2SO4、C2H6O、SO4²⁻），分歧 5 例。

功能影响评估：**当前无任何按字符串等值消费 id 的路径**——grade 全部断言
先解析再比组成，lang/kb 的 id 只作记录标识。故今天不构成错判；风险在
未来出现字符串等值消费者（跨库引用、缓存键）时静默错位。

canon1 状态：species 已落地（SMILES 图物种 `canon1:<16 位小写 hex>`，
FNV-1a-64 规范序列化、版本入计算域，20 条语料含 Kekulé 等价与对映体
区分）。**未接**：grade 遇 `canon*:` 前缀响亮拒绝（err 3 口径不变）；
阻塞点 = canon1 的等值判定需要图的规范身份判定（species 的
smiles_same_species 路径），且 L0/L1 表层（lang 语法）尚不收 SMILES 输入，
无题面可达路径。建议随 L2 表层支持 SMILES 时一并接入。

### 契约修订案（只提案，不改 INTERFACE.md，候主会话裁）

- 案由：INTERFACE 只定 `formula1:<FORMULA>@<charge>` 占位形，未定义
  FORMULA 的规范化规则；四方实现各自备案，字符串不等值。
- 选项甲：以 species 现行输出为准（C/H 先 + Z 序）。成本：grade 改排序
  （小）；lang 须内建 Z 序表并规范化（中）；kb 全部多元素物种 id 重生成
  （数据修订 + 校验器复跑）。
- 选项乙（本线推荐）：以**严格 Hill**（C 先、H 次、其余元素符号字母序）
  为准——「Hill 式」是 INTERFACE/species 备案里已写明的名称，严格 Hill
  是其外部标准含义；grade 已是此口径（零改动），kb 课本式与之最接近，
  species 只需改 hill_formula 一处（其 GAPS 已自认 Z 序为近似待修）。
  成本：species 改一函数 + 语料期望更新；lang 规范化（小：C/H 特判 +
  符号字母序排序，lang 已有组成计数）；kb 多元素 id 按新规重生成。
- 无论甲乙，建议同批在 INTERFACE 增补一句规范定义 + 一条「id 只许由
  species 层算法产生、消费方解析比对」的纪律，与 canon1 的接入时点绑定。

## §4 接线 C（评估完成：大，登记下轮）：check 自备有理数切 found rational

结论：**不切换，登记为下轮项**。证据：

1. 耦合面不在签名层。check 的有理数热路径不是 rat.sla 的 Rat（Rat 仅
   tables.elem_weight 一处生产、molar_mass_nd 一处消费），而是 c1.sla 自备
   的 (num, den) 对函数层 fr_norm/fr_add4/fr_sub4/fr_mul4/fr_div4（15 处
   引用），且 solve_balance 的 RREF 矩阵以两张扁平 i64 数组
   `an/ad: [i64; 432]` 存 (num, den) 对。切换 = 求解器存储与算术层重写，
   不是换名。
2. 类型形态不合。found 的 Rational 建在 BigInt 之上，BigInt = 符号 +
   Vec<u32> limb 向量（堆对象）；把 Rational 值塞进 432 格矩阵 = 大量
   含堆字段结构体按值搬运，正落在 §6 DEF-1（按值传递损坏）的爆心，且
   check 线已实证 Vec<T> 在其导入链链接失败（undefined sa_vec_free）。
3. 后端未证。found 语料固定 text 后端（SAB 有 DEF-2 缺口）；check 语料
   跑 SAB（默认）。切换会把未证组合引入 C1 判定路径。
4. 无语义必要。v0.1 规模（≤12 物种、系数为小整数、原子量分母为小整数）
   下 (i64, i64) 精确有理数与任意精度结果恒等，i64 余量（9.2e18）对 RREF
   中间量（lcm 有界）绰绰有余。
5. 触发条件（满足其一再立项）：DEF-1 在编译器侧修复；或 found rational
   在 SAB 后端获证；或 L2 出现 i64 包络外的精确分数需求（如平衡常数连乘）。

## §5 端到端一题（e2e/，命令与输出原文）

题 L0-e2e-001（`e2e/problem.json`）：氢气燃烧配平，balanced 断言，
骨架 `H2 + O2 -> H2O`。学生作答以 .heng 文本写出
（`e2e/answer_ok.heng` / `e2e/answer_bad.heng`）：

```text
species H2
species O2
species H2O
assert balanced 2 H2 + 1 O2 -> 2 H2O        // 对答
assert balanced 1 H2 + 1 O2 -> 1 H2O        // 错答（氧未配平）
```

管道（`e2e/run_e2e.sh` 一键复跑）：heng_parse 解析 → `e2e/adapt.sla`
（SLA 适配器：取 lang 输出 assertions[0].equation，经 sa_json_stringify
原样嵌回 grade 的 answer 形）→ grade CLI 判分（balanced 内部即 §2 的
check C1 口径）→ VerdictReport。

lang 解析输出（对答，原文）：

```json
{"species":[{"id":"formula1:H2@0","formula":"H2","composition":{"H":2},"charge":0},{"id":"formula1:O2@0","formula":"O2","composition":{"O":2},"charge":0},{"id":"formula1:H2O@0","formula":"H2O","composition":{"H":2,"O":1},"charge":0}],"equations":[],"assertions":[{"kind":"balanced","equation":{"lhs":[["formula1:H2@0",2],["formula1:O2@0",1]],"rhs":[["formula1:H2O@0",2]],"arrow":"->"}}]}
```

适配后 answer（原文）：

```json
{"problem_id":"L0-e2e-001","items":[{"equation":{"lhs":[["formula1:H2@0",2],["formula1:O2@0",1]],"rhs":[["formula1:H2O@0",2]],"arrow":"->"}}]}
```

VerdictReport（对答，原文）：

```json
{"problem_id":"L0-e2e-001","results":[{"assertion_index":0,"pass":true,"detail":"配平成立：两侧物种与题面一致，各元素原子数与总电荷守恒（2 种元素）","provenance":["derived"]}],"all_pass":true}
```

VerdictReport（错答，原文）：

```json
{"problem_id":"L0-e2e-001","results":[{"assertion_index":0,"pass":false,"detail":"元素 O 未守恒：左侧共 2 个，右侧共 1 个","provenance":["derived"]}],"all_pass":false}
```

错答 fail 且 detail 精确指出氧不守恒的数量差，满足验收。注记：lang 对
省略系数发 null（如 ex01 的 C6H12O6），grade 侧会响亮判结构错误；本例
两答均显式写全系数。省略系数→默认 1 的口径对齐属 lang/grade 间的小
契约项，建议主会话在 §3 修订案同批裁定（本线倾向：grade 对 null 系数
按断言语义响亮 fail 是对的，教学面应由 lang 在解析期提示补全系数）。

## §6 缺陷立账（转 SLA 线，本线不修编译器）

### DEF-1 结构体按值传递/返回时大数组字段损坏

- 现象：含大定长数组字段的结构体按值传参、按值返回、链式按值传递或从
  返回结构体按值移出大数组字段时，数组内容在头部之后截断/清零/读写
  分裂，而标量字段（如 len）正确。
- 三线互证（最小复现留档于各线工作过程，登记于 GAPS.md）：
  - lang 线：`PathB { bytes: [u8; 1024], len }` 按值传参后对 bytes 的写
    仅前 8 字节生效、其余清零，len 却正确累加（papp 按值版探针）。
  - check 线：① 含 `[i64; 36]` 的结构体按值传参仅头部可信；② 从返回
    结构体按值移出大数组字段（`S { comp: r.comp }` 形态）头部之后损坏；
    对照：扁平返回、本地构造整体移动 PASS，字段移出 FAIL。
  - grade 线：含数组大结构体链式按值传递时读写分裂（同一数组两种读法
    结果不一致，tg/th 探针）。
  - kb 线同族登记：FMap（含元素计数映射的结构体）按值复制实测丢字段。
- 影响面：全仓统一绕行纪律——大结构体一律 `&` 借用读、本地构造后整体
  移动、借用出参填充；§4 的 rational 切换评估亦受此缺陷封顶。
- 双后端：SAB 后端实证（各线验收后端）；text 后端未单独证伪，按同族
  处理候 SLA 线复核。

### DEF-2 String 双表示的双后端缺口（sa_plugin_sla POTENTIAL_ISSUES #15 同族）

- 现象：SLA 的 String/Slice 双表示（值格/指针）在两后端语义不一致：
  - found 线（镜像一）：SAB 后端 `String.as_bytes()` 报 UnknownRegister
    （trap 1007）——found 语料被迫固定 `--test-backend sa`（text）。
  - species 线（镜像二）：同一代码在 SA(text) 后端长度/指针失真（parse
    全灭、fnv 段错误）；`STR_PTR(ptr 形参)` 在两后端均段错误；
    `String.bytes()` 在 SAB 报 UnknownRegister callee——species 验收
    被迫固定 SAB 后端。
  - grade/check/kb/lang 各线均以 (ptr, len) 对传参 + STR_PTR/STR_LEN
    仅对本地 owned String 使用的纪律绕行（kb 线纪律 ① 同此）。
- 影响面：**全仓没有任何一条语料能双后端同跑**——found 锁 text、
  species 锁 SAB，其余线在各自后端内自洽但跨后端行为未证。此缺口关闭
  前，各线验收口径不得升级为「双后端」。
- 附带同族小项（found 线登记）：text 后端验证器 PhiStateConflict
  （String 绑定跨分支合并点改赋值触发 trap 1015），已以 return 式选择
  助手绕行，根因在 SA 验证器。

## §7 本线改动清单

- 修改：`check/formula.sla`（+parse_species_view）、`check/c1.sla`
  （+C1Balance 静默口径、+视图加项、+符号转发；check_balance 行为不变）、
  `check/README.md`（接线面文档）、`grade/src/grade.sla`（balanced 切 C1、
  6 符号改名、删自备守恒）、`grade/README.md`（口径改写）、`GAPS.md`
  （grade 节 balanced 条关闭登记）。
- 新增：`e2e/`（problem.json、answer_ok.heng、answer_bad.heng、adapt.sla、
  run_e2e.sh、README.md、out/ 下六份运行证据 JSON）、本文件。
- 未动：INTERFACE.md、README.md（仓根）、found/species/lang/kb 四子树
  全部源码与数据（仅复验与只读探针）。
