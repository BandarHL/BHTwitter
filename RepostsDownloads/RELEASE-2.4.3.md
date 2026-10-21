# X 随心 2.4.3：无头像 URL 时接收原生头像

## 依据与修复

收到的 2.4.2+diag.1 真机日志片段确认：作者 ID/用户名已经解析，`preview_resolved` 仍为 `model_url_missing`，没有下载请求；同一行的 `TUIAvatarImageView` 有 UIImage 和 layer.contents，而覆盖层仍为占位。日志也明确列出该头像视图的 `user`、`userViewModel` 访问器。用户报告中的完整时间线提供了头像延迟到达的线索；本地收到的片段不含完整启动和模型 shape 记录。

此前只重新读取模型，未消费原生视图中后来到达的图片。2.4.3 新增独立回退：

- 当模型没有头像 URL 时，查找原生头部 `TUIAvatarImageView`，通过其 `user` 或 `userViewModel.user` 核对原作者。数字账号 ID 冲突时拒绝，缺少任何可核对身份时仍保留占位。
- 不依据姓名标签或坐标单独授权取图。保存本次绑定的图片基线及原生 setImage 时的账号记录，只接受绑定后新到的同账号图片，或带有同账号赋图记录的图片；避免复用期间改了用户但仍残留旧图片的混配。
- 支持 UIImage 和 CGImage 图层内容；图层位图保持稳定引用，避免每次包装为新 UIImage 被误判为新图。
- 进入列表后在 0.15、0.6、1.5、2.5、4、7、12 秒检查，并响应原生图片更新。每次重新核对当前列表行、原帖 ID 和作者，排除引用/媒体子树及不符合头部尺寸的头像。
- 增加原作者 `profileImageMediaEntity` / `avatarImage` 资源路径及其媒体 URL 字段。继续使用头像 URL 白名单。
- 诊断模式新增头像字段空值/类型、原生轮询安排、候选视图绑定账号、位图到达时序与原生赋图结果，减少 UIKit 通用方法造成的日志噪声。

## 安装包

| 包 | 字节数 | SHA-256 |
| --- | ---: | --- |
| `packages/XSuixin_2.4.3_rootless.deb` | 6,458,570 | `eef95ca13fcd5e2a754228f9d6ecd303577c45ff1e4326a66d23edfa7e837172` |
| `packages/XSuixin_2.4.3_diag1_rootless.deb` | 6,467,400 | `efe46f679c211183a55bc552d186c995ee27645e8be7c9d42fe30713e545fca4` |

两个包包含相同修复。诊断包的 Debian 版本为 `2.4.3+diag.1`，另有文件日志，建议本次优先用它复验。可覆盖安装此前 2.4.2+diag.1，安装后彻底退出并重开 X，停留在相关转推预览约 12 秒，进入详情再返回查看头像。日志仍在 X 容器的 `Library/Application Support/XSuixinDownloads/avatar-diag.log`，轮转文件为 `.log.1`。

## 验证

- 新增 3 项模型检查与 11 项原生头像生命周期检查；常规检查共 922 项通过。
- 文件日志 40 项检查、诊断模式下同一套 41 项生产预览检查、完整日志事件检查通过；两档真实 HLS 验证通过。
- 两种包均完成 arm64 编译、版本/架构、iOS 15.0 最低版本、`/var/jb` 路径和仅 X 注入范围检查。标准包 8,054 个代码页、诊断包 8,064 个代码页的两份 CodeDirectory 哈希核验通过。
- 标准包确认不含文件诊断代码；现有静态依赖的链接废弃参数和节对齐提示仍存在，无编译错误。

这些测试使用宿主视图夹具重现延迟加载和复用，不等同于已在用户手机验证 2.4.3。若仍有占位，请导出新日志，重点查看 `native_avatar_candidate` 的 owner/matches/stamped/fresh 字段及 `native_avatar_assigned`。用户原始日志和截图不提交到公共仓库。
