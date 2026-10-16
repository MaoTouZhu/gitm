#!/usr/bin/env bash
# 名称补全 + 双形式自动探测

sandbox

# ---------- 名称补全 ----------
printf 'v\n' > foo.txt
"$GITM" foo.txt init >/dev/null 2>&1
ok_exists     "裸名字新建普通形式 foo.txt.git" foo.txt.git
ok_not_exists "未误建隐藏形式"                 .foo.txt.git

"$GITM" repo.git init >/dev/null 2>&1
ok_exists "已带 .git 原样保留" repo.git

"$GITM" .hidden init >/dev/null 2>&1
ok_exists "点开头名字按字面补后缀 .hidden.git" .hidden.git

GITM_NO_SUFFIX=1 "$GITM" raw init >/dev/null 2>&1
ok_exists     "GITM_NO_SUFFIX=1 用原名 raw" raw
ok_not_exists "GITM_NO_SUFFIX=1 不补 .git"  raw.git

mkdir -p sub
printf 'v\n' > sub/name.txt
"$GITM" sub/name.txt init >/dev/null 2>&1
ok_exists "显式路径只补后缀" sub/name.txt.git

"$GITM" . init >/dev/null 2>&1
ok_exists "gitm . 归一化为 .git" .git

# .. 归一化为上级目录的 .git
mkdir -p child
(
    cd child
    "$GITM" .. status --porcelain >/dev/null 2>&1
    exit $?
)
ok_rc "gitm .. 指向上级 .git" "$?" "0"

# ---------- 双形式探测 ----------
sandbox

printf 'v\n' > bar.txt
"$GITM" .bar.txt.git init >/dev/null 2>&1
out="$("$GITM" bar.txt status 2>&1)"
rc=$?
ok_rc        "只存在隐藏形式时自动选中" "$rc" "0"
ok_contains  "并提示使用了隐藏仓库"     "$out" "检测到隐藏仓库"

# 两种形式并存 -> 报错
E2="$(tmpdir)"
(
    cd "$E2" || exit 1
    printf 'v\n' > baz.txt
    "$GITM" baz.txt init >/dev/null 2>&1
    "$GITM" .baz.txt.git init >/dev/null 2>&1
    "$GITM" baz.txt status >/dev/null 2>&1
)
ok_rc "两种形式并存时裸名字报错" "$?" "1"

out="$(cd "$E2" && "$GITM" baz.txt status 2>&1)"
ok_contains "报错信息说明歧义" "$out" "有歧义"

(cd "$E2" && "$GITM" baz.txt.git status --porcelain >/dev/null 2>&1)
ok_rc "显式普通形式仍可用" "$?" "0"
(cd "$E2" && "$GITM" .baz.txt.git status --porcelain >/dev/null 2>&1)
ok_rc "显式隐藏形式仍可用" "$?" "0"

# 已写全 .git 的名字不受探测影响（即便另一种形式也存在）
(cd "$E2" && "$GITM" baz.txt.git status >/dev/null 2>&1)
ok_rc "写全名字不触发歧义" "$?" "0"

finish
