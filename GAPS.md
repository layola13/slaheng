# GAPS.md —— 各线缺口登记（每线只写自己的节；静默换语言/静默兜底禁止，缺口必须登记）

## kb 线（知识底座）

- **校验器实现语言 = Python，非 SLA**（2026-10-29）：kb 校验（JSON 解析 + 化学式递归下降解析 +
  守恒验算）属数据工程，本机 SLA 工具链虽可用（sa 0.1.8 冒烟过），但当前 SLA/std 无现成 JSON
  解析面，自建解析层会挤占数据正确性本身的工时，故 v0.1 校验器用 Python（`kb/tools/validate_kb.py`），
  按 README 纪律在此明示。SLA 化迁移条件：species 线 canon 与 found 线数据面就绪后，
  校验逻辑（解析器 + 守恒验算）应迁入 SLA 并进入常规门禁，Python 版退为对照实现。
- **能量数据（G°/H°）未收**：v0.1 知识底座只含 C1 层数据（化学式/组成/方程式/原子量）。
  核心演算的 C2 热力学一致性需要物种级 G°/H°，属后续阶段；补收时必须逐条带 `measured:<ref>`
  文献溯源，不许以 `assumed` 批量填充。
- **高分子与混合物未建模**：淀粉 (C6H10O5)n、蛋白质、空气、各类溶液无固定化学式，
  v0.1 不收为 species；需要时按草案 agent/opaque 形态另立契约（候主会话）。
- **教材版本差异**：本集以人教版通行口径为准；已知分歧点（偏铝酸钠表述等）以回避或
  离子式建模处理并在 kb/README.md 存疑清单登记。目标版本若被指定为其他版本，须整集复核。
- **方程式 conditions 为自由文本**（点燃/加热/催化剂/光照等未枚举化）：结构化条件
  （与 lang 线表层语法对齐）候后续契约修订，本线不私自定枚举。

## found 线（精确数与量纲）

- **零 Python 声明（用户 2026-10-29 22:55 新规）**：本线交付物无任何 Python
  文件、无 Python 运行时依赖；校验与测试全部在 SLA 语料内完成，运行脚本
  `found/run_tests.sh` 为 bash 薄封装（与 sa_plugin_sla 自家
  run_tests_batched.sh 同形态，只排序调用 `sla` 并断言证据行）。开发过程中
  曾用一次性文本脚本调整源码格式（分号风格），未入仓、非交付物，新规到达
  后已停用，后续格式修正全部手工完成。
- **SAB 后端缺口：`String.as_bytes()` 在 SAB 后端报 UnknownRegister**
  （trap 1007）：found 语料（含字符串解析的用例）在 SAB 后端不可跑，
  故 `run_tests.sh` 固定 `--test-backend sa`（text 后端）。属编译器后端
  缺口，非本线可修；SAB 后端修复后应把语料切为双后端各跑一遍再升级口径。
- **text 后端验证器 PhiStateConflict（fam4 同族）**：String 绑定跨分支
  合并点改赋值（如 `let u = a.unit; if ... { u = b.unit; }`）在
  qty_add 处触发 trap 1015。本线已以 return 式选择助手
  （`qty_pick_unit`）绕行并通过；根因在 SA 验证器，登记于此备查。
- **`sla build-exe` 在本机不可用（>300 s 无产出）**：本线导入链展开后
  约数万行，2 核 VM 上 build-exe 全量 AOT 超时且无任何输出。负例证据
  因此改走测试运行器的 panic 路径（neg_*_test.sla 期望 [FAIL] +
  指定 panic 码），与诊断语料的通行判读方式一致；若将来 build-exe
  可用，可补独立可执行负例。
- **SLA 语言面约束（本线绕行记录，非缺口申报）**：`&&`/`||` 不短路
  （下标守卫须用嵌套 if）；String 无拼接/push_str/下标/索引，
  拼接走 `format("{}{}", ...)` 惯用法；`^self` 方法形态在本机构建上
  类型不合，本线统一用自由函数 + `&T` 参数。均已在源码注释中标注。
- **°C 语义约束不在本层**：绝对温度相加等物理无意义运算，本层只按
  K 做算术、不拦截；语义层拦截属 check 线职责（见 found/README.md）。

## lang 线（L0/L1 语言面）

- **零 Python 声明（用户 2026-10-29 22:55 新规）**：本线交付物无任何 Python
  文件、无 Python 运行时依赖。解析器 `heng_parse.sla` 与对拍 harness
  `run_tests.sla` 均为 SLA（+ 一个 SA 宏文件 `argv_fill.sa`）；无 shell
  封装脚本，构建/运行命令见 lang/README.md。新规到达前曾用一次性文本
  脚本做源码定位与批量改名（未入仓、非交付物），到达后已停用。
- **物种 id 为占位式 `formula1:<本体>@<电荷>`**：INTERFACE 备案的占位
  格式；species 线 canon（`canon1:<hex>`）就绪后只替换 id 生成函数，
  输出其余形状不变。同物种不同写法（C2H5OH / C2H6O）在本层是两个记录，
  是否同一物种由 species 线规范化 + `species_id_eq` 断言判定，本层不猜。
- **疑似 SLA 编译器缺陷：结构体按值传参/返回时大数组字段写丢失**：
  `PathB { bytes: [u8; 1024], len }` 按值传入函数后，对 `bytes` 的写仅
  前 8 字节生效、其余清零（len 字段却正确累加），最小复现见本线工作
  记录（papp 按值版）。本线已统一改 `&PathB`/`&St` 借用模式绕行；
  建议 SLA 线立缺陷单复核（若属编译器缺陷，按主仓纪律应带语料回归）。
- **SLA 语言面约束（本线绕行记录）**：① 无 `ptr + int` 算术，缓冲区
  一律 (基址, 偏移) 索引读（oput_span 模式）；② 字符串 slice 不能以
  `ptr` 形参跨函数边界（STR_PTR/STR_LEN 只对本地 slice 寄存器有效，
  传错即运行时段错误），字符串一律按 (ptr, len) 对传参、字面量在调用
  点展开；③ `&u64` 解引用不能直接参与算术（`*p + 1` 类型检查报
  borrow 标签不合），须先载入临时变量。
- **value_eq 的 expr 只存原文不求值**：按 INTERFACE 分工，`M(...)` 等
  表达式求值归 grade/check 线；lang 只做词法捕获与原文透传。
- **v0.1 规模上限**（超出响亮报 E_COMPLEX，不静默截断）：输入 ≤ 4 MiB、
  物种 ≤ 192、元素 ≤ 96、组成条目 ≤ 2048、单物种不同元素 ≤ 64；
  一行一条语句、不续行（刻意保持语法小，见 lang/GRAMMAR.md §8）。

## check 线（C1 检验层）

- **零 Python 声明（用户 2026-10-29 22:55 新规）**：本线交付物无任何 Python
  文件、无 Python 运行时依赖；测试即 SLA 语料（`check/tests/*.sla`），以
  `sla test` 原生命令运行，无脚本封装（运行口径见 check/README.md）。
  新规到达前曾用一次性文本脚本做源码格式调整（未入仓、非交付物），
  到达后已停用，后续修正全部手工完成。
- **有理数为自备 i64 分数实现，待切换 found 线 rational**：found/ 的
  rational 就绪前，本线以 `check/rat.sla`（Rat{n,d}，恒约分、分母恒正、
  除零响亮 panic）+ c1.sla 内的 (num, den) 对运算顶替；判定逻辑
  （配平求解 RREF、相对分子质量）全部在精确有理数上完成，无浮点。
  found 线交付后应把 Rat 切换为其 rational 类型（签名已尽量同形）。
- **化合价模型 v0.1 边界**：同一元素在同一物种内只取一个价态做候选
  分配搜索——混合价态化合物（如 Fe3O4）不在模型内；有机式不适用
  化合价规则（葡萄糖在本模型内无分配、响亮失败，语料已固化）。
  氢只取 +1（初中口诀口径）：收 -1 会让 H 的负价自由度给有机式凑出
  伪分配；金属氢化物（如 NaH）非初中内容、出界时响亮失败并附模型注记。
  原子团（根）价态数据已备在 `check/data/valence_table.txt` 仅供参照，
  根级校验（如把 SO4 整体作根验价）未做，候后续迭代。
- **化学式解析面 v0.1 边界**：元素 + 计数 + 圆括号嵌套；不支持点式
  水合物（CuSO4·5H2O）与方括号配位式，遇到即解析失败响亮报错，
  不产半成品 composition。物种身份未对接 species 线 canon：本线按
  INTERFACE 许可以 formula 级解析消费 SpeciesRecord（formula + charge），
  composition 本身与 canon 产出一致，id 对接候集成期。
- **规模上限（超出响亮 panic，不静默截断）**：方程式每侧 ≤ 8 项
  （panic 3101/3102）；配平求解物种总数 ≤ 12；元素全集为数据表 36 种，
  表外元素解析期响亮失败。
- **SLA/SAB 前端实证缺口（本线绕行记录，均有最小形状留档于本线工作过程）**：
  ① 含大定长数组的结构体**按值传参**内容被截断（`{[i64; 36]}` 仅头部
  可信；与 lang 线登记的「写丢失」疑似同族）；② 从函数返回的结构体中
  **按值移出其大数组字段**（`S { comp: r.comp }` 形态）头部之后损坏。
  本线纪律：大结构体一律 & 借用读、本地构造后整体移动、借用出参填充。
  ③ **经借用嵌套读内层数组字段（`o.inner.counts[e]`）位于 while 循环体
  内时 SAB 报 PhiStateConflict（trap 1015）**；&Comp 直借循环读无恙——
  本线以「循环外先绑 &Comp 直借、辅助函数收 &Comp」绕行。
  ④ `Vec<T>` 链接失败（undefined `sa_vec_free`）：本线全用定长数组 + 长度字段。
  ⑤ `println` 的 `{}` 对 **ptr 变量**参数打印为空（字面量直传与数字
  参数正常）：报告行改用 `sa_print_bytes` + `sa_fmt_i64` 句柄自备打印层。
  ⑥ `sla test` 吞测试内 println（可读证据须经 `sla build-exe` 的 demo
  程序）；且 `sa` 不在 PATH 时 `sla test` 报错却 rc=0（宿主假绿），
  判读必须读输出内容而非 rc。⑦ `@import` 符号可见性只穿一层：隔两层
  的符号在下游文件报 UndefinedVariable，模块组织须留意。
  ⑧ `sla build-exe --out <file>` 不被接受（error[SA-CLI-014]），
  产物落在 `.sla-cache/sab/<name>-<hash>`。
