# X 随心 2.4.5：SSP 广告拦截与默认日志

全屏图片纯图标按钮及此前头像修复保留。以后只发布一个 rootless DEB，默认附带日志查看和导出，不再要求用户选择另一种诊断包。

## 广告修复

设备报告提供了 Google 原生广告模型、SSP 开关和 `showSSPAdWhenNoPromotedMetadata` 等符号，以及 Google SDK 的缓存线索。这些证据支持独立于推广推文的广告路径；静态符号不能单独证明广告一定在客户端 hydration 阶段插入，也不能证明某个 hook 已在运行中触发。本次不猜测新的 SSP JSON 字段。

- 广告 feature switch 覆盖 TPSTwitterFeatureSwitches、TFSFeatureSwitches、可选的 TFSInstrumentedFeatureSwitches，每类七个读取入口。对不存在的类、方法或不匹配的返回类型不安装 hook。
- 补入 SSP 和 `video_configurations_dynamic_ad_enabled` 开关。布尔开关的 number/integer/raw 读取也覆盖；字符串广告位仍返回字符串，未知结构保持原值，不归零广告间距、超时或尺寸配置。
- 对签名匹配的 `showSSPAdWhenNoPromotedMetadata` 布尔 getter 返回关闭状态。
- 隐藏广告开启时，拦截 Google AdLoader 的 `loadRequest:` 和 `loadWithAdResponseString:`。异步通知仍匹配的代理“无广告可填充”，并完成对应批次；旧请求/已换代理不接收过期回调。关闭开关恢复 SDK 原方法。
- 原生 URTTimelineGoogleNativeAdViewModel / ImmersiveGoogleNativeAdCardViewModel 在现有模型过滤边界直接识别，保留相邻普通条目和游标。未通过隐藏全屏视图制造空白页，也未替换不明分页器的数据结构。
- 保留原有 URT 推广条目过滤。将 `ad_response_seen` 移到无 marker 提前返回之前，并补入开关读取、实际 hook 清单、原生模型识别、SDK 请求阻止与失败完成日志。

SDK 入口及委托用途依据 [Google AdLoader 官方文档](https://developers.google.com/ad-manager/mobile-ads-sdk/ios/api/reference/Classes/GADAdLoader)，无填充错误代码 1 依据 [GADErrorCode 官方文档](https://developers.google.com/admob/ios/api/reference/Enums/GADErrorCode)。不额外链接或安装广告 SDK，只处理 X 进程中已有且签名匹配的类。

## 查看和导出日志

打开 **X 随心 → 文件与诊断 → 诊断日志（查看 / 导出）**。

“刷新”显示当前日志最后最多 300 行；“导出”通过系统分享导出当前日志和上一份轮转日志的一致性快照。分享完成或取消后清理临时副本，原日志保留。日志始终只在本机写入，不自动上传。保留约 2 MB × 2 的滚动文件、排队上限和开关读取采样。

完整事件说明和旧路径兼容见 [诊断日志说明](AVATAR-DIAGNOSTICS.md)。marker=false 只能说明该次 JSON 没有已有标记，必须与 SDK/模型事件结合分析，不能单独据此判断广告位来源。

## 验证与安装

- 新增 48 项 SSP 策略、真实 Objective-C 运行时替换及 SDK 委托生命周期检查；常规检查共 1,002 项通过。测试用替换器模拟 Substrate 安装语义，不代表已验证手机 SDK 内部行为。
- 日志文件检查增至 45 项，包括并发、权限、轮转、异步读取、完整双文件快照和临时副本清理；41 项预览检查、开启日志的 48 项 SSP 检查及日志事件验证通过。
- 两档真实 HLS 验证通过。arm64 编译通过，只有既有依赖的链接废弃参数及节对齐提示。
- 包版本 2.4.5、iphoneos-arm64、最低 iOS 15.0、/var/jb 路径及仅 X 注入核验通过。核验器强制要求默认文件日志和查看/导出类存在；两份 CodeDirectory 的 8,080 个代码页哈希通过。

安装后彻底退出并重开 X，确认“隐藏广告”开启，再上下滑动约 20 条视频验证。本次没有在用户的 X 12.24.1 / iOS 17.1.1 真机验收，仍可能遇到其他广告路径；若仍出现，请从设置导出本版日志继续定位。报告、截图与用户原始日志不上传公共仓库。

安装包：`XSuixin_2.4.5_rootless.deb`，6,478,712 字节。

SHA-256：`cd8cd8dc6db20c354fbc5d14031c1219460d59989318d679df529c9498b33ddf`。
