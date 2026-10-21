# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## 构建命令

需要先安装 [Theos](https://github.com/theos/theos) 和 [cyan](https://github.com/asdfzxcvbn/pyzule-rw)。

```bash
# Sideloaded（需要 packages/com.atebits.Tweetie2.ipa）
./build.sh --sideloaded

# TrollStore（需要 packages/com.atebits.Tweetie2.ipa）
./build.sh --trollstore

# Rootless .deb
./build.sh --rootless

# Rootfull .deb
./build.sh --rootfull
```

直接调用 make：
```bash
make          # debug build
make package  # 打包 .deb
make clean    # 清理构建产物
```

## 架构概览

这是一个 **iOS Theos tweak**，通过 Cydia Substrate 注入 Twitter/X 客户端进程，使用 Logos（`.x` 文件）语法 hook Objective-C 方法。

### 核心文件

- **`Tweak.x`** — 所有 hook 的入口，使用 `%hook`/`%orig` 语法拦截 Twitter 私有类方法
- **`BHTManager.m/.h`** — 功能开关管理器，所有设置读写通过 `NSUserDefaults` 完成，方法均为类方法（`+`）
- **`SettingsViewController.m/.h`** — 设置界面，基于 Cephei 框架（`HBListController`）
- **`TWHeaders.h`** — Twitter 私有类/协议的头文件声明

### 子模块/依赖目录

| 目录 | 用途 |
|------|------|
| `BHDownload/` | 视频下载逻辑 |
| `BHTBundle/` | Bundle 资源加载 |
| `ffmpeg/` | FFmpegKit 头文件（`.a` 静态库在 `lib/`） |
| `JGProgressHUD/` | 进度 HUD UI 组件 |
| `SAMKeychain/` | Keychain 访问（用于 Padlock 功能） |
| `Colours/` | 颜色工具 |
| `CustomTabBar/` | 自定义 Tab Bar |
| `ThemeColor/` | 主题颜色 |
| `AppIcon/` | 应用图标切换 |
| `keychainfix/` | Sideload 模式下的 Keychain 修复子项目 |

### 设置键（NSUserDefaults）

`BHTManager` 中每个 `+` 方法对应一个 `NSUserDefaults` 布尔键，例如 `dw_v`（下载视频）、`hide_promoted`（隐藏广告）等。首次启动时在 `T1AppDelegate` hook 中设置默认值（key: `FirstRun_4.3`）。

### 构建变体

- **Sideloaded/TrollStore**：`make SIDELOADED=1`，额外编译 `keychainfix` 子项目，用 `cyan` 注入 IPA
- **Rootless**：`THEOS_PACKAGE_SCHEME=rootless make package`
- **Rootfull**：`make package`（默认）
