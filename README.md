# OtterDiary iOS MVP

一个可运行的 SwiftUI 日记 App（MVP）：

- 无 AI 功能
- 新建日记（标题 / 正文 / 日期 / 心情）
- 日记列表展示与删除
- 「去年今日」卡片 + 详情列表
- 导出 JSON/Markdown 到 Files（可保存到 iCloud Drive）
- 使用系统原生 SwiftUI 组件，支持动态字体、深浅色、基础无障碍

## 项目结构

- `project.yml`：xcodegen 配置
- `OtterDiary/`：App 源码
- `OtterDiaryTests/`：单元测试（去年今日逻辑）

## 环境要求

- macOS + **完整 Xcode**（不是仅 Command Line Tools）
- Homebrew（用于安装 xcodegen）

## 快速开始

```bash
cd /Users/xiarui/openclaw-test
brew install xcodegen
xcodegen generate
open OtterDiary.xcodeproj
```

在 Xcode 里：

1. 选择 `OtterDiary` scheme
2. 选择模拟器（如 iPhone 16）
3. `⌘R` 运行

## 命令行构建（模拟器）

```bash
xcodebuild \
  -project OtterDiary.xcodeproj \
  -scheme OtterDiary \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

## 运行单测

```bash
xcodebuild \
  -project OtterDiary.xcodeproj \
  -scheme OtterDiary \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## 真机部署

1. Xcode 打开 `OtterDiary.xcodeproj`
2. Target → Signing & Capabilities
3. 勾选 Automatically manage signing
4. 选择你的 Team
5. 修改 `PRODUCT_BUNDLE_IDENTIFIER` 为你唯一的包名（如 `com.yourname.otterdiary`）
6. 连接真机并运行

> 如果要更稳定使用 iCloud Drive，可在 Capabilities 中开启 iCloud（iCloud Documents）。

## 说明

本仓库当前代码可生成工程并满足 MVP 功能；若命令行 `xcodebuild` 失败，请确认本机已安装完整 Xcode 并执行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

