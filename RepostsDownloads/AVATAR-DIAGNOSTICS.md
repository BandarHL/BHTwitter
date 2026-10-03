# 2.4.7-1 基础日志与临时详细采集

当前包和日志采用完整构建号（2.4.7-1）、数字修订及干净源码提交号，运行状态与诊断页面均可查看。一个 DEB 默认保留基础日志，不区分诊断版。

## 查看、管理和导出

X 随心 → 文件与诊断 → 诊断日志。管理菜单支持刷新、清空、开启详细采集10分钟或提前停止；默认关闭详细模型/视图反射。导出默认脱敏，移除账号、帖子标识、媒体地址及对应嵌套字段，并包含统计摘要。没有自动上传。

原始日志仅在本机；详细模式可能包含浏览账号/帖子线索，开启前会说明，10分钟后自动停止。当前与上一份各约2MB，清理超过7天的文件及记录。排队上限、丢弃和写入失败计数在查看与导出摘要中显示，避免将缺少记录误判为没有事件。方法/ivar反射移到后台并缓存，UI快照仍仅在主线程读取。

路径保持兼容：X 数据容器内 Library/Application Support/XSuixinDownloads/avatar-diag.log；上一份为 avatar-diag.log.1。导出使用独立快照，分享完成或取消后清理临时副本，原日志保留。

## 基础事件

- repost_detail_navigation：原生行选择调用、失效行或缺少有效选择处理器；不代表真实页面已完成验收。
- photo_save_start/fetch/prepare/authorization/committed/result：保存来源、数据大小、权限与结果；不记录图像内容。原图失败现在先询问是否改存当前图。
- ad_response_seen/ad_response_checked：原有推广标记及过滤结果。marker=false 不能单独确定广告来源，SSP路径仍未验证覆盖。
- session_start：X/iOS与完整插件构建身份。
- 详细模式额外包含头像模型和原生视图线索，默认不做重型采集。

## 恢复与版本出处

运行状态显示已安装/实际调用/不可用的能力、完整构建和提交；未实测项目明确标注。整体暂停后重启跳过功能注入，三指长按1.5秒可打开后备恢复菜单。X无法启动时，Filza可在数据容器Library/Application Support/XSuixinSafety创建disabled文件；恢复后需重启。

版本与发布规则见 BUILD-POLICY.md，设备待验项目见 DEVICE-ACCEPTANCE.md。核验器要求本机日志/导出、恢复、运行状态、照片保存和正确来源存在。旧build-avatar-diagnostics.sh仅为build.sh兼容入口。当前说明见RELEASE-2.4.7-1.md。
