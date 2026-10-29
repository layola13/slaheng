# found/ —— 精确数与量纲（衡引擎基础层）

全 SLA 实现，零浮点判定：一切数值判定走任意精度整数与有理数，
浮点不出现在任何代码路径中（连十进制导入都是逐位精确构造）。

## 文件

| 文件 | 内容 |
|---|---|
| `bigint.sla` | 任意精度有符号整数：符号 + 小端 base-2^32 limb 数组，零 = 空数组 |
| `rational.sla` | 规范化有理数 p/q（分母恒正、gcd=1、零 = 0/1） |
| `quantity.sla` | 7 元量纲向量 + Quantity（SI 归一化有理数值 + 显示单位名） |
| `test_bigint.sla` / `test_rational.sla` / `test_quantity.sla` | 正例语料（6 + 5 + 5 项） |
| `neg_dim_test.sla` / `neg_unit_test.sla` | 负例语料：期望响亮 panic（8303 / 8301） |
| `run_tests.sh` | 一键运行：check 三库 + 跑全部语料 + 断言负例 panic 码 |

运行：`bash found/run_tests.sh`（需本机 SLA 工具链路径，见脚本头部
环境变量 `HENG_SLA` / `HENG_SA_BIN` / `HENG_ZIG_BIN` 可覆盖）。

## API 摘要

### bigint（前缀 `bi_`）

`bi_from_i64` / `bi_from_u64` / `bi_parse_decimal`（非法输入 panic 8105）/
`bi_to_decimal_string` / `bi_add` / `bi_sub` / `bi_mul` / `bi_divmod`
（向零截断，余数随被除数符号）/ `bi_gcd` / `bi_cmp`。
乘法为朴素 O(n²)，除法为逐位长除——教育规模（摩尔质量、配平系数）
绰绰有余，不做 Karatsuba/FFT。

### rational（前缀 `rat_`）

`rat_make(num, den)`（den=0 panic 8201）/ `rat_from_i64` /
`rat_parse`：接受 `"p/q"`、`"12.34"`、`"42"`、`"-0.5"` 四种形态，
**精确导入**——`"0.1"` 就是 1/10，`"123456789123456789.5"` 就是
246913578246913579/2，全程不经浮点。
`rat_add` / `rat_sub` / `rat_mul` / `rat_div`（除零 panic 8202）/
`rat_cmp`（交叉相乘精确比较）/ `rat_to_string`（`"p/q"`，整数时省分母）/
`rat_to_decimal_string(max_places)`——**仅供显示：截断不舍入**，
判定永远用 `rat_cmp`，不许拿显示串做判定。

### quantity（前缀 `qty_` / `dim_`）

- `Dim`：7 个 i32 指数（kg, m, s, A, K, mol, cd）。`dim_add`/`dim_sub`
  合成乘除量纲，`dim_eq` 判同量纲，`dim_to_string` 输出如
  `kg*m^2*s^-2`、无量纲输出 `1`。
- `Quantity { si, dim, unit }`：`si` 为归一化到 SI 基本单位的有理数
  值；`unit` 为显示单位名（乘除结果为合成量纲时为空串，`qty_to_string`
  回退为 SI 值 + 量纲串）。
- `qty_parse(value_str, unit_name)` / `qty_make(Rational, unit_name)`：
  未知单位 panic 8301。
- `qty_value_in(q, unit)`：换回指定单位的有理数；量纲不符 panic 8302。
- `qty_add` / `qty_sub`：异量纲 panic 8303（响亮报错，无静默兜底）。
- `qty_mul` / `qty_div`：量纲合成。`qty_cmp`：异量纲 panic 8304。

### 单位表（`unit_lookup`，35 项）

SI 基本与导出：kg, m, s, A, K, mol, cd, J, kJ, MJ, N, W, Pa, kPa；
中学常用：g, mg, t, km, cm, mm, min, h, mA, L, mL, cm3；
复合：mol/L, g/mol, g/cm3, kg/m3, m/s, km/h。
换算因子全部为有理数（如 km/h = 5/18 m/s，g = 1/1000 kg）。

### °C 注记（重要）

°C 是**仿射**单位：存储时按 `K = °C + 5463/20`（即 +273.15，精确有理数）
归一化，`qty_value_in(q, "°C")` 时减回。由此 25 °C = 298.15 K 精确成立。
但两个绝对温度相加在物理上无意义——本层只做算术（经 K 相加），
语义约束（温度差须用 K、绝对温度不可相加）属上层 check 线职责，
本层不静默拦截。此点与 GAPS 登记一致。

## 契约对位（INTERFACE.md）

Quantity JSON 形态 `{"value": "p/q", "unit": "..."}` 中的 value 即
`rat_to_string` 输出、unit 即单位表名；量纲 7 元向量与 `Dim` 一一对应；
错误一律 panic 码响亮失败（81xx bigint / 82xx rational / 83xx quantity），
无静默兜底、无浮点判定。
