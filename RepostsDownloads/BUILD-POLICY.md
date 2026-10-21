# 唯一构建与发布规则

正式仓库为 `Caun1112/XSuixin`，主分支为 `main`；BHTwitter 工作仓库的推送不会自动同步这里。

当前源码目标包版本为 `2.5.0-2`：2.5.0 为功能版本，2 为该功能版本的安装包修订。正式包由干净提交构建，构建状态与核验结果记录在对应 GitHub Release。下一包使用 2.5.0-3。代码或安装行为变化后修订递增；不要上传不同内容覆盖同一个已发布修订。

准备下一次同功能版本构建：先获取发布标签，再运行 `python3 RepostsDownloads/scripts/next_build.py`，将 control 中修订递增并提交。脚本参考本地 control 与已获取的同版本标签，取最大修订加 1，不倒退。

正式构建必须来自干净的发布仓库提交。`build.sh` 在 clean 后生成未入库的构建头，注入完整 Debian 版本、修订及 Git 提交。若已存在 `v<包版本>` 标签，且代码不同或有未提交修改，构建拒绝并要求递增修订。开发构建允许未发布版本带 `-dirty` 来源，禁止将其作为正式包发布。

核验命令：

```sh
python3 RepostsDownloads/scripts/verify_deb.py PACKAGE.deb --version 2.5.0-2 --commit FULL_40_CHARACTER_COMMIT --repository Caun1112/XSuixin
```

核验包版本与二进制构建号一致、来自指定干净提交、功能及默认日志存在、rootless 路径、架构和全部签名页。每个 Release 使用 `v2.4.7-1` 等完整修订标签，与 source commit、DEB 及 SHA-256 配对。

GitHub Actions 测试、构建并核验；推送完整版本标签时可自动发布单一包和校验文件。已经发布的 Release 不替换附件；相同提交可以重新验证，新的源码必须使用新修订。最终发布包和提交对应记录在 Release，手机运行状态和导出日志包含相同构建身份。

普通分支与 PR 执行完整回归并编译 UIKit/Logos 生产代码，不重复生成发布附件。版本标签及显式手动构建生成 DEB；标签发布记录准确 source commit，并使用同版本源码发布说明。构建注入 GitHub 仓库身份，运行状态和诊断摘要可核对。
