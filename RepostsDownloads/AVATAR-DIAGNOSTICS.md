# 2.4.6 默认诊断日志

当前版本新增全屏图片保存到照片，只交付一个默认内置日志的 rootless DEB。日志的 build 为 2.4.6，revision 为 photo-save-1；不区分标准包和诊断包。

## 在 X 内查看与导出

1. 安装新的 XSuixin_2.4.6_rootless.deb，彻底退出并重新打开 X。
2. 复现需要排查的问题。例如进入视频流连续查看约 20 条视频，出现广告时停留 5 秒。
3. 打开 **X 随心 → 文件与诊断 → 诊断日志（查看 / 导出）**。
4. “刷新”显示当前日志最后最多 300 行；“导出”通过系统分享输出当前文件和上一份轮转文件的完整快照。
5. 分享完成或取消后清理临时副本，原日志保留，不自动上传。

路径保持兼容：`<X 数据容器>/Library/Application Support/XSuixinDownloads/avatar-diag.log`，上一份为 `avatar-diag.log.1`。日志可能含账号/帖子标识和不带查询参数的头像 URL 路径，不记录正文、图片数据、Cookie 或请求头。每个文件约 2 MB，最多保留一份备份，串行写入并限制排队数量。不要把个人日志提交到公共仓库。

## 广告事件

本次保留回退后 2.4.4 的广告逻辑，不恢复旧 2.4.5 的 SSP 试验代码。请按 revision 区分旧日志。

- `ad_response_seen`：在 2.4.4 的推广 marker 判定后、提前返回前记录 bytes 和 marker。该打点不改变响应或过滤结果。关闭广告过滤、空数据、超大数据仍按 2.4.4 原逻辑跳过。
- `ad_response_checked`：符合旧 URT 判定条件的响应是否实际发生过滤。

历史 SSP 试验路径已在此前回退中移除：ad_switch_read、ad_runtime_inventory、immersive_ad_model、google_ad_request_blocked、google_ad_no_fill。旧文件里可能仍保留这些记录，请按 revision/session_start 时间区分。

marker=false 只表示该次 JSON 没有已知推广标记，不能据此单独确定广告来源。本次是隐藏转推点击修复，不涉及新增视频流广告拦截。

## 隐藏转推详情事件

`repost_detail_navigation` 记录当前 row 与 result：`native_row_selection` 表示调用了原生行选择方法；`stale_or_unavailable_row` 表示行绑定失效或列表仍在批次更新；`native_selection_unavailable` 表示当前宿主没有签名匹配的选择处理器。它不记录正文，也不表示已经完成真机页面验收。

## 头像事件

保存图片时另有 `photo_save_start`、`photo_save_fetch`、`photo_save_prepare`、`photo_save_authorization`、`photo_save_committed` 和 `photo_save_result`。只记录是否有 URL/位图、字节数、格式、是否用了当前显示图、权限状态和错误域/码；不记录图片内容。若提交后已退出全屏，结果仍写入日志，原界面不接收过期反馈。

保留 preview_resolved、avatar_missing_url、model_shape、model_url、avatar_field、avatar_request_start、avatar_response、avatar_assigned、avatar_cache_hit、avatar_retry_scheduled、avatar_retries_exhausted、overlay_state，以及 native_avatar_poll_scheduled、native_avatar_candidate、native_avatar_assigned。

这些事件通过 row、handle 和请求 UUID 关联，区分 URL 缺失、下载失败、旧请求丢弃和原生位图回退。模型 shape 只列相关属性/方法名称，不遍历执行未知方法；最多采样 80 条帖子的模型，每条 3 次。

## 构建约定

```sh
sh RepostsDownloads/build.sh
sh RepostsDownloads/tests/run_all.sh
```

Makefile 默认编入日志及查看/导出界面；核验器检查详情入口和图片保存服务存在、旧时间线展开 handler 已移除，且没有重新带入 SSP 试验 hook。旧 build-avatar-diagnostics.sh 只是 build.sh 的兼容入口，不生成额外版本。GitHub Actions 只输出 XSuixin-rootless 一份产物。说明见 RELEASE-2.4.6.md。
