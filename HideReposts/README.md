# 屏蔽转推（roothide）

这是从 BHTwitter 独立出来的常开 tweak，仅负责隐藏 X/Twitter 时间线里的转推内容，不依赖 BHTwitter 的设置页、资源包或 Cephei。

## 目标环境

- roothide Bootstrap
- iOS 15.0 或更高版本
- arm64e 设备

## 构建

先安装支持 roothide 的 [roothide/theos](https://github.com/roothide/theos)，然后执行：

```bash
cd HideReposts
export THEOS="$HOME/theos"
make clean package FINALPACKAGE=1
```

Makefile 已固定使用 `roothide` scheme。注入 X/Twitter 的 dylib 编译为 `arm64`，deb 包架构由 roothide Theos 标记为 `iphoneos-arm64e`；生成的 deb 位于 `packages/`。

安装后，请在 roothide Bootstrap 的“App List”中为 X/Twitter 开启 tweak 注入，再重新启动 X/Twitter。
