# 2.4.5 起默认内置诊断日志

以后只交付一个 rootless DEB，不再区分普通版和诊断版。版本 2.4.5 包含 SSP 广告修复及日志查看/导出功能，日志中的 build 字段为 2.4.5。

## 在 X 内查看与导出

1. 安装后彻底退出并重开 X，确认“隐藏广告”开启。
2. 进入竖屏视频流，连续查看约 20 条视频。若出现广告，停留 5 秒。
3. 打开 **X 随心 → 文件与诊断 → 诊断日志（查看 / 导出）**。
4. 点击“刷新”查看当前日志末尾最多 300 行，点击“导出”通过系统分享发送完整日志。导出包括当前文件和上一份轮转文件，使用独立快照，不会删除原日志。
5. 可以把导出的文件发回本对话。仅手动导出，不自动上传。

磁盘路径兼容旧版本：`<X 数据容器>/Library/Application Support/XSuixinDownloads/avatar-diag.log`，上一份为 `avatar-diag.log.1`。日志含账号/帖子标识和不带查询参数的头像 URL 路径，不含正文、图片数据、Cookie 或请求头。不要把个人日志提交到公共仓库。每个文件约 2 MB，最多保留一份轮转备份；串行写入、限制排队数量，重复广告开关读取按键和方法采样。导出临时快照在分享完成或取消后清理。

## SSP 广告事件

- `ad_runtime_inventory`：启动及启动后补扫发现的 Google 广告相关类、实际安装的 hook。列出名字不等于已确认它参与了本次广告展示。
- `ad_switch_read`：读取类、方法、广告键、原始值类型和是否覆盖；不会写广告请求或账户信息。类型不匹配的 raw 配置保持原值，数值间距不归零。
- `google_ad_request_blocked`：已阻止 Google AdLoader 的加载入口，记录是否能通知代理。
- `google_ad_no_fill`：已向仍匹配的代理发送无广告可填充回调。
- `immersive_ad_model`：已有模型过滤边界遇到明确的 Google 原生广告模型，不是构造函数跟踪。
- `ad_response_seen`：在推广 marker 的提前返回之前记录。包括 eligible/enabled/marker/bytes，因关闭开关、空数据或超大数据跳过时也记录 eligible=false。
- `ad_response_checked`：符合旧 URT 判定条件的响应是否实际发生过滤。

**marker=false 只代表本次 JSON 没有已知推广标记，不能单独证明它没有广告，也不能单独判定广告是在客户端插入。** 需要联合开关、SDK 调用及模型事件，必要时补充准确的响应结构。旧日志可能来自 2.4.3/2.4.4，请核对 build 和 session_start 的时间。

## 头像事件

保留 preview_resolved、avatar_missing_url、model_shape、model_url、avatar_field、avatar_request_start、avatar_response、avatar_assigned、avatar_cache_hit、avatar_retry_scheduled、avatar_retries_exhausted、overlay_state，以及 native_avatar_poll_scheduled、native_avatar_candidate、native_avatar_assigned。

这些事件通过 row、handle 和请求 UUID 关联，区分 URL 缺失、下载失败、旧请求丢弃及核对身份后的原生位图回退。模型 shape 只列相关属性/方法名称，不遍历执行未知方法；最多采样 80 条帖子的模型，每条 3 次。

## 构建约定

```sh
sh RepostsDownloads/build.sh
sh RepostsDownloads/tests/run_all.sh
```

Makefile 默认编入日志、查看和导出代码；包核验器会拒绝缺少这些功能的包。旧 build-avatar-diagnostics.sh 仅作为兼容入口调用 build.sh，不再生成额外版本。GitHub Actions 只输出 XSuixin-rootless 一份产物。当前修复依据、验证与包校验值见 RELEASE-2.4.5.md。
