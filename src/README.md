# 完整设计源码

`project_sources.tar.xz` 保存已验证工程的源码、RTL、BD/XPR、XDC、IP 配置、PS/Linux 软件、算法和地面站，原始文件清单见 `source_manifest.json`。

内核源码完整归档分为 `linux_source.part000` 等文件，每卷不超过 48 MiB，完整哈希及各卷顺序见 `archives.json`。分卷不是 Git LFS 指针，不需要额外下载；准备脚本重组并验证后交给内核构建脚本。

仓库外层路径采用小写英文，`README.md` 使用约定入口名称。源码解包后保留 `Makefile`、`Module.symvers`、IP 名称和启动文件的原生大小写，防止破坏第三方构建约定。中文仅用于文档正文。解包出的工作目录位于 Git 忽略的 `out/`，不作为另一套仓库源文件提交。

在仓库根目录执行 `python build/prepare_sources.py --out out/workspace_01`。准备工具校验分卷与归档、限制解包范围、逐文件核对源码清单，生成工作目录，详细复现步骤见根目录 README。

所有第三方版本、作者及许可证保留在归档对应源码目录；归档本身不改变其授权，不将整套第三方代码重新声明为本项目原创。
