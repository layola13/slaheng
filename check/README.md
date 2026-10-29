# check/ —— C1 检验层（衡引擎线 3）

对位核心演算草案 C1（静态守恒检查）与 L0 初中教育面：给定 INTERFACE 的
SpeciesRecord / EquationRecord 契约，做配平检查、配平求解、化合价检查、
相对分子质量与反应类型判定。一切判定走精确有理数，无浮点、无静默兜底：
无解 / 多解 / 不适用一律响亮报错并以返回码区分。

**零 Python 声明**：本子树无任何 Python 文件与运行时依赖；测试为 SLA
语料，运行口径见下文。

## 文件

| 文件 | 内容 |
|---|---|
| `rat.sla` | i64 精确有理数小实现（found 线 rational 就绪前的顶替，切换点） |
| `tables.sla` | 36 元素表：符号 / 相对原子质量 / 化合价候选集（镜像，人工可读原件在 `data/`） |
| `formula.sla` | 化学式解析：Species{composition, charge, formula, ok}，失败响亮 ok=false |
| `c1.sla` | 五项交付主体（见下）+ 报告打印层（绕 println 的 ptr 参数缺陷） |
| `demo.sla` | 演示程序：把各检查的诊断文本打到标准输出（`sla build-exe demo.sla`） |
| `data/atomic_weights.txt` | 相对原子质量（学校近似值，分数形）；provenance: `measured:textbook-cn-junior` |
| `data/valence_table.txt` | 初中化合价候选集 + 原子团价态；provenance: `measured:textbook-cn-junior` |
| `tests/test_parse.sla` | 解析语料：嵌套括号计数、非法式拒绝 |
| `tests/test_c1.sla` | C1 验收语料 23 例（逐项断言） |

## 对外 API（c1.sla）

方程式以 `Equation`（每侧至多 8 个 `Term{Species, coeff, has_coeff}`）表示，
由 `eq_new()` + `eq_add_lhs/eq_add_rhs(&eq, formula, charge, coeff, has_coeff)`
构造——这正是 EquationRecord 的消费形态：物种经 `parse_species(formula, charge)`
消费 SpeciesRecord 的 formula/charge 面，composition 由解析产出（与 species 线
canon 的 composition 契约同形，id 对接候集成期）。

- `check_balance(&eq) -> i64`：配平检查。系数须齐备。返回 0 守恒 / 1 仅元素
  不守恒 / 2 仅电荷不守恒 / 3 两者皆不守恒 / −1 结构错误（解析失败或缺系数）。
  元素不守恒时合并报告一份：`error[C1-element]` 表头 + 逐元素差量行
  （如 ` H: 左 4 右 2`）；电荷为 `error[C1-charge]: 两侧电荷不守恒: 左 {} 右 {}`。
- `solve_balance(&eq) -> SolveRes`：配平求解（系数可空缺）。有理数
  Gauss–Jordan 全约化求解空间：恰一维时定向、通分、约分得最小正整数解，
  并整数回代自检。`status`：0 成功（`coeffs[0..n)` 按左后右物种序）/
  1 无解 / 2 多解（`nullity` 给维数）/ 3 异号解 / 4 零系数（`bad_index`
  指明物种）/ 5 结构错误。四种失败都有 `error[C1-solve]` 响亮说明。
- `check_valence(&sp) -> i64`：化合价检查。1 合法 / 0 无分配 / −1 不适用
  （解析失败或元素无表条目）。模型：每元素取单一价态，合法 ⟺ 存在候选
  分配使 Σ计数×价态 == 电荷（离子以其电荷为目标，如 SO4²⁻、NH4⁺ 均可验）。
- `molar_mass_nd(&sp) -> (num, den)`：相对分子质量的精确有理数；
  `print_molar_mass(&sp)` 打印 `Mr(X) = p/q` 与教科书口径一位小数。
- `reaction_type(&eq) -> i64`：1 化合 / 2 分解 / 3 置换 / 4 复分解 / 0 其他 /
  −1 结构错误；同时打印 `info[C1-type]: <类型名>`。判定纯按方程式形状：
  多→一化合、一→多分解；2→2 两侧各恰一种单质为置换；2→2 全化合物且
  右首项支撑集与左两项皆不同（确有交换）为复分解。

## 验收语料（tests/test_c1.sla，23 例全绿）

- 配平检查：光合作用、呼吸作用守恒通过；漏 H 方程式（2H2O→H2+O2）报
  元素码 1；SO4 误标 −1 价报电荷码 2；元素+电荷双不守恒报 3；离子方程式
  （H⁺+HCO3⁻、Fe²⁺+2Cl⁻）通过；缺系数 / 不可解析物种报 −1。
- 配平求解：H2+O2→H2O =[2,1,2]、CH4 燃烧 =[1,2,1,2]、呼吸 =[1,6,6,6]、
  光合 =[6,6,1,6]、铁氧化 =[4,3,2]；H2→H2O 无解（status 1）；
  H2+O2→H2O+H2O2 多解（status 2, nullity 2）；H2O2→H2O+H2 异号
  （status 3）；含惰性 He 零系数（status 4, bad_index 2）。
- 化合价：Fe2(SO4)3 / NaOH / H2SO4 / Ca(OH)2 / NH4Cl / KMnO4 / H2O2 / O2
  合法；SO4²⁻、NH4⁺ 离子合法；NaCl2、FeCl 不合法；葡萄糖在本模型内无
  分配、响亮失败（有机式出界，见 GAPS）。
- 相对分子质量：H2O 18、CO2 44、C6H12O6 180、CaCO3 100、NaCl 117/2、
  Ca(OH)2 74（全为精确有理数断言）。
- 反应类型：化合 / 分解 / 置换（Zn+H2SO4）/ 复分解（中和、AgNO3+NaCl）
  / 其他（CH4 燃烧）各就其码。

可读诊断证据：`demo.sla` 经 build-exe 运行的输出（含「 H: 左 4 右 2」等
报告原文）已在本线终报中留档。

## 运行口径

```sh
export PATH="$HOME/workspace/local-sa/zig17:$HOME/workspace/local-sa/sci/zig-out/bin:$PATH"
export SA_STD_DIR=$HOME/workspace/local-sa/sci/sa_std
SLA=$HOME/workspace/gosyntax-local/sla-plugin/zig-out/bin/sla
cd ~/workspace/heng/check/tests && rm -rf .sla-cache
$SLA test test_parse.sla   # 期望: test result: ok. 1 passed; 0 failed
$SLA test test_c1.sla      # 期望: test result: ok. 23 passed; 0 failed
cd ~/workspace/heng/check && rm -rf .sla-cache && $SLA build-exe demo.sla
# 产物: .sla-cache/sab/demo-<hash>，直接执行看诊断输出
```

判读纪律：`sla test` 在 `sa` 不在 PATH 时会报错却 rc=0（假绿），一律读
输出内容判读（须含 `test result: ok` 且失败名集为空），不认 rc。

## 已知边界

见 GAPS.md「check 线」节：有理数待切换 found 线 rational；化合价单价态
模型边界（Fe3O4、有机式、氢 −1 出界）；解析不支持水合物点式与配位
方括号；规模上限（每侧 8 项 / 求解物种 12）超出响亮 panic；以及本线
实证的八条 SLA/SAB 前端缺口与绕行纪律。
