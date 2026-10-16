# gitm

用一个目录同时管理多个小型 Git 仓库，并支持「一个仓库只记录一个文件」。

`gitm` 是一个 Bash 包装脚本：每个仓库是一个独立的 `<仓库名>.git` 目录（也支持隐藏形式
`.<仓库名>.git`），工作区就是当前目录。
核心是把 `git --git-dir=... --work-tree=...` 这套用法收进一个命令里，同时解决多仓库共用
同一工作区带来的两个麻烦：**忽略规则怎么生效**、**互不干扰怎么保证**。

```bash
gitm <git-dir 或 文件名> <git 命令> [参数...]
```

## 为什么需要它

在一个目录里放多个仓库，典型如 home 目录下有多个应用的配置文件希望进行独立管理时，每个仓库都希望
「只看见自己关心的文件」，忽略别的仓库的数据、其它临时文件。Git 原生只能靠一个 `.gitignore`
和一个 `.git` 仓库，多个仓库会互相冲突。

`gitm` 的做法是：每个仓库在 `<仓库名>.git/info/exclude` 里维护自己的忽略规则，
执行命令时临时把它「提升」为工作区的 `.gitignore`，命令跑完立即还原。于是每个仓库都有
自己的一套忽略视角，而工作区里那份属于你（或别的仓库）的 `.gitignore` 不会被永久占用。

## 安装

`gitm` 是自包含的单文件脚本，只依赖 `git` 和 Bash。

### 一键安装

从远端克隆，复制到 `~/.local/bin`，并加上可执行权限：

```bash
git clone --depth 1 https://github.com/MaoTouZhu/gitm.git ~/.local/share/gitm \
  && mkdir -p ~/.local/bin \
  && install -m 755 ~/.local/share/gitm/gitm ~/.local/bin/gitm \
  && echo "已安装: $HOME/.local/bin/gitm"
```

如果 `~/.local/bin` 不在 `PATH` 里，追加一行（`.zshrc` 用户改成对应文件）：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

用 SSH 的话把地址换成 `git@github.com:MaoTouZhu/gitm.git`。

### 更新

```bash
git -C ~/.local/share/gitm pull --ff-only \
  && install -m 755 ~/.local/share/gitm/gitm ~/.local/bin/gitm
```

### 手动安装

已经有一份克隆（或直接下载了脚本）时，只需放到 `PATH` 里的任意目录：

```bash
install -m 755 gitm ~/.local/bin/gitm
```

### 验证

```bash
gitm          # 应打印用法: gitm <git-dir> <git 命令> [参数...]
```

> 提交需要 Git 身份，没配过的话先设好，否则 `gitm <名字> init` 的首次提交会失败：
> ```bash
> git config --global user.name  "你的名字"
> git config --global user.email "你的邮箱"
> ```

## 快速开始

```bash
# 首次使用：建仓库（自动补 .git 后缀，并把 .gitignore 作为第一次提交）
gitm foo.txt init

# 日常操作：直接跟 git 子命令
gitm foo.txt status
gitm foo.txt log --oneline

# 其余命令原样透传给 git
gitm foo.txt diff HEAD~1
gitm foo.txt push origin main

# 隐藏形式的仓库也认，裸名字会自动找到它
gitm .config.git init       # 显式新建隐藏形式
gitm .config status         # 裸名字自动探测到 .config.git
```

`gitm foo.txt init` 之后，工作区形如：

```
foo.txt            # 被跟踪的文件（与仓库同名，init 时自动一并加入）
foo.txt.git/       # 仓库本体
.gitignore         # 首次提交的内容，内容与 foo.txt.git/info/exclude 一致
```

## 应用场景：多设备配置文件管理

如果你有多台机器，常见需求是：**同一份配置文件在不同机器上只有小幅差异，想统一管理又能各自
独立变动**。例如 `.bashrc` 在笔记本和台式机上共享大部分内容，但各自多几行专属设置。

`gitm` 的天然用法是：**每个配置文件一个仓库，每台设备一个分支**。

- 一个仓库管一个文件 → 切分支时只有一个文件的版本在变，不会牵动整个家目录；
- **分支 = 设备**，各设备的差异天然隔离，可独立推送/拉取；
- 抽一个 `common` 分支存放共享配置段，设备分支从它派生，共享段的改动合并下去即可；
- 每个仓库有自己的忽略规则（`*`），所以家目录里成千上万的其它文件不会打扰你。

### 完整流程

```bash
# ---------- 0. 在远端建一个空仓库（可选，任选其一）----------
# gh repo create <名字> --private          # 已装 GitHub CLI
# glab repo create <名字> --private        # 或用 GitLab CLI
# 也可以在网页上直接建空仓库

# ---------- 1. 选一条共用基线 ----------
cd ~
gitm .bashrc.git init                 # 建仓库并提交 .bashrc
gitm .bashrc.git branch -M common     # 把初始分支命名为 common，充当共享基线
gitm .bashrc.git remote add origin <你的私有仓库>
gitm .bashrc.git push -u origin common

# ---------- 2. 笔记本：从基线拉出自己的设备分支 ----------
gitm .bashrc.git switch -c laptop
# ...编辑 .bashrc，追加笔记本专属配置...
gitm .bashrc.git add -f .bashrc       # 仓库忽略了所有文件，必须 -f
gitm .bashrc.git commit -m "laptop 专属配置"
gitm .bashrc.git push -u origin laptop

# ---------- 3. 台式机：同样从基线派生 ----------
gitm .bashrc.git switch -c desktop common
# ...编辑 .bashrc，追加台式机专属配置...
gitm .bashrc.git commit -am "desktop 专属配置"
gitm .bashrc.git push -u origin desktop

# ---------- 4. 共享配置段改动：在 common 改，再合并到各设备 ----------
gitm .bashrc.git switch common
# ...修改所有设备都受益的段落...
gitm .bashrc.git commit -am "共享段：改用 nvim"
gitm .bashrc.git push origin common
gitm .bashrc.git switch laptop
gitm .bashrc.git merge --no-edit common    # 把共享段并进来，laptop 专属段不受影响

# ---------- 5. 只想看一眼别的机器怎么配的，不想切换 ----------
gitm .bashrc.git show desktop:.bashrc
```

上面的流程实测可用：合并 `common` 后 `laptop` 拿到了新的共享段，同时保留自己的专属段；
工作区 `status` 始终干净。

### 远端已存在时：直接 clone 起步

如果远端仓库已经建好（里面有你的配置和一个 `.gitignore`），不必先 `init` 再手动加远端，
直接用 `clone` 即可——`gitm` 会把它整理成符合要求的形态：

```bash
cd ~
gitm .bashrc.git clone <远端地址>
# 远端默认分支已铺到 ~/.bashrc，忽略规则已就位，可直接用
gitm .bashrc.git switch -c laptop     # 再从基线派生设备分支
```

### 几个要点

- **同一时刻只有一个分支的版本在磁盘上。** 切分支会就地替换 `.bashrc`，这是 Git 的正常行为，
  不是 `gitm` 特有的。只想查看别的分支时用 `git show <分支>:<文件>`，不要切换。
- **提交一定要 `-f`。** 仓库的忽略规则是「忽略所有」，`git add` 不加 `-f` 不会加入任何文件。
- **共享段改了要主动合并。** Git 没有「跨分支同步片段」的自动机制：在 `common` 上改完，
  逐个设备分支 `merge common`；只想取某一次改动就用 `cherry-pick`。
- **每台机器的初始化顺序**：先让 `common` 存在于远端，新机器再引导。新机器上最省事的方式是
  直接克隆成裸仓库，让 gitm 拿到一个真正的 git-dir：

  ```bash
  cd ~
  git clone --bare <远端地址> .bashrc.git
  git --git-dir=.bashrc.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  gitm .bashrc.git fetch origin
  gitm .bashrc.git switch -c desktop origin/common    # 以远端 common 为起点建本机分支
  ```

  之后即可用 `gitm .bashrc.git switch -c <设备名> origin/common` 开工。设备分支没推送过，
  别的机器看不到，这正是我们想要的隔离。
- **多个配置文件互不干扰**：`.bashrc.git` 与 `.gitconfig.git` 可以并存，各自跟踪各自的文件，
  各自的 `status` 都是干净的。
- **点开头文件名照常工作**：`gitm .bashrc status` 会自动探测到 `.bashrc.git`
  （探测规则见下一节），日常不必写全 `.bashrc.git`。

> 提醒：不要在一个仓库里同时跟踪多个配置文件再靠分支区分设备——那样切分支会把整组文件一起
> 切换，且不同设备对同一文件的依赖会互相牵制。**一个文件一个仓库**才是这个场景的推荐用法。

## 名称补全与双形式自动探测

仓库目录约定以 `.git` 结尾，并支持两种形式：

- **普通形式** `<名字>.git`，如 `foo.txt.git`
- **隐藏形式** `.<名字>.git`，如 `.foo.txt.git`

只给**裸名字**（不含 `/`、不是 `.` / `..`、不以 `.git` 结尾）时，`gitm` 会在两种形式间自动选择：

| 情况 | 行为 |
|---|---|
| 两个都不存在 | 按普通形式新建，`foo.txt` → `foo.txt.git` |
| 只存在隐藏形式 | 自动选中它，并提示 `检测到隐藏仓库，使用 .foo.txt.git` |
| 只存在普通形式 | 自动选中它 |
| **两个都存在** | **报错中断**，要求显式写全仓库名 |

两个都存在时的报错：

```
gitm: 仓库名有歧义：foo.txt.git 与 .foo.txt.git 同时存在
gitm: 请显式写全仓库名，例如：gitm foo.txt.git <命令>
gitm:                       或：gitm .foo.txt.git <命令>
```

已经带 `.git` 后缀的名字视为**明确指定**，原样使用、不做任何探测或改写；
显式带路径的名字只补后缀、不做探测：

| 输入 | 实际使用的仓库 | 说明 |
|---|---|---|
| `gitm foo.txt init` | `foo.txt.git` | 裸名字，都不存在 → 新建普通形式 |
| `gitm bar.txt status` | `.bar.txt.git` | 裸名字，只存在隐藏形式 → 自动选中并提示 |
| `gitm baz.txt status` | — | 两种形式同时存在 → 报错中断 |
| `gitm foo.txt.git status` | `foo.txt.git` | 写全了，明确指定 |
| `gitm .foo.txt.git status` | `.foo.txt.git` | 写全了，明确指定 |
| `gitm sub/bar status` | `sub/bar.git` | 显式路径，只补后缀 |
| `gitm .hidden init` | `.hidden.git` | 裸名字，按字面补后缀 |
| `gitm . init` | `.git` | 归一化为当前目录的 `.git` |
| `gitm .. status` | `../.git` | 归一化为上级目录的 `.git` |

设 `GITM_NO_SUFFIX=1` 可完全关闭补全与探测，改用仓库目录的原名。

> 以点开头的名字按字面处理：`gitm .config status` 找的是 `.config.git` 与 `..config.git`；
> 想用隐藏形式请直接写全 `gitm .config.git status`。
> 隐藏形式的仓库目录（如 `.foo.txt.git/`）同样被 `*` 规则忽略，不会出现在 `git status` 里。

## `init` 的特殊行为

`gitm <name> init`（且不带其它参数）会走一条完整流程：

1. 执行 `git init`；
2. 把「忽略所有」规则 `*` 写入 `<仓库>.git/info/exclude`，并设置 `core.excludesFile` 指向它；
3. 工作区若**没有** `.gitignore`，用 exclude 内容生成一份；**已有则原样尊重、绝不覆盖**；
4. 把 `.gitignore` 作为该仓库的**第一次提交**；
5. 若仓库名去掉 `.git` 后正是工作区里的同名普通文件（`foo.txt.git` → `foo.txt`，
   `.foo.txt.git` → `.foo.txt`），该文件会**一并强制加入并提交**，做到开箱即用。

重复执行 `init` 是幂等的：内容没变就只提示跳过，不会产生空提交。

> 注意：生成出来的 `.gitignore` 内容来自 `info/exclude`，因此包含 `*`。如果你把这个仓库
> 推送到远端，克隆端会看到一份「忽略所有」的 `.gitignore`。如果你不想要它，
> 用 `GITM_KEEP_GITIGNORE=0`，或自己先写好 `.gitignore`（gitm 不会覆盖你的版本）。
>
> 由于 `init` 会新建仓库，它遵循上面的探测规则但不会误判：裸名字在两种形式都不存在时
> 一律新建普通形式。想建隐藏形式请显式写 `gitm .foo.txt.git init`。

## 工作原理

正常执行一条命令时，`gitm` 做两件事：

```
1. 把仓库配置 core.excludesFile 指向 <仓库>.git/info/exclude
2. 执行 git --git-dir=<仓库>.git --work-tree=. <你的命令>
```

`git` 会把 `core.excludesFile` 与工作区的 `.gitignore`、`$GIT_DIR/info/exclude`
**叠加**使用，所以每个仓库都能获得自己的「忽略所有」视角，而：

- 工作区里的 `.gitignore` 属于你或某个仓库的内容，`gitm` **从不读写、从不备份还原**；
- 因此 `git add -A` / `git commit -a` 不可能把 gitm 的内部规则误提交进历史；
- 也没有 `.gitignore.bak` 之类的临时文件，不占用工作区路径。

> 早期版本用的是「把 exclude 临时拷成工作区 .gitignore、命令结束再还原」的做法，
> 那会让 `commit -a` 把临时内容提交进历史、并让用户的 `.gitignore` 永久显示为已修改。
> 现已改为上面的 `core.excludesFile` 方案。

## `clone` 的特殊行为

`gitm` 要求 `<gitdir>` **本身就是 git-dir**，而 `git clone` 默认生成 `<gitdir>/.git`
的非裸仓库，直接透传会报「不是 git 仓库」。因此 `gitm <gitdir> clone <url>` 会被改写：

```
git clone --bare <url> <gitdir>     # 让 <gitdir> 直接成为 git-dir
+ 写入「忽略所有」规则到 <gitdir>/info/exclude，并设置 core.excludesFile
+ 把远端默认分支的内容铺到工作区（用 read-tree + checkout-index）
```

铺开工作区时**只写出分支里已有的文件**，不会删除工作区里的其它内容
（例如并列存在的其它 `<仓库>.git/` 目录、以及你未提交的其它文件）。

```bash
gitm .bashrc.git clone git@github.com:me/bashrc.git   # 克隆后即可用
gitm .bashrc.git status

# 选项照常支持，--bare 由 gitm 自己处理
gitm .bashrc.git clone --depth 1 --branch main <url>
```

克隆下来的仓库各项都符合 gitm 的使用要求：`<gitdir>` 是 git-dir、忽略规则已就位、
默认分支已铺到工作区、`push`/`fetch` 正常。若远端是空仓库（没有任何提交），
工作区会保持空白，等你提交第一个版本。

## 并发锁

由于第 2 步占用的 `.gitignore` 是**工作区里共享的路径**，多个 `gitm` 同时运行会互相踩。
因此 `gitm` 使用两把锁：

| 锁 | 位置 | 作用 |
|---|---|---|
| 工作目录锁 | `<当前目录>/.gitm.workdir.lock` | 串行化同一工作目录下的「接管 `.gitignore`」过程 |
| 仓库锁 | `<真实 git-dir>/.gitm.repo.lock` | 串行化同一个仓库的并发调用 |

- 获取顺序固定为「先工作目录、后仓库」，因此**不会死锁**；
- 拿不到锁会**阻塞等待**，并打印一次「正在等待…锁」；
- 锁目录里记录持有者 PID，异常退出（如 `kill -9`）留下的**陈旧锁会被自动清理**；
- 锁目录会被 `*` 忽略规则盖住，不会污染 `git status`。

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `GITM_INIT_MESSAGE` | `initial commit` | `init` 首次提交的提交信息 |
| `GITM_KEEP_GITIGNORE` | `1` | `init` 时是否生成并提交 `.gitignore`；`0` = 不生成也不提交（已有文件永不被覆盖） |
| `GITM_NO_SUFFIX` | `0` | `1` = 完全关闭名称补全与双形式探测，仓库名按原样使用 |
| `GITM_LOCK_TIMEOUT` | `0` | 取锁最大重试次数（约 0.1s/次），`0` = 不限时；非整数会被忽略并提示 |
| `GITM_CLEAN_YES` | `0` | `1` = 跳过 `clean` 的确认（警告仍会打印） |

## 安全：`clean` 会被拦截

`git clean` 在这个场景里格外危险：**别的仓库正在跟踪的数据，在当前仓库看来只是「未跟踪文件」**；
再叠加 `-x` 时忽略规则全部失效，连仓库目录本身（`<仓库>.git/`、普通仓库的 `.git/`）都会被删掉。

所以 `gitm` 会在执行前打印警告，并要求输入 `yes` 才放行：

```
gitm: ⚠️  危险操作拦截 —— 你正在执行 git clean
  ...
  gitm: 确认执行 git clean 吗？输入 yes 继续，其它输入取消：
```

- 只有精确输入 `yes` 才继续，其它输入（含空、`y`、`YES`）一律取消；
- 非交互环境（stdin 无输入且拿不到控制终端）**直接中止**，默认不执行；
- 拦截会跳过 git 全局选项识别子命令，`gitm repo.git -C . clean -fdx` 这类写法同样会被拦下；
- 确认前建议先跑 `gitm <仓库> clean -n -d -x` 只看清单。

## 已知边界

- **两种形式同时存在时，裸名字会报错。** 这是刻意的：与其猜，不如让你显式写全
  `foo.txt.git` 或 `.foo.txt.git`。已经写全 `.git` 后缀的名字不会触发该错误。
- **锁只约束 `gitm` 自身。** 普通 `.git` 仓库的 `git` 命令、你的编辑器，都不会读 `gitm` 的锁；
  它们若在 `gitm` 运行窗口内读写同一个 `.gitignore`，锁拦不住。
- **同一个工作区里，多个仓库无法各自跟踪同一路径的不同内容。** 磁盘上一个路径只能有一个版本，
  若两个仓库分别提交了不同版本，必然有一个长期显示 `M`/`D`。这是共用工作区的固有约束。
- **工作区就是当前目录。** `gitm` 始终以 `--work-tree=.` 运行，请在目标目录顶层执行；
  在子目录里执行会把该子目录当作工作区根。
- **并发取锁的陈旧锁清理有微小竞态。** 若恰好撞上另一进程「刚创建锁目录、还没写入 PID」的瞬间，
  理论上可能误删活锁；窗口极短。

## 测试

回归测试在 `tests/` 下，纯 Bash，无外部依赖（除了 `git`）。

```bash
tests/run.sh              # 跑全部
tests/run.sh init clone   # 只跑指定分组
```

| 文件 | 覆盖 |
|---|---|
| `t-naming.sh` | 名称补全、`GITM_NO_SUFFIX`、`.`/`..` 归一化、双形式探测与歧义报错 |
| `t-init.sh` | 首次提交内容、exclude/`core.excludesFile`、幂等、已有 `.gitignore` 尊重、`GITM_KEEP_GITIGNORE` |
| `t-clone.sh` | 裸克隆结构、默认分支铺开、`--depth/--branch/--origin/--bare`、空远端、克隆后提交/推送/切分支/合并 |
| `t-clean.sh` | 警告文案、各种输入下的取消/放行、非交互中止、全局选项不能绕过、不误拦 |
| `t-locks.sh` | 锁的持有与释放、跨仓库串行、陈旧锁清理、超时、同仓库并发 |
| `t-misc.sh` | 命令透传、忽略语义（`*` 与用户 `.gitignore` 叠加）、不改写工作区文件、边界情况 |

特点：

- 每个用例都在独立的临时工作目录里跑，互不影响；**运行结束不残留任何目录**；
- 断言失败会打印「实际 / 期望」，便于定位；
- 全部通过时退出码 `0`，有失败时 `1`，可直接接进 CI；
- 测试强制隔离用户 git 配置（`GIT_CONFIG_GLOBAL=/dev/null`），结果可复现。

## 与同类工具

| | 仓库位置 | 忽略机制 | 适用 |
|---|---|---|---|
| `gitm` | `<name>.git` 或 `.<name>.git` | 临时提升 `info/exclude` 为工作区 `.gitignore` | 一个目录管理多个完整仓库，兼顾单文件 |
| `zit` | `.zit/<file>.git` 或 `.<file>.git` | `core.excludesfile` 指向仓库内文件 | 单文件历史追踪，功能最全 |
| `git1` | `.g1_<file>`（bare） | `info/exclude` 里 `*` + `!<file>` | 最小实现，只够管一个文件 |

`gitm` 的特点是把仓库当**完整普通仓库**对待、命令全透传，因此 `rebase`、`bisect`、`worktree`
等冷门功能不会被白名单挡住。

## 许可

未指定。
