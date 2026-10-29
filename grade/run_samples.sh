#!/bin/sh
# 样例题包验收：逐题跑 grade -> verdict，再由 verify（SLA）与 expect 比对。
# 本脚本只做顺序编排；一切判定/比对逻辑在 grade.sla 与 verify.sla 内（零 Python）。
# 退出码：0 = 8 个用例全过；否则为失败用例数。
cd "$(dirname "$0")"
./run_grade.sh >/dev/null 2>&1 || true

fails=0
total=0
for d in problems/p1_balancing problems/p2_species problems/p3_mr problems/p4_valence; do
    for a in ok bad; do
        total=$((total + 1))
        ./bin/grade "$d/problem.json" "$d/answer-$a.json" > "/tmp/heng-grade-verdict-$a.json"
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "CASE FAIL $d answer-$a: grade 退出码 $rc"
            fails=$((fails + 1))
            continue
        fi
        if ./bin/verify "/tmp/heng-grade-verdict-$a.json" "$d/expect-$a.json"; then
            :
        else
            echo "CASE FAIL $d answer-$a"
            fails=$((fails + 1))
        fi
    done
done
echo "samples: $((total - fails))/$total passed"
exit $fails
