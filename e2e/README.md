# e2e —— 衡 v0.1 端到端一题（集成线）

题 L0-e2e-001：氢气燃烧配平（balanced 断言）。学生作答以 .heng 文本
提交，经 lang 解析、adapt 适配、grade 判分（balanced 内部为 check 线
C1 口径），产出 VerdictReport。完整记录见仓根 INTEGRATION.md §5。

```bash
sh run_e2e.sh    # 产物落 out/，末行打印 E2E PASS 才算全程通过
```

- `problem.json`：题目（grade 形）。
- `answer_ok.heng` / `answer_bad.heng`：对/错两份学生作答（错答系数
  1,1,1，氧不守恒）。
- `adapt.sla`：lang 输出 -> grade answer 形的 SLA 适配器
  （用法 `adapt <lang.json> <problem_id> <out.json>`，失败响亮退出）。
- `out/`：lang_*.json（解析输出）、answer_*.json（适配结果）、
  verdict_*.json（判分报告）六份运行证据。
