#!/usr/bin/env bash
# 安全与一致性：权限收紧、仓库配置一致、-list

# ---------- 权限：仓库与对象不应对其他用户可读 ----------
sandbox
(
    umask 022      # 故意用宽松 umask，验证 gitm 自己会收紧
    printf 'secret-token\n' > .netrc
    "$GITM" netrc init >/dev/null 2>&1
)
ok_rc "宽松 umask 下也能初始化" "$?" "0"
ok "仓库目录权限为 700" "$(stat -c %a netrc.git)" "700"
ok "仓库内没有「其他用户可读」的文件" "$(find netrc.git -perm -o+r | wc -l | tr -d ' ')" "0"

sandbox
(
    umask 000
    printf 'v\n' > a.txt
    "$GITM" a.txt init >/dev/null 2>&1
)
ok "umask 000 下对象仍不可被其他用户读" "$(find a.txt.git -perm -o+r | wc -l | tr -d ' ')" "0"

# ---------- 仓库配置一致性：init 与 clone 都应可用原生 git ----------
sandbox
make_remote src conf.git main a.txt 'a\n'
"$GITM" cl.git clone conf.git >/dev/null 2>&1
printf 'v\n' > b.txt
"$GITM" in.git init >/dev/null 2>&1

ok "clone 后 core.bare=false" "$(gitd cl.git config --get core.bare)" "false"
ok "init 后 core.bare=false"  "$(gitd in.git config --get core.bare)" "false"
ok "clone 后 core.worktree 指向当前目录" "$(gitd cl.git config --get core.worktree)" "$(pwd)"
ok "init 后 core.worktree 指向当前目录"  "$(gitd in.git config --get core.worktree)" "$(pwd)"
git --git-dir=cl.git status --porcelain >/dev/null 2>&1
ok_rc "原生 git（不带 --work-tree）可用 clone 出来的仓库" "$?" "0"
git --git-dir=in.git status --porcelain >/dev/null 2>&1
ok_rc "原生 git 可用 init 出来的仓库" "$?" "0"

# ---------- -list ----------
sandbox
printf 'v\n' > one.txt
"$GITM" one.txt init >/dev/null 2>&1
"$GITM" one.txt add -f one.txt >/dev/null 2>&1
"$GITM" one.txt commit -qm base >/dev/null 2>&1
printf 'v\n' > two.txt
"$GITM" two.git init >/dev/null 2>&1
git --git-dir=blank.git init -q --bare      # 真·空仓库

out="$("$GITM" -list)"
ok_rc "-list 退出码 0" "$?" "0"
ok_contains "-list 列出 one.txt.git" "$out" "one.txt.git"
ok_contains "-list 列出 two.git"     "$out" "two.git"
ok_contains "-list 列出 blank.git"   "$out" "blank.git"
ok_not_contains "-list 不把 .git 当作仓库" "$out" ".git/"

# 有改动的仓库会显示改动数
printf 'changed\n' >> one.txt
out="$("$GITM" -list)"
ok_contains "-list 显示改动数" "$out" "1 处改动"
ok_contains "-list 显示分支名" "$out" "master"

# 干净仓库显示干净
out="$("$GITM" -list)"
ok_contains "-list 干净仓库标记" "$out" "干净"

# 空仓库
out="$("$GITM" -list | grep '^blank.git')"
ok_contains "-list 标注空仓库" "$out" "空仓库"

# 没有仓库时给出提示
sandbox
out="$("$GITM" -list)"
ok_rc "空目录 -list 退出码 0" "$?" "0"
ok_contains "空目录 -list 给出提示" "$out" "没有 gitm 仓库"

# -list 是只读的：不应产生锁或改动文件
ok_not_exists "-list 不留下工作目录锁" .gitm.workdir.lock

finish
