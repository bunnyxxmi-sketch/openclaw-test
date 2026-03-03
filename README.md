# OtterDiary iOS MVP

一个可运行的 SwiftUI 日记 App（MVP）：

- 无 AI 功能
- 新建日记（标题 / 正文 / 日期 / 心情）
- 日记列表展示与删除
- 「去年今日」卡片 + 详情列表
- 导出 JSON/Markdown 到 Files（可保存到 iCloud Drive）
- 可选 iCloud 同步开关（基于 iCloud Documents JSON 同步桥接，离线可用）
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
2. 选择模拟器（如 iPhone 17）
3. `⌘R` 运行

## 命令行构建（模拟器）

```bash
xcodebuild \
  -project OtterDiary.xcodeproj \
  -scheme OtterDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

## 运行单测

```bash
xcodebuild \
  -project OtterDiary.xcodeproj \
  -scheme OtterDiary \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  test
```

## 启用 iCloud 同步（必做配置）

> App 内的“iCloud 同步”开关依赖 Target 的 iCloud Capability。未开启时会显示“不可用”。

1. Xcode 打开 `OtterDiary.xcodeproj`
2. 选中 **Target: OtterDiary** → **Signing & Capabilities**
3. 点击 `+ Capability`，添加 **iCloud**
4. 勾选：
   - **iCloud Documents**
   - （可选）CloudKit（后续演进可用）
5. 在 **Containers** 中选择/创建默认容器（通常 `iCloud.<bundle-id>`）
6. 确保 Entitlements 文件中有：
   - `com.apple.developer.icloud-container-identifiers`
   - `com.apple.developer.ubiquity-container-identifiers`
   - `com.apple.developer.ubiquity-kvstore-identifier`
7. 真机需登录 iCloud；模拟器需在 Settings 登录 Apple ID 才能实际同步

## iCloud 同步验证步骤（模拟器/真机）

1. 在设备 A 安装运行后，进入设置页，开启“iCloud 同步”
2. 新建一条日记，返回时间线确认可见
3. 在设备 B（同 Apple ID）运行同一构建，开启“iCloud 同步”
4. 进入首页后应自动拉取并合并数据
5. 冲突验证：两端修改同一条记录后，以 `updatedAt` 较新的版本为准（last-write-wins）
6. 断网验证：关闭网络仍可新建/删除（本地 JSON 正常）；恢复网络后自动尝试同步

## 真机部署

1. Xcode 打开 `OtterDiary.xcodeproj`
2. Target → Signing & Capabilities
3. 勾选 Automatically manage signing
4. 选择你的 Team
5. 修改 `PRODUCT_BUNDLE_IDENTIFIER` 为你唯一的包名（如 `com.yourname.otterdiary`）
6. 连接真机并运行

## 说明

本仓库当前代码可生成工程并满足 MVP 功能；若命令行 `xcodebuild` 失败，请确认本机已安装完整 Xcode 并执行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
