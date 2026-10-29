# 衡 · Heng —— L0/L1 语言面表层语法 v0.1（lang 线）

状态：v0.1 冻结本。实现 = `heng_parse.sla`（同目录）。跨线输出契约以仓根 `INTERFACE.md` 为准；
本文定义表层写法、输出 JSON 的具体形状、诊断话术格式与 check 层衔接点。

## 1. 文件组织

- 一个 `.heng` 文件 = 若干**语句**，**一行一条语句**（v0.1 不续行；写不下就拆成两行）。
- 空行忽略；`//` 起到行尾是注释（注释可写中文）。`//` 出现在 `value_eq` 的引号字符串内时不算注释。
- 语句只有三种：`species` 声明、方程式、`assert` 断言。

## 2. EBNF

```ebnf
program      := { line }
line         := [ statement ] [ comment ]
comment      := "//" { any_char }
statement    := species_stmt | equation | assert_stmt

species_stmt := "species" species_ref

equation     := side arrow side
side         := term { "+" term }
term         := [ coefficient ] species_ref
coefficient  := number                          (* 整数或小数，> 0；可紧贴化学式也可空格分隔 *)

species_ref  := formula [ charge ]
formula      := factor { factor }
factor       := element [ count ] | "(" formula ")" [ count ]
element      := UPPER [ LOWER ]
count        := DIGIT { DIGIT }
charge       := "^" [ DIGIT { DIGIT } ] ( "+" | "-" )     (* 写法甲：SO4^2-、PO4^3- *)
              | [ DIGIT ] ( "+" | "-" )         (* 写法乙：Ca2+、OH-、H+；判定规则见 §3 *)

arrow        := "->" | "<=>"

assert_stmt  := "assert" ( "balanced" equation
                         | "value_eq" string_lit "=" quantity "tol" tol
                         | "species_eq" species_ref species_ref )
quantity     := number unit
number       := DIGIT { DIGIT } [ "." DIGIT { DIGIT } ]
unit         := IDENT { ( "/" | "*" ) IDENT }   (* 如 g、mol、L、g/mol、kJ/mol *)
tol          := number | number "%"
string_lit   := '"' { any_char_except_quote } '"'
```

## 3. 化学式与电荷的判定规则（写死，不许猜）

- 元素符号：首字母大写、可跟一个小写字母（`H`、`O`、`Na`、`Fe`）。小写开头直接报错（见诊断 E_LOWER）。
- 角标数字紧跟元素符号或右括号：`H2O`、`Ca(OH)2`、`Fe2(SO4)3`。括号可嵌套。
- 电荷写在化学式**末尾**，两种写法：
  - 写法甲（带 `^`，无歧义，**多原子离子必须用这种**）：`SO4^2-`、`CO3^2-`、`PO4^3-`、`NH4+` 也可写 `NH4+`（见下）。
  - 写法乙（不带 `^`）：`H+`、`OH-`、`Cl-`、`Ca2+`、`Fe3+`。
  - 消歧规则（解析器按此执行）：紧贴化学式末尾的 `+`/`-` 若其后是空格+`+`、箭头、行尾或另一个 `+`，判为电荷；
    若其后紧跟下一个化学式（无空格），判为方程式的连接符 `+`。
    无 `^` 时，符号前的数字**仅当化学式本体是单个元素**时算电荷数（`Ca2+` = Ca 本体 + 2 电荷）；
    本体是多元素时数字归本体（`NH4+` = NH4 本体 + 1 电荷；`NO3-` = NO3 本体 + 1 电荷）。
- 系数缺省 ≠ 系数 1：**没写系数 = 还没配平**，输出为 `null`（待配平形态），见 §5。

## 4. 量与单位

- 量一律「数值 + 单位」：`5 mol`、`36 g`、`18 g/mol`。数值只允许整数与小数（分数是 L1 预留）。
- 单位是标识符，可用 `/`、`*` 组合（`g/mol`、`kJ/mol`）。单位的量纲换算归 found 线，lang 只记录原文。

## 5. 输出 JSON（解析成功时 stdout 输出一个对象，退出码 0）

```json
{ "species": [ SpeciesRecord, ... ],
  "equations": [ EquationRecord, ... ],
  "assertions": [ Assertion, ... ] }
```

- `SpeciesRecord`（= INTERFACE）：`{ "id", "formula", "composition", "charge" }`。
  - `id`：canon 就绪前用占位式 `"formula1:<formula>@<charge>"`（INTERFACE 已备案的占位格式）。
  - `formula`：化学式本体原文（不含电荷后缀），如 `"Ca(OH)2"`、`"C2H5OH"`（同物种不同写法在本层是**两个**记录，
    是否同一物种由 `species_eq` 断言交给 species 线的规范化判定）。
  - `composition`：元素符号 → 计数，按在化学式中首次出现的顺序；`charge`：整数（`Ca2+` → 2，`OH-` → -1，中性 → 0）。
  - 文件中出现过的物种（含仅在方程式/断言里出现的）全部登记，按首次出现顺序去重。
- `EquationRecord`（= INTERFACE）：`{ "lhs": [[id, 系数], ...], "rhs": [...], "arrow": "->" | "<=>" }`。
  - 系数：整数 → JSON 数（如 `2`）；小数 → 精确有理数字符串（如 `0.5` → `"1/2"`）；**未写 → `null`（待配平）**。
- `Assertion`（= INTERFACE 三种）：
  - `{"kind":"balanced","equation":EquationRecord}`
  - `{"kind":"value_eq","expr":"<引号内原文>","expect":{"value":"<数值原文>","unit":"<单位原文>"},"tol":"<原文，如 0.5 或 1%>"}`
  - `{"kind":"species_id_eq","a":id,"b":id}`（表层写法是 `assert species_eq A B`，输出 kind 用契约名 `species_id_eq`）。

## 6. 教学级诊断（解析失败时 stdout 输出文本，退出码 1）

固定两行格式（行、列均 1 起；列按**字符**计，中文算 1 列）：

```
第 {line} 行第 {col} 列出了点问题：{一句话：错在哪、期望什么}
出错的那一行：{该行原文}
```

错误码表（实现与本文一一对应，不许另造）：

| 码 | 触发 | 话术要点 |
|---|---|---|
| E_LEX | 不认识的符号 | 指出该符号，说明化学式只用英文字母/数字/括号 |
| E_LOWER | 元素符号小写开头 | 元素符号首字母要大写，举例 H2O |
| E_SPECIES | 该写化学式的位置是空的/不对 | 这里应该写一个化学式 |
| E_PAREN_OPEN | `(` 没关上 | 前面有个 ( ，后面要补 ) |
| E_PAREN_CLOSE | `)` 没有配对的 `(` | 这个 ) 前面没有 ( |
| E_COUNT | 数字位置不对 | 角标数字要跟在元素符号或 ) 后面 |
| E_ARROW | 缺箭头 | 左边反应物、中间 -> 或 <=>、右边生成物 |
| E_ARROW_EQ | 用了 `=` 连接 | 方程式中间不能用 = ，要用 -> 或 <=> |
| E_PLUS | 两项之间缺 `+` | 两个化学式之间要用 + 连接 |
| E_SIDE | 箭头某侧为空 | 箭头两边至少各写一个化学式 |
| E_TAIL | 一行末尾有多余内容 | 这行后面多出来的东西看不懂 |
| E_COEF | 系数非法（≤0 或写错） | 系数是写在化学式前面的大于 0 的数 |
| E_CHARGE | 电荷写法错（如 `^` 后缺符号） | 电荷要紧贴化学式末尾，如 Ca2+、SO4^2- |
| E_ASSERT | assert 后面的词不认识 | 只能是 balanced / value_eq / species_eq |
| E_EQSIGN | value_eq 缺 `=` | 用 = 把表达式和期望值连起来 |
| E_STRING | 引号没关上 | 字符串要用一对英文双引号括起来 |
| E_TOL | value_eq 缺 tol | 要写明允许误差，如 tol 0.5 |
| E_UNIT | 缺单位或单位写错 | 数值后面要跟单位，如 g、mol、g/mol |
| E_STMT | 整行不认识 | 每行只能是 species、assert 或一个方程式 |
| E_COMPLEX | 超出 v0.1 规模上限（物种 >192、元素 >96、组成条目 >2048） | 这个化学式太复杂了，先写简单一点的 |

## 7. 与 check 层的衔接（本线只留格式与渲染，不实现 C1 本体）

- check 线判定 `balanced` 断言后，逐元素差量用此 JSON 形状回传（grade 线同用）：
  `{"kind":"balance_delta","element":"O","lhs":2,"rhs":1}`（lhs/rhs = 该元素在方程式两侧的原子总数）。
- lang 线提供把差量渲染成教学句子的入口（同一二进制）：
  `heng_parse --hint <元素符号> <lhs> <rhs>` → 例：`heng_parse --hint O 2 1` 输出
  `氧（O）：左边有 2 个，右边只有 1 个，两边不一样多。`
  常见元素中文名内嵌（H 氢、O 氧、C 碳、N 氮、S 硫、P 磷、Cl 氯、Na 钠、K 钾、Ca 钙、Mg 镁、
  Al 铝、Fe 铁、Zn 锌、Cu 铜、Ag 银、Ba 钡、Mn 锰、I 碘、Br 溴、Si 硅）；表外元素只报符号。

## 8. v0.1 限制与预留扩展点（刻意保持语法小）

v0.1 **不引入**（高级别才解锁，此处仅留位、写明防日后乱加）：

- **能量标注**（L2+）：`energy { ... }` 块、G0/barrier 写法——预留在方程式行后以独立语句接入，v0.1 见到即 E_STMT。
- **箭头条件**（L1）：`-> [点燃]` 式条件标注（点燃/通电/加热/催化剂）——预留在箭头后方括号位。
- **分数系数**（L1）：`1/2 O2` 式写法；v0.1 系数只收整数/小数（小数输出已按有理数，语义等价）。
- **区室与膜**（L3+）：`compartment` / `membrane` / `in::` 前缀。
- **协议层与观察**（L3+）：`protocol` / `observe` / 时间点语句。
- **变量与赋值**：语言面永远不引入（核心演算公理：无赋值）；`let` 不是预留项，是明确拒绝项。
- 文件级组织将来可加 `module`（模块接口物种），v0.1 文件即全量、无导入。
