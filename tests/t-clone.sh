#!/usr/bin/env bash
# clone 的完整行为

# 造一个裸远端：make_remote <源目录> <远端名> <分支> <文件> <内容>
make_remote() { # make_remote <srcdir> <remotename> <branch> <file> <content>
    srcdir="$1"; remote="$2"; branch="$3"; file="$4"; content="$5"
    rm -rf "$srcdir" && mkdir -p "$srcdir"
    (
        cd "$srcdir" || exit 1
        printf '%b' "$content" > "$file"
        git init -q -b "$branch"
        git add -A >/dev/null 2>&1
        git commit -qm init >/dev/null 2>&1
    )
    rm -rf "$remote"
    git clone -q --bare "$srcdir" "$remote"
    rm -rf "$srcdir"
}

# ---------- 基本克隆 ----------
sandbox
rm -rf src && mkdir -p src
(
    cd src || exit 1
    printf '## base\n' > .bashrc
    printf '*.log\n' > .gitignore
    printf 'v1\n' > app.txt
    git init -q -b main
    git add -A >/dev/null 2>&1
    git commit -qm init >/dev/null 2>&1
)
rm -rf remote.git
git clone -q --bare src remote.git
rm -rf src

"$GITM" other.git init >/dev/null 2>&1
printf 'keep\n' > user.txt

"$GITM" app.git clone remote.git >/dev/null 2>&1
ok_rc "clone 成功" "$?" "0"
ok_exists     "<gitdir> 本身是 git-dir" app.git/HEAD
ok_not_exists "没有 <gitdir>/.git 嵌套"  app.git/.git
ok "exclude 含 *" \
   "$(grep -qxF '*' app.git/info/exclude && echo yes || echo no)" "yes"
ok "已设置 core.excludesFile" \
   "$(test -n "$(gitd app.git config --get core.excludesFile)" && echo yes || echo no)" "yes"
ok "远端默认分支已铺到工作区" "$(cat .bashrc | tr '\n' '|')" "## base|"
ok "用户的 .gitignore 原样保留" "$(cat .gitignore)" "*.log"
ok_exists "并列的其它仓库目录幸存" other.git
ok_exists "用户的其它文件幸存" user.txt
ok "克隆后 status 干净" "$(gitd app.git status --porcelain)" ""
ok "HEAD 指向默认分支" "$(gitd app.git symbolic-ref --short HEAD)" "main"

# 克隆后日常可用
printf 'v2\n' > app.txt
"$GITM" app.git commit -qam mod >/dev/null 2>&1
ok_rc "克隆后可提交" "$?" "0"
ok "commit -a 不污染 .gitignore" "$(gitd app.git show HEAD:.gitignore)" "*.log"
ok "提交后 status 干净" "$(gitd app.git status --porcelain)" ""
"$GITM" app.git push -q origin main >/dev/null 2>&1
ok_rc "push 可用" "$?" "0"
ok "远端收到提交" "$(git --git-dir=remote.git log -1 --pretty=%s main)" "mod"
"$GITM" app.git fetch -q origin >/dev/null 2>&1
ok_rc "fetch 可用" "$?" "0"
"$GITM" app.git log --oneline >/dev/null 2>&1
ok_rc "log 可用" "$?" "0"

# ---------- clone 选项 ----------
sandbox
make_remote src opt.git main a.txt 'a\n'
"$GITM" d1.git clone --depth 1 opt.git >/dev/null 2>&1
ok_rc "--depth 支持" "$?" "0"
"$GITM" d2.git clone --branch main opt.git >/dev/null 2>&1
ok_rc "--branch 支持" "$?" "0"
"$GITM" d3.git clone --origin upstream opt.git >/dev/null 2>&1
ok_rc "--origin 支持" "$?" "0"
"$GITM" d5.git clone >/dev/null 2>&1
[ $? -ne 0 ] && r=err || r=ok
ok "缺少 URL 时报错" "$r" "err"

# --bare 单独一个沙箱，确保工作区没有 a.txt 干扰
sandbox
make_remote src bare.git main a.txt 'a\n'
"$GITM" d4.git clone --bare bare.git >/dev/null 2>&1
ok_rc         "--bare 支持" "$?" "0"
ok_not_exists "--bare 时不铺工作区" a.txt
ok_exists     "--bare 时仍是 git-dir" d4.git/HEAD

# ---------- 空远端 ----------
sandbox
git init -q --bare empty.git
"$GITM" e.git clone empty.git >/dev/null 2>&1
ok_rc "空远端 clone 成功" "$?" "0"
ok "空远端工作区保持空白" "$(ls -A | grep -vE '^(empty|e)\.git$' | wc -l | tr -d ' ')" "0"
"$GITM" e.git status --porcelain >/dev/null 2>&1
ok_rc "空远端 status 不报错" "$?" "0"
printf 'v\n' > x.txt
"$GITM" e.git add -f x.txt >/dev/null 2>&1
"$GITM" e.git commit -qm first >/dev/null 2>&1
ok "空远端克隆后可提交" "$(gitd e.git log -1 --pretty=%s)" "first"

# ---------- 默认分支为 master ----------
sandbox
make_remote src m.git master m.txt 'm\n'
"$GITM" mo.git clone m.git >/dev/null 2>&1
ok_rc "master 默认分支 clone 成功" "$?" "0"
ok "铺出 master 分支内容" "$(cat m.txt 2>/dev/null)" "m"
ok "HEAD 为 master" "$(gitd mo.git symbolic-ref --short HEAD)" "master"

# ---------- 克隆后多分支操作（多设备流程） ----------
sandbox
make_remote src h.git main .bashrc '## base\n'
"$GITM" work.git clone h.git >/dev/null 2>&1
ok_rc "clone 后即可用" "$?" "0"
ok "铺出默认分支内容" "$(tr '\n' '|' < .bashrc)" "## base|"

"$GITM" work.git switch -c laptop >/dev/null 2>&1
ok_rc "克隆后可建分支" "$?" "0"
printf '## laptop\n' >> .bashrc
"$GITM" work.git commit -qam laptop >/dev/null 2>&1
"$GITM" work.git switch main >/dev/null 2>&1
ok "切回 main 后内容回退" "$(tr '\n' '|' < .bashrc)" "## base|"
ok "切分支后 status 干净" "$(gitd work.git status --porcelain)" ""
"$GITM" work.git merge --no-edit laptop >/dev/null 2>&1
ok_rc "合并设备分支" "$?" "0"
ok "合并后包含设备专属段" "$(grep -c laptop .bashrc)" "1"

finish
