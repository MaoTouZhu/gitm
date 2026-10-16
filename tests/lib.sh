#!/usr/bin/env bash
#
# tests/lib.sh - 极简测试框架（由 run.sh 载入，不直接用 bash 跑）
#
# 提供:
#   sandbox       新建一个干净的工作目录并 cd 进去（每个用例前用）
#   ok DESC GOT WANT          断言相等
#   ok_contains DESC GOT WANT 断言包含子串
#   ok_not_contains DESC GOT WANT
#   ok_exists DESC PATH       断言存在
#   ok_not_exists DESC PATH   断言不存在
#   ok_rc DESC RC WANT        断言退出码
#   finish                    汇总本文件结果（文件末尾必须调用）

set -u

_pass=0
_fail=0
_results_file="${RESULTS_FILE:-}"

ok() {
    if [ "$2" = "$3" ]; then
        printf '  ✅ %s\n' "$1"
        _pass=$((_pass + 1))
    else
        printf '  ❌ %s\n       实际=[%s]\n       期望=[%s]\n' "$1" "$2" "$3"
        _fail=$((_fail + 1))
    fi
}

ok_contains() {
    case "$2" in
        *"$3"*) printf '  ✅ %s\n' "$1"; _pass=$((_pass + 1)) ;;
        *) printf '  ❌ %s\n       实际=[%s]\n       应包含=[%s]\n' "$1" "$2" "$3"; _fail=$((_fail + 1)) ;;
    esac
}

ok_not_contains() {
    case "$2" in
        *"$3"*) printf '  ❌ %s\n       实际=[%s]\n       不应包含=[%s]\n' "$1" "$2" "$3"; _fail=$((_fail + 1)) ;;
        *) printf '  ✅ %s\n' "$1"; _pass=$((_pass + 1)) ;;
    esac
}

ok_exists() {
    if [ -e "$2" ]; then
        printf '  ✅ %s\n' "$1"
        _pass=$((_pass + 1))
    else
        printf '  ❌ %s（路径不存在: %s）\n' "$1" "$2"
        _fail=$((_fail + 1))
    fi
}

ok_not_exists() {
    if [ ! -e "$2" ]; then
        printf '  ✅ %s\n' "$1"
        _pass=$((_pass + 1))
    else
        printf '  ❌ %s（路径不应存在: %s）\n' "$1" "$2"
        _fail=$((_fail + 1))
    fi
}

ok_rc() {
    if [ "$2" = "$3" ]; then
        printf '  ✅ %s（rc=%s）\n' "$1" "$2"
        _pass=$((_pass + 1))
    else
        printf '  ❌ %s\n       实际 rc=[%s]\n       期望 rc=[%s]\n' "$1" "$2" "$3"
        _fail=$((_fail + 1))
    fi
}

# gitd REPO ARGS... —— 以裸 git 身份操作某个 gitm 仓库（绕过 gitm 本身，用于校验落盘状态）
gitd() {
    repo="$1"
    shift
    git --git-dir="$repo" --work-tree=. "$@"
}

# 新建干净工作目录
sandbox() {
    _sb="$(mktemp -d "${TMPDIR:-/tmp}/gitm-test-XXXXXX")"
    _sandboxes="$_sandboxes $_sb"
    trap '_cleanup_sandboxes' EXIT
    cd "$_sb" || return 1
    printf '  ▸ 工作目录: %s\n' "$_sb"
}

# 新建一个受管理的临时目录（不 cd），路径输出到 stdout。
# 注意：本函数在命令替换的子 shell 中执行，所以不能在这里注册 EXIT trap
# （子 shell 一退出就会误删目录）。清理依赖 run.sh 把 TMPDIR 指向受管目录。
tmpdir() {
    mktemp -d "${TMPDIR:-/tmp}/gitm-test-XXXXXX"
}

# 退出时清掉本文件创建的所有沙箱（由 run.sh 在子 shell 中调用，trap 随子 shell 结束触发）
_sandboxes=""
_cleanup_sandboxes() {
    [ -n "$_sandboxes" ] && rm -rf $_sandboxes 2>/dev/null
    _sandboxes=""
}

finish() {
    printf '  ── 本文件: %d 通过 / %d 失败\n' "$_pass" "$_fail"
    if [ -n "$_results_file" ]; then
        printf '%s %s\n' "$_pass" "$_fail" > "$_results_file"
    fi
    _cleanup_sandboxes
    [ "$_fail" -eq 0 ]
}
