#!/usr/bin/env bash
# clean 拦截与确认
#
# 注意：`clean -fdx` 会连本仓库目录一起删掉（这正是拦截要防的行为），
# 所以所有「放行」类用例必须各自放在独立 sandbox 里、并且最后执行。

# ================= 取消类：不会破坏环境，可复用同一基线 =================
sandbox
printf 't\n' > keep.txt
"$GITM" A.git init >/dev/null 2>&1
"$GITM" A.git add -f keep.txt >/dev/null 2>&1
"$GITM" A.git commit -qm k >/dev/null 2>&1
ok "基线 status 干净" "$(gitd A.git status --porcelain)" ""

for v in no y YES "" "  "; do
    printf 'junk\n' > junk.txt
    printf '%s\n' "$v" | "$GITM" A.git clean -fdx >/dev/null 2>&1
    ok "输入 [$v] 取消且不删除" "$(test -e junk.txt && echo kept || echo gone)" "kept"
done

# 输入 yes 时不再取消（用 -n 预览形式验证，不会破坏环境）
# 注：bash 的 read 会去掉首尾空白，所以「yes 」等价于「yes」，不单列用例
printf 'junk\n' > junk.txt
printf 'yes\n' | "$GITM" A.git clean -n -d -x >/dev/null 2>&1
ok_rc "输入 yes 时放行确认（预览形式）" "$?" "0"

printf 'junk\n' > junk.txt
"$GITM" A.git clean -fdx </dev/null >/dev/null 2>&1
ok_rc "非交互环境中止" "$?" "1"
ok "非交互时不删除" "$(test -e junk.txt && echo kept || echo gone)" "kept"

# 警告文案
out="$(printf 'no\n' | "$GITM" A.git clean -fdx 2>&1)"
ok_contains     "警告提示已拦截"           "$out" "危险操作拦截"
ok_contains     "警告说明不可恢复"         "$out" "不可恢复"
ok_contains     "警告提到 -x 会删仓库目录"  "$out" "仓库目录"
ok_contains     "警告给出预览命令"         "$out" "clean -n -d -x"
ok_not_contains "取消时不打印放行信息"     "$out" "跳过确认"

# git 全局选项不能绕过拦截
for form in "clean -fdx" "-C . clean -fdx" "--no-pager clean -fdx" "-c core.quotePath=false clean -fdx" "--git-dir A.git clean -fdx"; do
    printf 'junk\n' > junk.txt
    printf 'no\n' | "$GITM" A.git $form >/dev/null 2>&1
    ok "拦截覆盖: $form" "$(test -e junk.txt && echo kept || echo gone)" "kept"
done

# 非 clean 子命令不应被误拦
out="$("$GITM" A.git status --porcelain 2>&1)"
ok "status 不被拦截" "$(printf '%s' "$out" | grep -c '危险操作拦截')" "0"
out="$("$GITM" A.git log --oneline 2>&1)"
ok "log 不被拦截" "$(printf '%s' "$out" | grep -c '危险操作拦截')" "0"
out="$("$GITM" A.git cleanliness 2>&1)"
ok "cleanliness 不误拦" "$(printf '%s' "$out" | grep -c '危险操作拦截')" "0"

# ================= 放行类：各自独立沙箱（执行后会删掉仓库） =================
sandbox
printf 't\n' > keep.txt
"$GITM" A.git init >/dev/null 2>&1
"$GITM" A.git add -f keep.txt >/dev/null 2>&1
"$GITM" A.git commit -qm k >/dev/null 2>&1
printf 'junk\n' > junk.txt
printf 'yes\n' | "$GITM" A.git clean -fdx >/dev/null 2>&1
ok_rc "输入 yes 时放行" "$?" "0"
ok "输入 yes 后确实删除" "$(test -e junk.txt && echo kept || echo gone)" "gone"

sandbox
printf 't\n' > keep.txt
"$GITM" A.git init >/dev/null 2>&1
"$GITM" A.git add -f keep.txt >/dev/null 2>&1
"$GITM" A.git commit -qm k >/dev/null 2>&1
printf 'junk\n' > junk.txt
out="$(GITM_CLEAN_YES=1 "$GITM" A.git clean -fdx 2>&1)"
rc=$?
ok_rc "GITM_CLEAN_YES=1 放行" "$rc" "0"
ok "GITM_CLEAN_YES=1 仍打印警告" "$(printf '%s' "$out" | grep -c '危险操作拦截')" "1"
ok "GITM_CLEAN_YES=1 跳过询问"   "$(printf '%s' "$out" | grep -c '输入 yes 继续')" "0"

finish
