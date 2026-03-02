# Otter Diary iOS MVP（无 AI）产品与技术说明

## 1. 产品目标与定位

**产品目标**：构建一个“海獭日记风格”的轻量 iOS 日记应用 MVP，强调温和、治愈、低打扰记录体验。  
**范围约束**：本阶段不接入任何 AI 能力（不做 AI 写作、AI 分析、AI 推荐）。

**核心体验关键词**：
- 1 分钟内快速记一条
- 可回看“去年今日”
- 数据可在多设备同步
- 数据可导出，保证可迁移

---

## 2. MVP 功能范围

### 2.1 必做功能（In Scope）

1. **日记 CRUD（基础）**
   - 新建日记：标题（可选）、正文（必填）、心情（可选）、标签（可选）
   - 浏览日记：按时间倒序展示
   - 编辑/删除日记

2. **首页聚合（Home）**
   - 今日快捷入口（快速新建）
   - 最近日记列表（近 7~30 条）
   - 去年今日卡片（若存在）

3. **去年今日（On This Day）**
   - 展示“同月同日”的历史日记（优先 N-1 年）
   - 若有多条，按时间排序并可展开

4. **iCloud 同步（CloudKit）**
   - 同一 Apple ID 下设备间自动同步
   - 冲突处理采用“最后写入时间优先 + 保留本地未提交变更”策略

5. **导出功能（Export）**
   - 导出 JSON（结构化备份）
   - 导出 Markdown（可读归档）
   - 使用 `ShareLink` / `UIActivityViewController` 分享到文件、AirDrop、第三方应用

### 2.2 非目标（Out of Scope）

- AI 续写/润色/总结
- 社交分享社区
- 跨平台（Android/Web）
- 富文本复杂排版（如图文混排编辑器）
- 端到端加密多方协同

---

## 3. 数据模型（MVP）

建议实体：`DiaryEntry`

- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `entryDate: Date`（日记所属日期，和创建时间可不同）
- `title: String?`
- `content: String`
- `mood: Mood?`（枚举）
- `tags: [String]`
- `isDeleted: Bool`（软删除，便于同步）

设计要点：
- `entryDate` 用于“去年今日”计算，不依赖 `createdAt`
- `updatedAt` 作为同步冲突决策字段
- `isDeleted` 用于 CloudKit tombstone，避免“删了又回来”

---

## 4. “去年今日”逻辑设计

### 4.1 目标
用户在任意一天打开 App，可快速看到历史同一天内容，增强“时间回响感”。

### 4.2 规则

1. 基准日期：`targetDate`（默认今天）
2. 匹配条件：历史记录中 `month/day` 与 `targetDate` 相同
3. 年份过滤：仅保留 `< targetYear` 的记录
4. 优先策略：
   - 优先展示 `targetYear - 1` 的记录
   - 若无，再展示更早年份（可限制最近 5 年）
5. 闰年处理：
   - 对 `2/29`：非闰年时可降级匹配 `2/28`（可配置）
6. 排序：按 `entryDate` 降序（先近后远）

### 4.3 性能建议

- 小规模（< 1 万条）可内存过滤
- 增长后可建立按 `MM-dd` 的索引字段（例如 `monthDayKey = "03-02"`）
- 首页只查询当日 key，避免全量扫描

---

## 5. iCloud 同步方案（MVP）

### 5.1 技术选型

- 首选：**SwiftData + CloudKit**（iOS 新项目默认路径，开发效率高）
- 备选：Core Data + CloudKit（若团队已有存量）

### 5.2 同步策略

- 自动同步：依赖系统 CloudKit 同步周期
- 冲突合并：
  - 字段级简化为实体级：`updatedAt` 较新者覆盖
  - 删除优先：若远端为 tombstone（`isDeleted=true`），本地删除
- 离线写入：先写本地，网络恢复后同步

### 5.3 异常与降级

- 未登录 iCloud：提示“当前为本地模式”
- iCloud 空间不足/权限失败：提示并允许继续本地记录
- 同步状态提示：设置页展示“上次同步时间/错误简述”

---

## 6. 导出方案（MVP）

### 6.1 导出格式

1. **JSON**（机器可读、可回导）
   - 包含完整字段（含元数据）
2. **Markdown**（人类可读）
   - 每条日记输出标题、日期、心情、标签、正文

### 6.2 导出流程

1. 用户选择格式（JSON / Markdown）
2. 拉取本地有效数据（`isDeleted == false`）
3. 生成临时文件到 `tmp` 目录
4. 通过系统分享面板导出

### 6.3 数据安全

- 文件默认由用户自行选择保存位置
- 不上传第三方服务器
- 可选：未来支持 ZIP + 密码（本期不做）

---

## 7. iOS 26 设计规范要点（MVP 采纳）

> 以下为工程实践向要点，聚焦 SwiftUI 原生体验与可访问性。

1. **层级清晰、减少装饰噪音**
   - 首页采用卡片分区：Today / Recent / On This Day
   - 通过留白和字体层级替代过重边框

2. **动态字体与可访问性优先**
   - 全面使用系统文字样式（`.title`, `.headline`, `.body`）
   - 支持 Dynamic Type，避免写死字号

3. **语义化颜色与深色模式**
   - 使用 `Color.primary/secondary`、语义背景色
   - 不硬编码浅色模式专用颜色

4. **手势与反馈一致性**
   - 删除/归档动作使用系统 swipe actions
   - 导出成功/失败给出轻量 toast 或 alert

5. **隐私可感知**
   - 明确说明：数据默认本地 + iCloud 私有数据库
   - 导出时提示文件可能包含私密内容

6. **状态可见**
   - 空状态（无日记）要有友好引导
   - 同步异常状态在设置页可见，不打断主流程

7. **MVP 视觉建议（海獭日记风格）**
   - 温和配色（米白、浅棕、海蓝点缀）
   - 圆角卡片 + 轻微阴影
   - 图标适度可爱但不过度拟物

---

## 8. 建议目录结构

```text
ios-mvp/
  App/
    OtterDiaryApp.swift
  Models/
    DiaryEntry.swift
  Features/
    Home/
      HomeView.swift
    OnThisDay/
      OnThisDayService.swift
    Export/
      ExportService.swift
```

---

## 9. 里程碑建议

- Milestone 1（当前）：骨架与核心逻辑（文档 + 代码草稿）
- Milestone 2：接入 SwiftData + CloudKit 实存储
- Milestone 3：导出/设置页完善 + UI 打磨
- Milestone 4：测试（单元测试 + 快照测试）与 TestFlight
