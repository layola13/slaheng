#!/bin/sh
# grade 批量并发验收：批量 stdout 必须逐字节等于各份单跑 grade 的 stdout
# 按清单序拼接（重复 5 轮全等）。本脚本只做顺序编排与比对（判定在 SLA 内）。
# 工具链可用 HENG_SA_BIN / HENG_SLA / HENG_ZIG_BIN 覆盖（默认本仓 toolchain-*，
# 见仓根 CONCURRENCY.md §4）。
set -u
cd "$(dirname "$0")"
SA_BIN_DIR="${HENG_SA_BIN:-$HOME/workspace/heng/toolchain-sci/zig-out/bin}"
ZIG_BIN_DIR="${HENG_ZIG_BIN:-$HOME/workspace/local-sa/zig17}"
SLA="${HENG_SLA:-$HOME/workspace/heng/toolchain-sla/zig-out/bin/sla}"
export PATH="$SA_BIN_DIR:$ZIG_BIN_DIR:$PATH"
export SA_STD_DIR="${SA_STD_DIR:-$HOME/workspace/heng/toolchain-sci/sa_std}"
export SA_PLUGIN_DEV=1
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-$HOME/workspace/local-tools/llvm14/extracted/usr/lib/x86_64-linux-gnu}"

W=/tmp/heng-batch-test
rm -rf "$W"; mkdir -p "$W"
fails=0

if [ ! -x bin/grade ] || [ src/grade.sla -nt bin/grade ] || [ src/grade_lib.sla -nt bin/grade ]; then
    rm -rf .sla-cache
    "$SLA" build-exe src/grade.sla >/dev/null || { echo "BUILD FAIL grade"; exit 1; }
    for f in .sla-cache/sab/grade-*; do case "$f" in *.sa.bc|*.sab) ;; *) cp "$f" bin/grade ;; esac; done
fi
if [ ! -x bin/grade_batch ] || [ src/grade_batch.sla -nt bin/grade_batch ] || [ src/grade_lib.sla -nt bin/grade_batch ]; then
    "$SLA" build-exe src/grade_batch.sla >/dev/null || { echo "BUILD FAIL grade_batch"; exit 1; }
    for f in .sla-cache/sab/grade_batch-*; do case "$f" in *.sa.bc|*.sab) ;; *) cp "$f" bin/grade_batch ;; esac; done
fi

# ---- 构造清单：8 样例 + e2e 2 + 3 错误形态 + 样例重复（共 16 份） ----
P=$PWD/problems
E=$PWD/../e2e
printf '{"problem_id":"WRONG-ID","items":[]}' > "$W/pid_mismatch.json"
printf 'not json' > "$W/bad.json"
{
  printf '[\n'
  sep=''
  add() { printf '%s{"problem":"%s","answer":"%s"}' "$sep" "$1" "$2"; sep=','; }
  for d in p1_balancing p2_species p3_mr p4_valence; do
    add "$P/$d/problem.json" "$P/$d/answer-ok.json"
    add "$P/$d/problem.json" "$P/$d/answer-bad.json"
  done
  add "$E/problem.json" "$W/e2e-answer-ok.json"
  add "$E/problem.json" "$W/e2e-answer-bad.json"
  add "$P/p1_balancing/problem.json" "$W/missing.json"
  add "$E/problem.json" "$W/pid_mismatch.json"
  add "$W/bad.json" "$P/p1_balancing/answer-ok.json"
  add "$P/p3_mr/problem.json" "$P/p3_mr/answer-ok.json"
  add "$P/p3_mr/problem.json" "$P/p3_mr/answer-bad.json"
  printf '\n]\n'
} > "$W/manifest.json"
# e2e 的 answer 形由 adapt 产物提供（与 e2e/out 一致的已存适配结果不行——
# 直接用仓内 e2e/out/answer_ok.json 作为输入数据）
cp "$E/out/answer_ok.json" "$W/e2e-answer-ok.json"
cp "$E/out/answer_bad.json" "$W/e2e-answer-bad.json"

# ---- 期望：逐份单跑拼接 ----
: > "$W/expected.txt"
for pair in \
  "p1_balancing ok" "p1_balancing bad" "p2_species ok" "p2_species bad" \
  "p3_mr ok" "p3_mr bad" "p4_valence ok" "p4_valence bad"; do
  set -- $pair
  ./bin/grade "problems/$1/problem.json" "problems/$1/answer-$2.json" >> "$W/expected.txt" || true
done
./bin/grade ../e2e/problem.json "$W/e2e-answer-ok.json" >> "$W/expected.txt" || true
./bin/grade ../e2e/problem.json "$W/e2e-answer-bad.json" >> "$W/expected.txt" || true
./bin/grade problems/p1_balancing/problem.json "$W/missing.json" >> "$W/expected.txt" || true
./bin/grade ../e2e/problem.json "$W/pid_mismatch.json" >> "$W/expected.txt" || true
./bin/grade "$W/bad.json" problems/p1_balancing/answer-ok.json >> "$W/expected.txt" || true
./bin/grade problems/p3_mr/problem.json problems/p3_mr/answer-ok.json >> "$W/expected.txt" || true
./bin/grade problems/p3_mr/problem.json problems/p3_mr/answer-bad.json >> "$W/expected.txt" || true

# ---- 批量 ×5 轮逐字节对拍 ----
r=1
while [ $r -le 5 ]; do
  ./bin/grade_batch "$W/manifest.json" > "$W/batch-$r.txt"
  brc=$?
  if [ $brc -ne 1 ]; then echo "ROUND $r: grade_batch rc=$brc（期望 1：含错误份）"; fails=$((fails+1)); fi
  if diff -q "$W/expected.txt" "$W/batch-$r.txt" >/dev/null; then
    echo "ROUND $r: byte-identical"
  else
    echo "ROUND $r: DIFF FOUND"; diff "$W/expected.txt" "$W/batch-$r.txt" | head -6; fails=$((fails+1))
  fi
  r=$((r+1))
done

if [ $fails -eq 0 ]; then
  echo "BATCH TEST PASS (16 jobs x 5 rounds byte-identical)"
else
  echo "BATCH TEST FAIL ($fails)"
  exit 1
fi
