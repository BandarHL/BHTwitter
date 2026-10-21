# 2.5.0-2 验收记录、基础日志与临时详细采集

当前源码目标构建及日志采用完整构建号（2.5.0-2）、数字修订及干净源码提交号，运行状态与诊断页面均可查看。一个 DEB 默认保留基础日志，不区分诊断版。构建来源还包含仓库身份，正式仓库为 Caun1112/XSuixin；本轮真机效果仍待复验。

2.4.7-6 真机已验证日志查看、脱敏保存及 USB 取回，但发现日志导出、保留清理及验收快照中的本地 JSON 会进入宿主响应 hook，再产生诊断记录；当次摘要有 61,122 条丢弃记录和 128 条待写记录。2.4.7-7 用解析线程内的本地读取标记隔离这些路径，并在嵌套、无效 JSON 和异常后恢复原标记。真实宿主 JSON 继续经过原过滤逻辑。新增 59 项组合检查把宿主解析 hook 与生产验收快照、日志清理和导出同时启用，确认这些操作不会生成自身反馈或递归积压。

“运行状态与恢复 → 实际运行验收”可开始一轮、查看真实阶段并导出验收报告与性能采样。验收记录独立于文件日志队列：文件队列满时仍保留关键结果；无法写入验收记录时页面显示存储错误。记录按构建、提交和轮次隔离，跨重启保存，最多保留 120 条阶段与 20 次启动。新轮次替换旧记录；需要保留旧轮次请先导出。只记录固定阶段、数值和错误域/码，不保存账号、帖子 ID 或图片链接。

## 2.5.0-2 出口结构与新增分类

导出采用exportSchema=2，仅保留已知事件的允许字段、固定枚举、有限数值及由已知组件构成的读取路径。未知事件只输出有效构建元数据；自由文本、未知身份别名、未知路径/字段默认省略，错误域只保留已知集合。原始本地日志不被改写。需要核对新的私有类型时，先在本机详细模式检查，不能把导出中省略的信息解释为宿主不存在。

`resourceDecisionCounts`在基础模式区分unsupported_scheme/host/extension/content_type，不包含原始URL。`home_header_resolution`记录扫描截断、标签/控制器/共同表头识别、Add命中区域及固定拒绝枚举；每窗口有时间及条数预算。两者为后续实机定位提供证据，不自动证明下载或首页限制已通过。

HLS的`stream_probe_invalidated`表示选择已失效，随后取消引擎并释放资源。人工性能评价与自动告警分别保留，普通采样不覆盖人工失败。

## 查看、管理和导出

X 随心 → 文件与诊断 → 诊断日志。管理菜单支持刷新、清空、开启详细采集10分钟或提前停止；默认关闭详细模型/视图反射。导出默认脱敏，移除账号、帖子标识、媒体地址及对应嵌套字段，并包含统计摘要。没有自动上传。

原始日志仅在本机；详细模式可能包含浏览账号/帖子线索，开启前会说明，10分钟后自动停止。当前与上一份各约2MB，清理超过7天的文件及记录。排队上限、丢弃和写入失败计数在查看与导出摘要中显示，避免将缺少记录误判为没有事件。方法/ivar反射移到后台并缓存，UI快照仍仅在主线程读取。

路径保持兼容：X 数据容器内 Library/Application Support/XSuixinDownloads/avatar-diag.log；上一份为 avatar-diag.log.1。导出使用独立快照，分享完成或取消后清理临时副本，原日志保留。

## 2.5.0 日志降噪及复制验证

普通 `ad_response_seen` / `marker=false` 保留首条，其余计数与字节数汇总成 `ad_response_summary`，最多等待 30 秒，查看/导出/显式 flush 会提前汇总。并发突发不会为每条未命中创建文件写入任务；最多一个聚合计时回调。`aggregatedRecords` 表示主动合并，`droppedRecords` 仍是真实队列溢出，`writeFailures` 为实际文件写入失败，三者不互相替代。清空日志同步重置累计与待汇总计数。广告命中、真实失败、警告和其他功能事件继续逐条写入，仍受 128 条队列容量限制；验收关键结果独立保存。

`photo_copy_payload` 记录当前图片未就绪或编码/像素预算失败；`photo_clipboard_result` 记录写入验证结果和固定失败原因。验证只在本次写入后读取本次数据，不记录图像、剪贴板文本或链接。成功证明即时写入，并不证明稍后其他 App 能粘贴。

视频详细诊断中 `resourceProbes` 保留 scheme/host/extension 类别及拒绝原因；原始地址仍脱敏。当前项样本最多 3 次且全局有预算，不放宽下载域名或把自定义播放 URL 改写为网络地址。

## 基础事件

2.4.7-7 的详细采集额外提供 `fullscreen_photo_resolution`：当前选中图片视图、有限单对象绑定路径、已尝试 getter 的存在性/类型与固定拒绝原因，以及位图来源和像素。每视图最多 3 次、每全屏容器最多 48 次，单条不超过 24 KB；不记录地址、账号或帖子身份，不检查邻图或媒体数组内容。原图地址不可用时，可开启详细采集并按 1 → 2 → 4 → 1 切图，再导出日志，帮助定位宿主兼容路径。

- repost_detail_navigation：原生行选择调用、失效行或缺少有效选择处理器；不代表真实页面已完成验收。
- photo_save_start/fetch/prepare/authorization/committed/result：保存来源、数据大小、权限与结果；不记录图像内容。原图失败现在先询问是否改存当前图。
- ad_response_seen/ad_response_checked：原有推广标记及过滤结果。marker=false 不能单独确定广告来源，SSP路径仍未验证覆盖。
- session_start：X/iOS与完整插件构建身份。
- repost_detail_visible/return/confirmation_timeout：核对原帖详情与返回隐藏状态；未知身份、离屏行及超时保持待确认。
- recovery_invoked/safety_pause_changed：实际恢复菜单展示、暂停标记保存；下一进程启动才确认暂停/恢复生效。
- performance_started/sample/finished/memory_warning：用户主动启动的前台显示回调、内存及热状态采样，不自动证明性能通过。
- acceptance_export：生成、展示、系统分享完成/取消/失败，分享完成不证明接收方已收到。
- fullscreen_video_resolution：点击轮次、当前可见资源读取、菜单实际呈现、不可用或切换取消；发现计数和包装路径供定位，不记录图像内容。菜单呈现仅说明读取入口成功，不证明传输完成。验收报告仅保留固定原因和数值。
- fullscreen_download_visibility：右侧独立入口的实际显示/暂隐、模态遮挡和布局尺寸；仅状态变化时记录，显示不再要求已解析下载 URL。路径 `current_inline_actions.viewModel` / `current_card.media` 表示已从当前原生参数源读取。
- TAV 读取日志保留 `stage`、有限 `resourceProbePaths` 和 `candidateResults`，以及成功/失败候选计数；路径和对象类名不包含 URL、播放内容或账号。可以区分内部状态、当前播放项、播放器技术、原生 AV 项及清晰度端点的读取结果，避免只有最终 `source` 一项。
- `current_card.status` 表示从当前 Swift 卡片帖子取得原生 MP4 参数。`stream_probe_start/bound/wait/callback/result` 记录 HLS 探测会话与耗时；`stream_download_start/bound/progress/callback/result` 记录传输和本地文件结果；`stream_job_cancel/timeout` 记录主动取消/看门狗。每个 job 绑定验收轮次，迟到回调不会覆盖新的任务。
- 15 秒读超时与 45 秒探测等待分开；FFmpegKit `withTimeout` 仅用于消息返回等待。`diagnosticTail` 是固定错误类别集合，不是原始 stderr。系统网络代理的速度无法由插件自动保证。
- 详细模式额外包含头像模型和原生视图线索，默认不做重型采集。

## 恢复与版本出处

运行状态显示已安装/实际调用/不可用的能力、完整构建和提交；未实测项目明确标注。整体暂停后重启跳过功能注入，三指长按1.5秒可打开后备恢复菜单。X无法启动时，Filza可在数据容器Library/Application Support/XSuixinSafety创建disabled文件；恢复后需重启。

版本与发布规则见 BUILD-POLICY.md，设备待验项目见 DEVICE-ACCEPTANCE.md。核验器要求本机日志/导出、恢复、运行状态、验收页与性能观察、照片保存、独立视频入口、TAV/Swift 原生参数与流媒体阶段和正确来源存在。旧build-avatar-diagnostics.sh仅为build.sh兼容入口。当前说明见 [RELEASE-2.5.0-2.md](RELEASE-2.5.0-2.md)。
