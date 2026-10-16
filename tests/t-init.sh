#!/usr/bin/env bash
# init 的完整行为

# ---------- 基本流程：无 .gitignore ----------
sandbox
printf 'v1\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
ok_rc "init 成功" "$?" "0"
ok "首次提交含 .gitignore 与同名文件" \
   "$(gitd foo.txt.git ls-tree -r --name-only HEAD | tr '\n' ' ' | sed 's/ $//')" \
   ".gitignore foo.txt"
ok "init 后 status 干净" "$(gitd foo.txt.git status --porcelain)" ""
ok "exclude 含忽略所有规则 *" \
   "$(grep -qxF '*' foo.txt.git/info/exclude && echo yes || echo no)" "yes"
ok "已设置 core.excludesFile" \
   "$(test -n "$(gitd foo.txt.git config --get core.excludesFile)" && echo yes || echo no)" "yes"
ok "工作区 .gitignore 内容与 exclude 一致" \
   "$(cmp -s .gitignore foo.txt.git/info/exclude && echo same || echo diff)" "same"
ok "core.excludesFile 指向存在的文件" \
   "$(test -f "$(gitd foo.txt.git config --get core.excludesFile)" && echo yes || echo no)" "yes"

# 幂等
"$GITM" foo.txt init >/dev/null 2>&1
ok_rc "重复 init 不报错" "$?" "0"
ok "重复 init 不新增提交" "$(gitd foo.txt.git rev-list --count HEAD)" "1"

# 幂等且内容变了会补提交
printf 'v2\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
ok "同名文件内容变化后 init 会提交" "$(gitd foo.txt.git rev-list --count HEAD)" "2"

# ---------- 自定义提交信息 ----------
sandbox
printf 'v\n' > a.txt
GITM_INIT_MESSAGE="我的首次提交" "$GITM" a.txt init >/dev/null 2>&1
ok "GITM_INIT_MESSAGE 生效" "$(gitd a.txt.git log -1 --pretty=%s)" "我的首次提交"

# ---------- 已有用户 .gitignore：必须尊重 ----------
sandbox
printf '*.log\n' > .gitignore
printf 'v1\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
ok_rc "已有 .gitignore 时 init 成功" "$?" "0"
ok "用户 .gitignore 未被覆盖" "$(cat .gitignore)" "*.log"
ok "用户 .gitignore 被纳入首次提交" "$(gitd foo.txt.git show HEAD:.gitignore)" "*.log"

# ---------- 隐藏形式 init ----------
sandbox
printf 'v1\n' > .secret
"$GITM" .secret.git init >/dev/null 2>&1
ok_exists "隐藏形式仓库已创建" .secret.git
ok "隐藏形式的同名文件也被跟踪" \
   "$(gitd .secret.git ls-tree -r --name-only HEAD | grep -c '^.secret$')" "1"

# ---------- GITM_KEEP_GITIGNORE=0 ----------
sandbox
printf 'v1\n' > foo.txt
GITM_KEEP_GITIGNORE=0 "$GITM" foo.txt init >/dev/null 2>&1
ok_not_exists "KEEP=0 不生成 .gitignore" .gitignore
ok "KEEP=0 首次提交不含 .gitignore" "$(gitd foo.txt.git ls-tree -r --name-only HEAD)" "foo.txt"
ok "KEEP=0 时 status 依然干净" "$(gitd foo.txt.git status --porcelain)" ""

# ---------- init 后 gitm 自身不再动 .gitignore ----------
sandbox
printf '*.log\n' > .gitignore
printf 'v1\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
"$GITM" foo.txt add -f foo.txt .gitignore >/dev/null 2>&1
"$GITM" foo.txt commit -qm base >/dev/null 2>&1
before="$(md5sum .gitignore | cut -d' ' -f1)"
for c in status log diff; do "$GITM" foo.txt "$c" >/dev/null 2>&1; done
printf 'v2\n' > foo.txt
"$GITM" foo.txt commit -qam v2 >/dev/null 2>&1
after="$(md5sum .gitignore | cut -d' ' -f1)"
ok "普通命令不改动 .gitignore" "$([ "$before" = "$after" ] && echo same || echo changed)" "same"
ok "commit -a 不会把忽略规则写进 .gitignore" "$(gitd foo.txt.git show HEAD:.gitignore)" "*.log"
ok "commit -a 后 status 干净" "$(gitd foo.txt.git status --porcelain)" ""
ok_not_exists "不产生 .gitignore.bak" .gitignore.bak

finish
