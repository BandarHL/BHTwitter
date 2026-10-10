# X 随心 2.4.6：全屏图片保存到照片

在全屏图片右侧悬浮三个点的“图片工具箱”里新增 **保存图片到照片**。复制图标、原有工具和隐藏转推详情行为保留。

## 保存方式

- 优先复用原图获取路径。JPEG、PNG、GIF、HEIC 等支持格式以原始数据提交 Photos，保留可用的格式和方向信息。其他静态格式转为方向正确的 PNG。
- 获取原图失败或没有地址时，尝试保存当前已加载图片，状态反馈为“已保存当前图到照片”。当前位图通过 UIImage 绘制后编码，避免忽略旋转/镜像方向；不截取含悬浮控件的整屏画面。
- 只请求添加照片权限，先检查宿主应用权限说明。被拒绝时提示并提供打开设置的选项；写入失败时显示系统错误或可重试说明。
- 下载、编码和授权完成后核对图片身份、请求代次及全屏状态。切图/退出会取消尚未提交的保存，晚到回调不保存旧图片。Photos 已接受的写入继续完成并记录结果，原页面不接收过期反馈。
- 操作期间暂时禁用复制及更多按钮，防止重复请求。获取、授权、提交和结果事件进入现有本机日志，不记录图像内容或完整请求。

权限和资源提交采用 Apple 的 [add-only 权限](https://developer.apple.com/documentation/photos/phaccesslevel/addonly)、[授权请求](https://developer.apple.com/documentation/photos/phphotolibrary/requestauthorization(for:handler:)) 和 [图片资源提交 API](https://developer.apple.com/documentation/photos/phassetcreationrequest/addresource(with:data:options:))。

## 安装与复验

安装 `XSuixin_2.4.6_rootless.deb` 后彻底退出并重开 X。在全屏图片页面点击右侧三个点，选择“保存图片到照片”，首次按系统提示允许 X 添加照片，然后到照片中确认图片。

只提供一个默认带日志的 DEB。日志仍可在 **X 随心 → 文件与诊断 → 诊断日志（查看 / 导出）** 获取。版本为 `build=2.4.6`、`revision=photo-save-1`，新增 photo_save_start/fetch/prepare/authorization/committed/result 事件。

## 验证

- 新增 31 项图片数据、Photos 权限及保存生命周期检查：PNG/JPEG/GIF 原始字节、静态转换与 EXIF 方向、权限说明缺失、拒绝/授权、授权期间换图、取消、重复回调、已提交写入及错误结果。
- 常规回归共 1,026 项通过；45 项日志文件检查、82 项日志模式预览检查、3 项广告日志检查、开启日志的 31 项保存检查和日志事件覆盖验证通过。两档真实 HLS 验证通过。
- arm64 编译与版本 2.4.6、iphoneos-arm64、最低 iOS 15.0、/var/jb 路径、仅 X 注入范围核验通过。核验器确认保存服务、菜单动作、详情入口和默认日志/导出代码存在。
- 两份 CodeDirectory 共 8,088 个代码页哈希通过。只有既有依赖库链接废弃参数和节对齐提示，无编译错误。
- Photos 测试使用可控提供器，直接执行生产保存服务；菜单及系统权限提示尚未在用户的 X 12.24.1 / iOS 17.1.1 手机上验收。

文件大小：6,483,090 字节。

SHA-256：`16a5ced1c7528a5b9fe113579efec68bbc1bc38ee2e3d58d2d69d9712986b68e`。
