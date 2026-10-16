#!/usr/bin/env bash
# 命令透传 / 忽略语义 / 边界情况

# ---------- 命令透传 ----------
sandbox
printf '*.log\n' > .gitignore
printf 'v1\n' > foo.txt
printf 'x\n' > other.txt
"$GITM" foo.txt init >/dev/null 2>&1
"$GITM" foo.txt add -f foo.txt .gitignore >/dev/null 2>&1
"$GITM" foo.txt commit -qm base >/dev/null 2>&1

"$GITM" foo.txt status --porcelain >/dev/null 2>&1
ok_rc "status 可用" "$?" "0"
"$GITM" foo.txt log --oneline >/dev/null 2>&1
ok_rc "log 可用" "$?" "0"
"$GITM" foo.txt show --stat HEAD >/dev/null 2>&1
ok_rc "show 可用" "$?" "0"
"$GITM" foo.txt diff HEAD >/dev/null 2>&1
ok_rc "diff 可用" "$?" "0"
"$GITM" foo.txt rev-parse --git-dir >/dev/null 2>&1
ok_rc "rev-parse 可用" "$?" "0"
"$GITM" foo.txt branch -a >/dev/null 2>&1
ok_rc "branch 可用" "$?" "0"
"$GITM" foo.txt ls-files >/dev/null 2>&1
ok_rc "ls-files 可用" "$?" "0"

# 命令输出确实来自该仓库
ok "rev-parse 返回该 git-dir" "$("$GITM" foo.txt rev-parse --git-dir 2>/dev/null)" "foo.txt.git"
ok "log 能看到该仓库的提交" "$("$GITM" foo.txt log --oneline 2>/dev/null | wc -l | tr -d ' ')" "1"

# ---------- 忽略语义 ----------
ok "info/exclude 里有 *" "$(grep -qxF '*' foo.txt.git/info/exclude && echo yes || echo no)" "yes"
ok "'*' 使其它未跟踪文件不可见" "$(gitd foo.txt.git status --porcelain)" ""
"$GITM" foo.txt add . >/dev/null 2>&1
ok "add . 不会误加被忽略的文件" "$(gitd foo.txt.git diff --cached --name-only)" ""

# 用户 .gitignore 与 '*' 叠加生效
sandbox
printf '*.log\n' > .gitignore
printf 'v1\n' > foo.txt
printf 'noise\n' > x.log
printf 'other\n' > other.txt
"$GITM" foo.txt init >/dev/null 2>&1
"$GITM" foo.txt add -f foo.txt .gitignore >/dev/null 2>&1
"$GITM" foo.txt commit -qm base >/dev/null 2>&1
ok "用户 .gitignore 与 * 叠加后不可见" "$(gitd foo.txt.git status --porcelain)" ""
"$GITM" foo.txt add -f other.txt >/dev/null 2>&1
ok_rc "强制 -f 仍可跟踪被忽略的文件" "$?" "0"
ok "强制加入后出现在索引" "$(gitd foo.txt.git diff --cached --name-only)" "other.txt"

# ---------- gitm 不改写工作区文件 ----------
sandbox
printf '*.log\n' > .gitignore
printf 'v1\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
"$GITM" foo.txt add -f foo.txt .gitignore >/dev/null 2>&1
"$GITM" foo.txt commit -qm base >/dev/null 2>&1
before="$(md5sum .gitignore | cut -d' ' -f1)"
for c in status log diff branch; do "$GITM" foo.txt "$c" >/dev/null 2>&1; done
after="$(md5sum .gitignore | cut -d' ' -f1)"
ok "普通命令不改写 .gitignore" "$([ "$before" = "$after" ] && echo same || echo changed)" "same"
ok_not_exists "不产生 .gitignore.bak 备份文件" .gitignore.bak

# ---------- 边界 ----------
sandbox
"$GITM" missing.git status >/dev/null 2>&1
ok_rc "不存在的仓库返回非 0" "$([ $? -ne 0 ] && echo err || echo ok)" "err"
ok_not_exists "不存在的仓库不留下 .gitignore" .gitignore

mkdir -p fake.git
"$GITM" fake.git status >/dev/null 2>&1
ok "目录不是仓库时返回非 0" "$([ $? -ne 0 ] && echo err || echo ok)" "err"
ok_not_exists "不是仓库的目录不被塞锁" fake.git/.gitm.repo.lock

out="$("$GITM" 2>&1)"
ok_rc "缺少参数返回 1" "$?" "1"
ok_contains "缺少参数打印用法" "$out" "用法"

# 多余参数原样透传（以 gitm 不认识的子命令为例）
"$GITM" missing.git no-such-subcommand >/dev/null 2>&1
ok "未知子命令返回非 0" "$([ $? -ne 0 ] && echo err || echo ok)" "err"

finish
