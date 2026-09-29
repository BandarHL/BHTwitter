# 2.4.4+diag.1 头像文件诊断版

这是包含 2.4.4 原生头像回退修复的取证包。安装包版本为 `2.4.4+diag.1`，可覆盖安装 2.4.2+diag.1 或正式版，设置页标题显示“头像诊断版”。新逻辑已通过本地模拟验证，实际手机效果仍需复验。

## 安装与导出

1. 安装 `packages/XSuixin_2.4.4_diag1_rootless.deb`，彻底退出并重新打开 X。
2. 刷新出现“已隐藏一条转推”的列表，让有占位头像的条目停留至少 12 秒，再上下滚动两次。
3. 日志路径为 `<X 数据容器>/Library/Application Support/XSuixinDownloads/avatar-diag.log`。如果旁边存在 `avatar-diag.log.1`，请一起导出。容器 UUID 不写死，重装 X 后需重新定位。
4. 手机端助手可复制到 `/var/mobile/Media/XSuixinLogs/`，然后把日志文件发回本对话。日志含帖子 ID、用户名、头像 URL 路径，不要将个人日志提交到公共 GitHub。

文件直接由插件写入，无需 root、系统日志命令或 Console.app。日志是逐行 JSON；含启动版本、系统版本、事件时间戳。每个文件约 2 MB，最多保留当前文件及一个滚动备份；文件权限 0600。不记录正文、图片数据、Cookie、请求头或 URL 查询参数。只在诊断构建中写日志，普通构建不会编入写日志代码。

## 判断故障在哪一段

- 2.4.4 也记录 `ad_response_checked`：`changed=true` 表示当前 JSON 响应中确实移除了广告条目，`false` 表示虽然数据含相关标记，但没有符合过滤规则的条目。该事件只含响应字节数和结果，不写 URL 或响应正文；未出现此事件不能证明没有广告，可能是不同数据解析路径。

- 没有 `session_start`：先核对是否安装诊断包并重启 X，以及容器路径是否正确。
- `preview_resolved` 显示 `model_url_missing`，随后 `avatar_missing_url`：头像还没有进入模型；看相同 `row` 的 `model_shape`、`model_url`，确定真实类名、字段及包装路径。`getters` 只列名称，含带参数的方法及相关 ivar，不会遍历执行未知方法。
- `avatar_request_start` 后的 `avatar_response`：记录请求标记、URL（不含查询参数）、最终 URL、HTTP 状态、MIME、字节数、错误域/错误码、是否取消、解码是否成功、请求是否仍属于当前行。
- `avatar_retry_scheduled` / `avatar_retries_exhausted`：区分暂时下载失败与三次尝试均失败。
- `avatar_assigned` / `avatar_cache_hit` / `overlay_state`：确认生产逻辑最终赋给预览的是已解码图片还是占位图。`loaded` 表示解码成功，不代表图片内容一定不是服务端默认头像；结合 URL 判断。
- `native_image_view`：原生相关视图类名、frame、hidden、alpha、是否有 UIImage、是否有 layer.contents 及可读取 URL。每个预览会在初始及稍后采样，用于比较原生头像何时出现。
- `native_avatar_poll_scheduled`：无 URL 时已经安排原生头像检查。
- `native_avatar_candidate`：头像视图绑定的账号、与原作者是否匹配、是否属于头部、是否有图、是否有匹配的赋图记录或本次绑定后的新图。
- `native_avatar_assigned`：账号与新鲜度检查通过，已将原生图片赋给预览。
- `avatar_field`：展示原作者对象上头像相关字段是否为空及返回值类型；URL 值另见 `model_url`。视图 shape 省略 UIKit 基类的通用方法，避免大量无关内容挤掉关键日志。

模型与视图记录通过 `row` 与含 `handle` 的 `preview_resolved` 关联。单行内作者更正通过后续 resolved 记录及请求 UUID 区分。最多采样 80 条帖子的模型，每条 3 次；磁盘写入由串行队列执行，队列积压时跳过新日志，以免阻塞 X。

本版不恢复旧的基于姓名标签与几何位置的 `BHRDCaptureRepostAuthor` 回退。只处理账号身份已验证的 `TUIAvatarImageView`，并核对当前行及图片到达时序。针对本问题使用独立 `BHRD_AVATAR_DIAGNOSTICS` 开关，不启用范围更广的旧 `Diagnostics.x`。

## 构建与回归

```sh
sh RepostsDownloads/build-avatar-diagnostics.sh
sh RepostsDownloads/tests/run_avatar_diagnostics.sh
```

构建入口自动设置 `BHRD_AVATAR_DIAGNOSTICS=1 PACKAGE_VERSION=2.4.4+diag.1`，生成别名、校验签名与包结构并输出 SHA-256。普通 `build.sh` 生成正式版 2.4.4。两种构建都从 clean 开始，避免沿用另一种模式的对象文件。

测试覆盖并发写入、JSON 行完整性、权限、轮转、URL 脱敏，并在开启真实日志实现的情况下再次执行 41 项生产预览生命周期检查，确认日志文件包含原生头像检查和赋图等完整过程。宿主视图由夹具模拟，不替代 X 12.24.1 / iOS 17.1.1 真机取证。当前版本完整验证结果与包校验值见 `RELEASE-2.4.4.md`。

GitHub Actions 同时构建标准包与诊断包，诊断产物名为 `XSuixin-avatar-diagnostics`。云端重建的包有独立 SHA-256，以其随附校验文件为准。
