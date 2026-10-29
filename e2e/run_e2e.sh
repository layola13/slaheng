#!/bin/sh
# run_e2e.sh —— 衡 v0.1 端到端一题（集成线）：.heng 学生作答 -> lang 解析
# -> adapt 适配 -> grade 判分（内部经 check 线 C1 口径）-> VerdictReport。
# 产物落 e2e/out/：lang_*.json / answer_*.json / verdict_*.json。
# 验证：对答 all_pass=true；错答 all_pass=false 且 detail 指出氧不守恒。
# 工具链环境配方与各线 README 一致（local-sa sla 插件）。
set -eu
cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
export LD_LIBRARY_PATH="$HOME/workspace/local-tools/llvm14/extracted/usr/lib/x86_64-linux-gnu"
export PATH="$HOME/workspace/local-sa/zig17:$HOME/workspace/local-sa/sci/zig-out/bin:$HOME/workspace/gosyntax-local/sla-plugin/zig-out/bin:$PATH"
export SA_STD_DIR="$HOME/workspace/local-sa/sci/sa_std"
export SA_PLUGIN_DEV=1
mkdir -p out bin

# --- lang 解析器（缺失才构建） ---
PE=$(find "$ROOT/lang/.sla-cache/sab" -maxdepth 1 -type f -name 'heng_parse-*' ! -name '*.sab' ! -name '*.bc' 2>/dev/null | head -1)
if [ -z "$PE" ]; then
  (cd "$ROOT/lang" && sla build-exe heng_parse.sla >/dev/null)
  PE=$(find "$ROOT/lang/.sla-cache/sab" -maxdepth 1 -type f -name 'heng_parse-*' ! -name '*.sab' ! -name '*.bc' | head -1)
fi
# --- 适配器 ---
if [ ! -x bin/adapt ]; then
  sla build-exe adapt.sla >/dev/null
  AP=$(find .sla-cache/sab -maxdepth 1 -type f -name 'adapt-*' ! -name '*.sab' ! -name '*.bc' | head -1)
  cp "$AP" bin/adapt
fi
# --- grade CLI（grade 线已构建产物） ---
GE="$ROOT/grade/bin/grade"
[ -x "$GE" ]

for v in ok bad; do
  "$PE" "answer_$v.heng" > "out/lang_$v.json"
  ./bin/adapt "out/lang_$v.json" L0-e2e-001 "out/answer_$v.json"
  "$GE" problem.json "out/answer_$v.json" > "out/verdict_$v.json"
  echo "--- verdict_$v.json ---"
  cat "out/verdict_$v.json"
done

grep -q '"all_pass":true' out/verdict_ok.json
grep -q '"all_pass":false' out/verdict_bad.json
grep -q '元素 O 未守恒：左侧共 2 个，右侧共 1 个' out/verdict_bad.json
echo "E2E PASS: 对答 all_pass=true；错答 all_pass=false 且 detail 指出氧不守恒"
