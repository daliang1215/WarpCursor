# WarpCursor（原生重写版）

![Build](https://github.com/daliang1215/WarpCursor/actions/workflows/build.yml/badge.svg)

用全局快捷键在多块显示器之间瞬间移动光标的 macOS 菜单栏小工具。

这是经典停更工具 CatchMouse（ftnew.com，v1.2，2011 年停更）的 clean-room 重写版（现改名 WarpCursor）：
原版是闭源 Intel 二进制，在 Apple Silicon 上只能靠 Rosetta 运行。本项目用 Swift
完全重写，原生支持 arm64，不依赖 Rosetta。

- **最低支持 macOS 14 Sonoma**，已考虑 macOS 15 / 26 / 27 的兼容性
- **零系统权限申请**：默认 Carbon 热键引擎不需要辅助功能 / 录屏 / 输入监控任何权限
- 无第三方依赖，单二进制，菜单栏常驻（无 Dock 图标）

## 功能

- 🖥️ 每块显示器一个全局快捷键 → 光标 warp 到该屏中央
  - 默认：`⌃⌘,` / `⌃⌘.` / `⌃⌘/` = 左 / 中 / 右显示器
- 🔁 `⌃⌥→` / `⌃⌥←` 在显示器之间循环切换
- ⚙️ 偏好设置里可为每块显示器录制自定义快捷键（Esc 取消，Delete 清空）
- 🔗 绑定按显示器 UUID 持久化，热插拔 / 换接口后不丢失
- 🔢 “识别显示器”在每块屏幕上闪现大数字编号
- ✨ 跳转后在落点闪现放大的光标 + 圆环（约 1 秒），一眼看到光标在哪块屏上
- 🚀 可选开机自动启动（需要正式签名版本，见下）
- ⌨️ 命令行模式：`--list` / `--move N` / `--move-next` / `--move-prev`，方便脚本调用
- 🔧 双热键引擎：Carbon（默认，免权限）/ 事件监听（备用，需辅助功能权限）

## 构建

只需要 Xcode Command Line Tools，不需要完整 Xcode：

```sh
xcode-select --install   # 如未安装
./build_app.sh
```

产物在 `build/WarpCursor.app`（纯 arm64）。需要双架构时：

```sh
UNIVERSAL=1 ./build_app.sh   # arm64 + x86_64
```

安装运行：

```sh
cp -R build/WarpCursor.app /Applications/
open /Applications/WarpCursor.app
```

菜单栏会出现一个光标图标。点图标 → 偏好设置可自定义所有快捷键。

开发调试：

```sh
swift build                              # debug 构建
swift run WarpCursor --list              # 列出显示器
.build/debug/WarpCursor --move 2         # 光标移到第 2 块屏
```

## 权限说明

默认 Carbon 引擎**不需要申请任何系统权限**，开箱即用。
只有当你在偏好设置里手动切换到“事件监听”引擎时，才需要去
“系统设置 → 隐私与安全性 → 辅助功能”中授予权限。

## 开机启动说明

偏好设置里的“开机自动启动”分两种机制，App 会自动选择：

- **正式签名版**（Developer ID / Apple Development）：走 `SMAppService`
  系统登录项，原生体验。
- **ad-hoc 免费版**（`./build_app.sh` 默认）：走 LaunchAgent，
  在 `~/Library/LaunchAgents/com.warpcursor.app.plist` 写一个启动项，
  无需任何签名、永久有效。App 移动位置后下次启动会自动修正路径，
  无需手动干预。

ad-hoc 签名每次构建身份都会变化，直接用 `SMAppService` 会在系统里留下
无法清理的残留登录项，所以免费版不走那条路。

## 分发（三条路线）

| 路线 | 签名 | 适合 |
|---|---|---|
| GitHub Releases（免费） | Developer ID + 公证 | 公开发布，`scripts/notarize.sh` 一键签名公证 |
| Mac App Store（付费） | Apple Distribution | 上架销售，见下文 |
| 自己用 | ad-hoc（`./build_app.sh` 默认） | Gatekeeper 会提示，右键 → 打开即可 |

### 路线一：GitHub 自动编译发布（无需本地环境）

仓库已配好 GitHub Actions（`.github/workflows/build.yml`）：

- 每次 push / PR 自动编译 + 打 DMG（`macos-15`，纯 arm64）
- 打 tag 推送（如 `git tag v1.0.0 && git push origin v1.0.0`）后，DMG 自动发布到 GitHub Releases

```sh
git init && git add -A && git commit -m "WarpCursor v1.0.0"
git remote add origin git@github.com:daliang1215/WarpCursor.git
git push -u origin main
git tag v1.0.0 && git push origin v1.0.0   # 触发 Release
```

去掉 Gatekeeper 拦截（发给别人用时建议）：需要 Apple Developer Program，
设置好环境变量后运行 `./scripts/notarize.sh`（Developer ID 签名 + 公证 + 装订）。
所需变量：`APPLE_TEAM_ID`、`SIGNING_IDENTITY`、`NOTARY_APPLE_ID`、
`NOTARY_APP_PASSWORD`、`NOTARY_TEAM_ID`。

### 路线二：上架 Mac App Store（付费应用）

已验证可行：`CGWarpMouseCursorPosition` 与 Carbon `RegisterEventHotKey`
都是沙盒兼容的公开 API，无需任何特殊权限。App Store 版会自动：

- 启用 App Sandbox（`Resources/WarpCursor.entitlements`）
- 热键引擎锁定为 Carbon（事件监听引擎在沙盒下不可用，已自动禁用）
- 已知限制：macOS 15+ 沙盒下，只用 Option/Option+Shift 做修饰键的
  全局热键不会触发（Apple bug FB15168205），偏好设置里有提示

步骤（需要 Apple Developer Program，$99/年）：

1. `python3 scripts/generate_xcodeproj.py` 生成 `WarpCursor.xcodeproj`
   （已生成好并提交在仓库里，增删源文件后可重新生成）
2. 用 Xcode 打开，在 Signing & Capabilities 里选择你的 Team，
   Bundle ID 改成你自己的反向域名（如 `com.你的名字.warpcursor`）
3. Product → Archive → Distribute App → App Store Connect
4. 在 App Store Connect 新建 App 记录，填写介绍、截图、定价（付费选价格档），提交审核

注意：App Store 版与 GitHub 免费版建议用**不同的 Bundle ID**，
避免已安装用户的偏好设置串扰。

## 项目结构

```
Sources/WarpCursor/
  main.swift                    # 入口：CLI 分流 / 启动 App
  AppDelegate.swift             # 装配：热键 + 显示器 + 菜单
  DisplayManager.swift          # 显示器枚举 / 排序 / warp 光标
  CarbonHotKeyCenter.swift      # Carbon RegisterEventHotKey 封装（默认引擎）
  EventTapHotKeyCenter.swift    # CGEventTap 封装（备用引擎）
  HotKeyCenter.swift            # 引擎调度与绑定重装
  HotKeyCombo.swift / Modifiers.swift / KeyCodeNames.swift
  ShortcutRecorder.swift        # 快捷键录制控件
  PreferencesWindowController.swift  # 偏好设置窗口（纯代码 UI）
  StatusMenuController.swift    # 菜单栏图标与菜单
  IdentifyDisplays.swift        # 识别显示器（闪大数字）
  CursorFlash.swift             # 跳转后闪现放大的光标（约 1 秒）
  LaunchAtLogin.swift           # 开机启动：正式签名走 SMAppService，ad-hoc 走 LaunchAgent
  Persistence.swift             # UserDefaults 持久化（按显示器 UUID）
  CLI.swift                     # --list / --move 等命令行动作
Resources/
  Info.plist                    # LSUIElement 菜单栏 agent 等配置
  AppIcon.icns / MenuBarIcon.png # 应用图标 / 菜单栏图标（同设计）
  WarpCursor.entitlements        # App Sandbox（App Store 版）
WarpCursor.xcodeproj/           # Xcode 工程（App Store 打包用，可重新生成）
scripts/
  generate_icon.py              # 生成 AppIcon.icns / MenuBarIcon.png
  generate_xcodeproj.py         # 重新生成 WarpCursor.xcodeproj
  make_dmg.sh                   # 打 DMG（CI 用）
  notarize.sh                   # Developer ID 签名 + 公证（GitHub 分发用）
.github/workflows/build.yml    # CI：自动编译 + 打 tag 自动发 Release
build_app.sh                    # 一键构建 + 组装 .app + 签名
```

## 技术要点

- 全局热键：Carbon `RegisterEventHotKey`（macOS 14–27 均可用，免权限）；
  备用 `CGEventTap` 已实现，可在偏好设置中切换。
- 挪光标：`CGWarpMouseCursorPosition`，全程使用 Quartz 全局显示坐标系
  （`CGGetActiveDisplayList` + `CGDisplayBounds` + warp 同一坐标系，避免换算错误）。
- 显示器身份：`CGDisplayCreateUUIDFromDisplayID` 取 UUID 做持久化 key。
- 显示器热插拔：监听 `didChangeScreenParametersNotification` 自动重绑热键、刷新菜单。

## 许可

MIT License。独立 clean-room 实现，未使用原版的任何源码、二进制或素材。
