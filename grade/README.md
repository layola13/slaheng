# grade —— 衡 · Heng 判分运行时（v0.1 最小形态）

题目 = 模型 + 断言集 + 评分要点 → 判定 + 溯源报告。实现：`src/grade.sla`
（SLA 单文件 CLI）；样例验收器：`src/verify.sla`（同样 SLA）。**本线零 Python
依赖**：工具、脚本、校验器、测试 harness 均为 SLA / POSIX sh（sh 只做顺序
编排，一切判定与比对逻辑在 SLA 内）。

## 构建与运行

```sh
./run_grade.sh <problem.json> <answer.json>   # 构建（按需）并运行判分器
./run_samples.sh                              # 样例题包验收（8/8 应全过）
```

工具链为本机布局：`sla` = `~/workspace/local-sa/sa_plugin_sla/zig-out/bin/sla`，
`sa`/`zig` 在 `~/workspace/local-sa/` 下，`SA_STD_DIR=~/workspace/local-sa/sci/sa_std`
（脚本内已设置）。产物复制到 `bin/grade`、`bin/verify`（不入库）。

## CLI 契约

`grade <problem.json> <answer.json>` → stdout 输出一行 VerdictReport JSON：

```json
{"problem_id":"...","results":[{"assertion_index":0,"pass":true,"detail":"...","provenance":["derived"]}],"all_pass":true}
```

字段严格按 `INTERFACE.md` 的 VerdictReport：`assertion_index / pass / detail /
provenance`；v0.1 三种断言的 provenance 恒为 `["derived"]`。

退出码：`0` = 已产出报告（all_pass 是数据、不是进程状态）；`2` = 用法错误；
`3` = 文件读取/JSON 解析失败；`4` = 题目/答案结构错误（含 problem_id 不一致、
assertions 缺失、rubric 非数组）。硬错误时 stdout 输出 `{"error":"..."}` 一行。

## 题目格式（Problem）

```json
{ "problem_id": "L0-bal-001", "curriculum": "初中", "topic": "化学方程式配平",
  "model": { "species": ["H2","O2","H2O"], "note": "…" },
  "assertions": [ Assertion... ],
  "rubric": [ {"point":"…","max":2} ] }
```

- `model` 为题面模型（物种/方程式等），v0.1 判分器不直接消费、原样保留。
- `rubric`（可选）v0.1 **只做结构校验（必须为数组）与透传**，不做 extern 判定；
  评分要点判定属后续 extern 层（见 GAPS）。

## 答案格式（Answer，本线自定、备案于此）

```json
{ "problem_id": "L0-bal-001", "items": [ Item... ] }
```

`items[i]` 与 `assertions[i]` 按下标对位（缺项 = 未作答、该条 fail 并在 detail
注明）。`problem_id` 可省略；给出则必须与题目一致，否则退出码 4。

| 断言 kind | Item 结构 | 说明 |
|---|---|---|
| `balanced` | `{"equation": EquationRecord}` | 学生的完整方程式（物种+系数+箭头）。缺项时以断言自身 equation 自判（骨架系数为占位、自判通常不通过守恒——教师勿依赖此模式） |
| `value_eq` | `{"value": Quantity}` | `Quantity = {"value": "<rational 字符串>", "unit": "<单位字符串>"}` |
| `species_id_eq` | `{"b": "<物种引用>"}` | 缺项时改判断言自身的 `a`/`b`（断言须自带 `b`） |

## 三种断言的判定口径

### balanced（守恒判定已切换至 check 线 C1 口径，集成线落地）

题面断言的 `equation` 是**骨架**：两侧物种多重集（按 species_id 级别）与
`arrow` 是期望，**骨架系数仅占位、不参与判定**。学生方程须：

1. 两侧物种多重集与骨架逐一相等（写序任意、系数忽略）；
2. 箭头与骨架一致（骨架未给箭头则不查）；
3. 自身守恒——由 check 线 C1 判定（`c1_balance_compute`，经
   `@import "../../check/c1.sla"` 同编译单元调用；grade 只把学生方程构造为
   check 的 Equation 并把结构化结果译为 detail，不再自备守恒算术）。

系数须为正整数（0 = 该物种不参与、跳过；负数/小数响亮报错）。fail 的 detail
逐项点名：多出/缺少的物种 id、未守恒的元素及两侧计数、电荷差。边界：C1
每侧至多 8 项、元素须在 C1 的 36 元素表内、式形须为 L0 子集（不支持点式
水合物/方括号配位式），超出响亮 fail 并在 detail 注明。

### value_eq

`{"kind":"value_eq","expr":"Mr(CO2)","expect":Quantity,"tol":"<rational>"}`。
单位先做字符串精确比对（量纲向量比对待 found/ 落地后切换，见 GAPS）；
数值走自备精确有理数比较：`|答案 − 期望| ≤ tol`（连分数比较、零溢出乘积）。
`tol` 必须题面显式给出，缺失即 fail（不默认 0）。`expr` 仅作标识回显，
**不求值**（Mr 等求值属 check/kb 的范围，见 GAPS）。

### species_id_eq

两侧物种引用解析为 (composition, charge) 后生成 formula1 占位 id 比对。
fail 的 detail 给出两边 id 及逐元素计数差、电荷差。

## 物种引用微格式（v0.1）

- 原始化学式：元素符号 + 计数 + 括号分组，如 `H2SO4`、`Ca(OH)2`、`Al2(SO4)3`；
  元素表为 L0/L1 常用 48 元素，未知元素响亮报错。
- 离子电荷后缀：`Na+`、`OH-`、`Ca2+`、`SO4^2-`/`SO4^3-` 等。约定：带 `^` 时
  其前数字全为电荷量；不带 `^` 时符号前**最多一位**数字为电荷量（如 `SO42-`
  读作 SO4 带 2−），其余数字属化学式本体。
- 占位 id：`formula1:<Hill 规范式>@<charge>`（INTERFACE 备案格式），可直接
  作题面/答案的物种引用。Hill 序：有碳先 C 后 H、其余字母序；无碳全字母序。
- `canon1:` 正式 id 在 v0.1 **不可解析、响亮 fail**（canon 归 species/ 线）。

## 零浮点声明

判定路径零浮点：数值只经 ① `sa_json_as_i64` 读整数 kind、② NUMBER_STRING/
字符串走自备逐位文本解析为有理数（`p/q` 或十进制，不接受科学计数法）。
JSON 中 FLOAT kind 的系数直接拒绝（detail「系数不是整数」）。源内审计：
`grep -n "f64" src/*.sla` 无命中（数值路径不引用任何浮点 extern）。
注：sa_std JSON 分词器为共享依赖，数值读取只用其 i64/字符串访问器，
FLOAT 仅以 kind 码形式被识别并拒绝。

## 样例题包（problems/）

| 目录 | 题目 | 全对 | 典型错答（预期 fail 点） |
|---|---|---|---|
| p1_balancing | L0-bal-001 配平（含离子式电荷守恒 + rubric 透传演示） | [pass, pass] | [fail, pass]：O 未守恒（左 2 右 1） |
| p2_species | L0-spc-002 化学式同物种判等（H2SO4） | pass（H2O4S 同式） | fail：O 计数 4 ≠ 3 |
| p3_mr | L0-mr-003 相对分子质量 Mr(CO2)=44 | pass | fail：28 之差 16 > 容差 0 |
| p4_valence | L0-val-004 化合价式判等（Al2O3）+ 置换反应配平 | [pass, pass] | [fail, pass]：AlO（Al 2≠1、O 3≠1） |

每题目录含 `problem.json / answer-ok.json / answer-bad.json /
expect-ok.json / expect-bad.json`；`./run_samples.sh` 全链验收。

## 批量并发判分（期二首项）

判定核已拆分：`src/grade_lib.sla`（全部判定与输出助手，代码搬运零
改动）+ `src/grade.sla`（单份 CLI，行为与 v0.1 逐字节一致，样例 8/8
与拆分前构建逐字节对拍已实证）。

`src/grade_batch.sla` 为批量入口（设计见仓根 `CONCURRENCY.md`）：
`grade_batch <manifest.json>`，清单为 JSON 数组
`[{"problem":"…","answer":"…"}, …]`（上限 128 份）。每份判定由一个
goroutine 在本帧内私有完成，结果按清单原序确定性合并——批量 stdout
逐字节等于各份单跑 `grade` 的 stdout 按序拼接。退出码：0 = 全部已
判定；1 = 至少一份硬错误（该份以 `{"error":…}` 行呈现，与单跑的
stdout 行一致；单跑的 stderr 提示与非零退出码语义收敛为此行 + 1）；
2 = 用法错误；3 = 清单读取/解析失败。批量模式另有两条上限（响亮报
错、呈现为该份的 error 行）：单题断言 > 24、problem_id > 512 字节。

构建：`sla build-exe src/grade_batch.sla`（需 goroutine 语法批工具链，
见 CONCURRENCY.md §4）。验收：`./run_batch_test.sh`（16 份混合清单
含 3 份错误形态 × 5 轮与单跑拼接逐字节对拍）。
