# lang —— 衡 · Heng L0/L1 语言面（表层语法 + 解析器 + 教学诊断）

## 文件

| 文件 | 内容 |
|---|---|
| `GRAMMAR.md` | 表层语法 v0.1 冻结本：EBNF、电荷消歧规则、输出 JSON 形状、诊断话术表、check 层衔接格式、预留扩展点 |
| `heng_parse.sla` | 解析器（SLA）：`.heng` → INTERFACE 的 SpeciesRecord/EquationRecord/Assertion JSON；`--hint` 模式渲染 check 层 balance_delta 教学句子 |
| `run_tests.sla` | 对拍 harness（SLA）：逐例跑解析器、比退出码与 stdout 全文 |
| `argv_fill.sa` | SA 宏：填充 process argv 数组（仿 sa_plugin_sla bridge demo 的 ARGV_FILL1；SLA 不许 ptr→u64 转型，故宏代劳） |
| `examples/` | 7 个正例 + 5 个错误例 `.heng`，每个带 `.expected.json` / `.expected.txt` 对拍基准 |

## 构建与运行

工具链环境（本机 local-sa）：

```bash
cd ~/workspace/heng/lang
export SA_STD_DIR=~/workspace/local-sa/sci/sa_std
export PATH=~/workspace/local-sa/zig17:~/workspace/local-sa/sci/zig-out/bin:$PATH
SLA=~/workspace/local-sa/sa_plugin_sla/zig-out/bin/sla

SA_PLUGIN_DEV=1 $SLA build-exe heng_parse.sla    # 产物 .sla-cache/sab/heng_parse-<hash>
SA_PLUGIN_DEV=1 $SLA build-exe run_tests.sla     # 产物 .sla-cache/sab/run_tests-<hash>

PE=$(find .sla-cache/sab -maxdepth 1 -type f -name 'heng_parse-*' ! -name '*.sab' ! -name '*.bc')
./$PE examples/ex01_photosynthesis.heng          # 成功：JSON，退出码 0
./$PE examples/err01_lowercase.heng              # 失败：教学诊断两行，退出码 1
./$PE --hint O 2 1                               # 氧（O）：左边有 2 个，右边只有 1 个，两边不一样多。
./$PE /不存在的路径.heng                          # 打不开：退出码 2

TE=$(find .sla-cache/sab -maxdepth 1 -type f -name 'run_tests-*' ! -name '*.sab' ! -name '*.bc')
./$TE $PE examples                               # 14 例对拍，全过打印 ALL PASS (14/14)，退出码 0
```

## 行为要点

- 缺系数 ≠ 系数 1：未写系数输出 `null`（待配平形态）；小数系数输出精确有理数字符串（`0.5` → `"1/2"`）。
- 物种 id 是 INTERFACE 备案的占位式 `"formula1:<本体>@<电荷>"`，canon 就绪后只换 id 生成、不动输出形状（见仓根 GAPS.md lang 节）。
- 诊断列号按字符计（中文算 1 列）；错误即响亮退出（码 1），不猜测修复、不静默兜底。
- v0.1 上限（超出报 E_COMPLEX）：输入文件 ≤ 4 MiB、物种 ≤ 192、元素 ≤ 96、组成条目 ≤ 2048、单物种不同元素 ≤ 64。
- 一行一条语句，不续行；能量/区室/协议不在 v0.1（GRAMMAR.md §8 预留位）。
