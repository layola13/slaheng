#!/bin/sh
# 构建 grade 判分器与 verify 验收器到 grade/bin/，并以给定参数运行 grade。
# 用法： ./run_grade.sh <problem.json> <answer.json>
# 工具链为本机布局（见 README「构建与运行」）；缓存目录 .sla-cache 不入库。
set -e
cd "$(dirname "$0")"

SA_BIN_DIR="$HOME/workspace/local-sa/sci/zig-out/bin"
SLA="$HOME/workspace/local-sa/sa_plugin_sla/zig-out/bin/sla"
export PATH="$HOME/workspace/local-sa/zig17:$SA_BIN_DIR:$PATH"
export SA_STD_DIR="$HOME/workspace/local-sa/sci/sa_std"

mkdir -p bin
if [ ! -x bin/grade ] || [ src/grade.sla -nt bin/grade ]; then
    "$SLA" build-exe src/grade.sla >/dev/null
    for f in .sla-cache/sab/grade-*; do
        case "$f" in
            *.sa.bc|*.sab) ;;
            *) cp "$f" bin/grade ;;
        esac
    done
fi
if [ ! -x bin/verify ] || [ src/verify.sla -nt bin/verify ]; then
    "$SLA" build-exe src/verify.sla >/dev/null
    for f in .sla-cache/sab/verify-*; do
        case "$f" in
            *.sa.bc|*.sab) ;;
            *) cp "$f" bin/verify ;;
        esac
    done
fi

exec ./bin/grade "$@"
