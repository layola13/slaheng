# CONCURRENCY.md —— 衡引擎内部运行时并发：设计条款 → 实现决策映射

本文件是衡期二首项「引擎内部运行时并发」的立项与验收依据（用户
2026-10-30 08:30 批准先行，并明示「必须要符合引擎设计文档」）。
v0.1 运行时为纯顺序管线（parse→adapt→grade、kb 逐条串行校验），设计层
的并发意图未落地；本线只补运行时调度形态，**判定语义与输出字节零变化**。

## §1 设计条款 → 实现决策

| # | 设计条款（出处） | 条款要义 | 本线决策 |
|---|---|---|---|
| 1 | 草案 §0 公理 3「无序」：物理层内声明顺序不影响语义 | 求值顺序不是语义的一部分 | 独立判定单元可任意顺序/并行求值，结果不变（D1、D3） |
| 2 | 草案 §2.4：程序的指称 = 轨迹空间上的概率测度 𝓟；所有观察都是对 𝓟 的查询 | 结果是输入的纯函数式指称，不依赖执行轨迹 | 判定结果只由输入决定；调度、线程数、完成顺序禁止进入输出（D3） |
| 3 | 草案 §3 卷首：C1/C2 是**逐规则**的局部检查；C3–C6 是全网络结构分析 | 逐条检查彼此独立；全局分析是汇合点 | 并发单位 = 逐条（断言/答卷/条目）；全局聚合留主程顺序合并（D1、D4） |
| 4 | 草案 §4.3：C1/C2 逐规则、与上下文无关，组合后保持 | 独立验证过的单元可直接拼接 | 各 worker 的判定结果按索引拼接即得全局结果，无需复检（D3） |
| 5 | 草案 §4.4：retroactivity 使**动力学**不组合 | 耦合只存在于共享物种的动力学层面 | 本线并发只用于输入封闭的判定（一份答卷、一条条目），其输入是只读题面/kb，判定间不存在负载耦合；单个模型内部的动力学并发不在本线（属期三模拟层） |
| 6 | 草案 §5.2 + sala 20 一节：每个判定结果附带方法与假设集合（C6 溯源） | 结论必须携带 provenance | provenance 在 worker 内随判定产生、合并时原样保留，不因并发改写（D5） |
| 7 | sala 20 三节 ECS 裁决：系统 = 演算与判分过程；「系统可按实体集并行，与模拟层的 goroutine 轨迹并行同路」；ECS 是世界模型层、不取代核心演算 C1–C6 | 并发的合法形态 = 系统扫过实体集 | 判分系统/校验系统以 goroutine 并行扫过实体集（答卷集、条目集）；本线落的是该运行时形态，世界模型层的 sla_ecs 代码迁移不在本线，C1–C6 判定函数零改动（D5） |
| 8 | sala 20 三节「模拟层借运行时、不借语义」：SMC 成千上万条独立轨迹借 goroutine 运行时承载 | 独立轨迹借 goroutine 是设计内先例 | 独立判定同构借 goroutine 运行时（sa_std task/Chan），不借任何外部线程库 |
| 9 | sala 20 三节呈现纪律：「判定永不依赖渲染」 | 推论：判定永不依赖任何非输入因素 | 聚合必须确定性：按原索引定序合并；禁止按完成顺序输出（D3） |
| 10 | sala 20 三节建议管线序：解析 → 规范化 → 脱糖（C5 挂脱糖前）→ C1–C6 → 网络生成，阶段序固定 | 阶段间依赖不可乱序 | 并发只在阶段**内**；阶段间以 join 为屏障顺序衔接（D4：kb 物种登记全部合并后才进方程式校验） |
| 11 | INTERFACE.md：VerdictReport 的 results 按 assertion_index 排列；语义纪律「错误一律响亮：不静默兜底、不默认 0、不跳过」 | 输出形态与失败形态都是契约 | 合并按索引定序；worker panic 即整批响亮失败；批量面中单份硬错误呈现为该份的 `{"error"}` 行（新契约，见 grade/README），不吞、不跳（D6） |
| 12 | INTERFACE.md 语义纪律：数值不用浮点做判定（走 rational） | 并发不得改变算术路径 | 同一判定函数、同一输入、同一代码路径；并发只改变调用者与时机（D5） |

## §2 实现决策（D1–D6）

- **D1 并发单位**：grade = 一份（题目， 答卷）对的完整判定（含渲染）；
  kb = 一条条目的逐条校验。phase 4（species/fact 校验 + 物种登记）与
  phase 5（方程式校验）各自成段并行，段内按条目分片（连续区间）。
- **D2 只读共享面**：题目/答卷/kb 数据的文件字节（各 worker 私有解析
  一份）；phase 5 读的物种登记表（phase 4 合并产物，worker 只读拷入
  本地）。除下方 D3 的独占结果槽外，worker 不写任何其他 worker 或
  主程可见的内存；不存在共享可变状态，也就不存在锁与竞态面。
- **D3 确定性聚合**：每个 worker 只写自己独占的结果槽（Box 构造、
  主程持有）；主程 join 全部 worker 后，按原索引顺序拼接各槽字节
  产出最终输出。完成先后不影响任何字节。
- **D4 阶段屏障**：kb 登记（phase 4 的副作用）是 phase 5 的输入。
  phase 4 全部 join → 登记按分片序合并（保持全局条目序，使
  `species_lookup` 的「后登记者胜」语义与顺序版逐字一致）→ 才 spawn
  phase 5。grade 各份判定无阶段间依赖，单段并行。
- **D5 判定函数零改动**：并发只改变「谁在何时调用判定函数」。grade 的
  `judge_one/judge_balanced/judge_value_eq/judge_species_eq` 与 check
  C1、kb 的 `check_species/check_fact/check_equation` 源码零改动；
  grade 单答卷 CLI 行为与输出与 v0.1 逐字节一致（其 main 的增量打印
  改为等价的整段渲染后一次打印，字节流相同，由样例包 + e2e 对拍为证）。
- **D6 响亮失败**：worker 内 panic = 整进程响亮失败（与顺序版同级），
  不捕获、不降级为顺序重跑；不存在「并发失败则静默串行」的兜底路径。

## §3 编译器实证纪律（本机探针，2026-10-30，语法批工具链）

以下形态法则均由本线探针实测得出（探针程序与输出存本线工作记录）：

- **L1 spawn 入口约定 = `fn(ptr)`**：`go f(a, b)` 双参被类型检查器
  拒绝（原文：`the goroutine entry convention is fn(ptr) - wrap the
  arguments in a heap struct (Box) and pass its pointer`）。多参一律
  打包 `*Job`；单参（Chan、`*T`）可直传。
- **L2 `&(*ptr)` 还借不可用**：探针 5 实测 `sum_of(&(*sp))` 读出垃圾
  值（814665553），同数据 `(*sp).vals[i]` 直读为 36。**禁止**把共享
  结构以 `&(*ptr)` 还借给 `&` 形参函数；跨 goroutine 共享只许
  `(*ptr).field` 直读直写，或在 worker 帧内构造私有值后以本地 `&`
  调用既有 API（v0.1 顺序形态在 worker 内的复刻）。
- **L3 大结构体不按值过界**（DEF-1，在案）：Job/结果槽只放指针与
  标量；大缓冲（kb OutB、grade RBuf）由 worker 在本帧内私有构造、
  结果字节以 `(*slot).bytes[i]` 直写拷回独占槽，不经 Chan、不按值返回。
- **L4 Chan 负载走运行时 16 字节槽 + 所有权转移**（语料
  test_unit_go_chan 头注）：大结果不走 Chan；Chan 只作小消息/同步用。
  本线 grade/kb 均以 join + 结果槽聚合，未用 Chan 传结果。
- **L5 while 块后不跟 `;`**（AGENTS.md 既有纪律，探针复现）。
- **DEF-KB-1（新登记，编译器缺陷，候 SLA 编译器线/DEF-1/DEF-2 线）**：
  「结构体 Vec 字段索引赋值」在控制流合并点产生能力状态不一致的
  phi，sa 的 SAB 验证器以 **trap 1015 PhiStateConflict** 拒绝。两种
  触发形态均实测：① if/else 两分支分别写同一结构体两个不同 Vec
  字段（kb/tools/json.sla 原 j_parse_array/j_parse_object，SAB 合并
  点 L_MERGE）；② while 循环体内单一 Vec 字段索引赋值（循环头 phi：
  入口 Uninitialized vs 回边 Composite；species tests_species 在
  本地同陷此形态）。归因判别（2026-10-30 本地，证据链完整）：同一
  test_json 源码在 **四种组合**（sla 6004af4 / era sla 33629b75 ×
  companion sa e7c18568 / era sa 870cda60，全部本地重编）下**全部**
  被拒，且 register/line 逐一相同 → 与 sla/sci 版本无关；而同一源码
  在 2026-10-29/30 盒上 era 组合实测全过（kb 报告字节稳定、species
  20/20）。剩余变量 = 构建环境（本机以提取 .deb 的 LLVM-14 垫片 +
  zig cc 包装重编 vs 盒上原生构建）或验证器对构建产物的隐性依赖，
  本线不下结论，原始证据（四组合 trap JSON、最小复现）随终报交
  DEF-1/DEF-2 编译器线（其章程含 SAB 验证器根因）在盒上原生工具链
  复核。最小复现：`repro_vecset_loop.sla`（39 行自包含，本地实测
  trap 1015 于 SAB line 318；已附本线终报）。kb 侧影响：validate_kb
  与 test_json 在本地重编工具链下 build-exe/test 均被拒（`sla check`
  通过；grade 的 build-exe 与批量并发不受此形态影响、本地全绿）；
  kb 并发实现已落码且 check 通过，其二进制验收（报告 md5 对拍）
  待盒上原生工具链由主会话协调补跑（见 §5）。

## §4 工具链（本地重建，盒恢复后同法复核）

本机实例 CPU 无 `sha_ni`，盒上构建的 sa/sla 二进制在 std sha2 硬件
路径触发 SIGILL（证据：`Illegal instruction at …/std/crypto/sha2.zig:259`，
栈在 sci `resolver.zig packageTreeHash`，`sa build-exe` 任意输入 rc=132/134）。
故本线工具链全部改为**本地重建**（与语法批本地复证同法）：

- `toolchain-sci/`：sci companion 链 tip `e7c18568` 的本地克隆，
  `zig build` + `zig build sa-std-static`；`nm` 核 `sa_task_*` = 15 个
  `T` 符号（与集成门禁数一致）。
- `toolchain-sla/`：sa_plugin_sla 链 tip `6004af4` 的本地克隆，
  `SCI_ROOT=toolchain-sci` 下 `zig build`，产物 `zig-out/bin/sla`。
- 两目录是本地构建区，**不入库**（已登记 `.git/info/exclude`）；
  构建/运行环境见各 run 脚本注记：`SA_STD_DIR=toolchain-sci/sa_std`、
  `SA_PLUGIN_DEV=1`、`SLA_NO_FRESHNESS_CACHE=1`、编译器改动前清
  目标树 `.sla-cache`。

探针结论（先于实现，任务第二步）：**通**。
- probe_go：双 goroutine 经 `Chan<i64>` ping-pong 回传、主程收齐
  打印，输出 `PROBE a=30 b=40 sum=70`，连跑 6/6 次一致，rc=0。
- probe_job：`fn(ptr)` Job 打包（共享数组指针 + 区间 + 独占 out 格），
  双 worker 分片读、独占写，输出 `PROBE2 left=10 right=26 total=36`，
  3/3 次一致。

## §5 验收口径（四联判读 + 名字集）

- 并发版 vs 顺序版输出逐字节对拍（grade 样例 8 例 + e2e ok/bad +
  批量集 ≥16 份），重复 ≥5 轮全等；
- kb `validation_report.txt` 与基线 md5 一致
  （基线 `7a61820e1092f0dd60bcf374cdc1461a`），且 `RESULT ALL PASS`；
- 既有套件名字集不变：grade 8/8、check 1/1 + 23/23、species 20/20、
  lang 14/14、found 16 + 2 负例、e2e E2E PASS；
- 判读 = rc + 预期结果行 + 失败名字集为空，三者缺一不算过。

## §6 验收实绩（2026-10-30 本地）

- **grade：全项达成。** 拆分后 grade 与拆分前（HEAD 单体）同题输出
  8/8 逐字节相同、e2e ok 相同；verify 8/8 OK；`grade_batch` 构建
  成功，16 份混合清单（8 样例 + e2e 2 + 文件缺失 / pid 不一致 /
  坏 JSON 三种错误形态 + 重复 3 份）× 5 轮与单跑拼接逐字节全等
  （`run_batch_test.sh` PASS，批量 rc=1 符合契约）。
- **kb：实现落码、`sla check` 通过；二进制验收未跑**——本地重编工
  具链下 build-exe 被 DEF-KB-1（§3）阻塞，且阻塞点在未改动的
  json.sla（j_parse_array），不在并发新代码内（trap 定位经 SAB 反
  汇编确认）。待盒上原生工具链补跑：构建 validate_kb → 运行 →
  报告 md5 对拍 + test_json 7/7。
- 既有套件本地复跑实绩随终报：凡本地工具链可跑者按上列口径记录
  名字集；species 的 `sla test` 在本地同陷 DEF-KB-1（未改动源码），
  与 kb 一并待原生工具链复核。
