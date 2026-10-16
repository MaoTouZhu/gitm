#!/usr/bin/env bash
# 并发锁：串行化、超时、陈旧锁清理

sandbox

# ---------- 基本：运行中锁存在，结束后释放 ----------
sandbox
"$GITM" A.git init >/dev/null 2>&1
git --git-dir=A.git config alias.slow '!sleep 1'
"$GITM" A.git slow >/dev/null 2>&1 &
slow_pid=$!
sleep 0.4
ok_exists     "运行中持有工作目录锁" .gitm.workdir.lock
ok_exists     "运行中持有仓库锁"     A.git/.gitm.repo.lock
wait "$slow_pid"
ok_not_exists "结束后释放工作目录锁" .gitm.workdir.lock
ok_not_exists "结束后释放仓库锁"     A.git/.gitm.repo.lock

# ---------- 不同仓库之间串行（工作目录锁） ----------
"$GITM" B.git init >/dev/null 2>&1
git --git-dir=A.git config alias.slow '!sleep 2'
"$GITM" A.git slow >/dev/null 2>&1 &
a_pid=$!
sleep 0.4
out="$("$GITM" B.git status 2>&1 >/dev/null)"
ok_rc       "等待中的调用最终成功" "$?" "0"
ok_contains "等待时给出提示"       "$out" "正在等待"
wait "$a_pid"

# ---------- 陈旧锁自动清理 ----------
mkdir -p .gitm.workdir.lock
printf '999999\n' > .gitm.workdir.lock/pid
"$GITM" A.git status --porcelain >/dev/null 2>&1
ok_rc         "陈旧锁被清理后可正常运行" "$?" "0"
ok_not_exists "陈旧锁不再残留"           .gitm.workdir.lock

# 无 pid 文件的锁同样视为陈旧
mkdir -p .gitm.workdir.lock
"$GITM" A.git status --porcelain >/dev/null 2>&1
ok_rc         "无 pid 的锁被视为陈旧" "$?" "0"
ok_not_exists "无 pid 的锁已被清理"   .gitm.workdir.lock

# ---------- 超时 ----------
mkdir -p .gitm.workdir.lock
printf '%s\n' "$$" > .gitm.workdir.lock/pid      # 自己持有 => 活锁
GITM_LOCK_TIMEOUT=3 "$GITM" A.git status >/dev/null 2>&1
ok_rc "GITM_LOCK_TIMEOUT 生效" "$?" "1"
rm -rf .gitm.workdir.lock

# 超时值为非整数 -> 退回不限时且不报 bash 错误
GITM_LOCK_TIMEOUT=abc "$GITM" A.git status >/dev/null 2>&1
ok_rc "非整数超时值不导致崩溃" "$?" "0"
out="$(GITM_LOCK_TIMEOUT=abc "$GITM" A.git status 2>&1)"
ok_contains "非整数超时值给出提示" "$out" "GITM_LOCK_TIMEOUT"

# ---------- 同一仓库并发调用都能成功（不会因冲突直接失败） ----------
git --git-dir=A.git config alias.slow '!sleep 1'
"$GITM" A.git slow >/dev/null 2>&1 &
p1=$!
sleep 0.3
"$GITM" A.git slow >/dev/null 2>&1
ok_rc "同仓库并发调用不再互相失败" "$?" "0"
wait "$p1"

finish
