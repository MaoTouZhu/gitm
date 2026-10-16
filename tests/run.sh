#!/usr/bin/env bash
#
# tests/run.sh - gitm 的测试入口
#
# 用法:
#   tests/run.sh                # 跑全部
#   tests/run.sh init clone     # 只跑 tests/t-init.sh 与 tests/t-clone.sh
#
# 每个测试文件在独立子 shell 中执行，结束后把计数写进结果文件汇总。
# 只要有一个断言失败，整体退出码为 1。

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
GITM="$(cd "$TESTS_DIR/.." && pwd)/gitm"
export GITM

if [ ! -x "$GITM" ]; then
    echo "找不到可执行的 gitm: $GITM" >&2
    exit 2
fi

# 隔离用户全局 git 配置，保证结果可复现
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=gitm-test
export GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=gitm-test
export GIT_COMMITTER_EMAIL=test@example.com

# 收集要跑的文件
if [ $# -gt 0 ]; then
    files=""
    for name in "$@"; do
        f="$TESTS_DIR/t-${name#t-}.sh"
        if [ ! -f "$f" ]; then
            echo "没有这个测试文件: $f" >&2
            exit 2
        fi
        files="$files $f"
    done
else
    files="$(ls "$TESTS_DIR"/t-*.sh 2>/dev/null | sort)"
fi

if [ -z "$(printf '%s' "$files" | tr -d ' ')" ]; then
    echo "没有找到任何 tests/t-*.sh" >&2
    exit 2
fi

RESULTS_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gitm-results-XXXXXX")"
trap 'rm -rf "$RESULTS_DIR"' EXIT

# 把所有测试沙箱都关进 RESULTS_DIR：即使某个用例漏了清理，退出时也随 RESULTS_DIR 一起删除
mkdir -p "$RESULTS_DIR/tmp"
export TMPDIR="$RESULTS_DIR/tmp"

total_pass=0
total_fail=0
failed_files=""
ran_files=0

for f in $files; do
    base="$(basename "$f")"
    echo
    echo "═══ $base ═══"
    rf="$RESULTS_DIR/$base.result"
    ( RESULTS_FILE="$rf"; . "$TESTS_DIR/lib.sh"; . "$f" )
    rc=$?
    ran_files=$((ran_files + 1))

    p=0; q=0
    if [ -f "$rf" ]; then
        read -r p q < "$rf"
    fi
    total_pass=$((total_pass + p))
    total_fail=$((total_fail + q))

    if [ "$rc" -eq 0 ] && [ "$q" -eq 0 ]; then
        echo "  → $base: 通过（$p 项）"
    else
        echo "  → $base: 失败（通过 $p，失败 $q）"
        failed_files="$failed_files $base"
    fi
done

echo
echo "════════════════════════════════════"
printf '文件: %d 个   断言: %d 通过 / %d 失败\n' "$ran_files" "$total_pass" "$total_fail"
if [ -n "$failed_files" ]; then
    echo "失败文件:$failed_files"
    exit 1
fi
echo "全部通过 ✅"
exit 0
