import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var viewModel: DiaryViewModel

    @State private var selectedBottomTab: BottomTab = .diary
    @State private var selectedDiaryTab: DiaryTab = .timeline
    @State private var onThisDayMode: OnThisDayMode = .lastYear
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedCalendarDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var calendarMonthAnchor: Date = Calendar.current.startOfDay(for: .now)
    @State private var editingEntry: DiaryEntry?

    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportFormat: ExportFormat = .json
    @State private var feedback: StandardFeedback?
    @State private var showingSearchHint = false
    
    @State private var timelineTopToken = UUID()
    @State private var fabVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            DiaryColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                DiaryTopHeader(
                    title: headerTitle,
                    onMenu: {},
                    onSearch: { showingSearchHint = true },
                    onSettings: { showingSettings = true }
                )
                .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                .padding(.top, DiaryStyle.TopBar.topPadding)
                .padding(.bottom, DiaryStyle.TopBar.bottomPadding)

                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            DiaryBottomNav(selected: $selectedBottomTab, fabVisible: fabVisible) {
                showingNewEntry = true
            }
            .safeAreaPadding(.bottom, DiaryStyle.BottomNav.bottomPadding)
        }
        .animation(DiaryStyle.Motion.selectionSpring, value: selectedBottomTab)
        .animation(DiaryStyle.Motion.selectionSpring, value: selectedDiaryTab)
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                NewEntryView { title, content, date, mood, emoji, imageAssetPaths in
                    viewModel.addEntry(title: title, content: content, date: date, mood: mood, emoji: emoji, imageAssetPaths: imageAssetPaths)
                    selectedBottomTab = .diary
                    selectedDiaryTab = .timeline
                    timelineTopToken = UUID()
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                EditEntryView(entry: entry) { title, content, date, mood, emoji, imageAssetPaths in
                    viewModel.updateEntry(id: entry.id, title: title, content: content, date: date, mood: mood, emoji: emoji, imageAssetPaths: imageAssetPaths)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(
                    iCloudSyncEnabled: Binding(
                        get: { viewModel.isICloudSyncEnabled },
                        set: { enabled in
                            viewModel.toggleICloudSync(enabled)
                            if enabled, let note = viewModel.firstEnableNoticeIfNeeded() {
                                feedback = StandardFeedback(title: "iCloud 同步", message: note)
                            }
                        }
                    ),
                    iCloudStatusTitle: viewModel.iCloudSyncState.title,
                    iCloudStatusDetail: viewModel.iCloudSyncState.detail,
                    onExportJSON: { doExport(.json) },
                    onExportMarkdown: { doExport(.markdown) }
                )
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportURL.map { LocalFileDocument(fileURL: $0) },
            contentType: exportFormat == .json ? .json : .plainText,
            defaultFilename: "otter-diary-export"
        ) { result in
            switch result {
            case .success:
                feedback = StandardFeedback(title: "导出成功", message: "文件已准备好，可在 Files 中保存或分享。")
            case .failure:
                feedback = StandardFeedback(title: "导出失败", message: "导出未完成，请稍后重试。")
            }
        }
        .alert(feedback?.title ?? "提示", isPresented: Binding(
            get: { feedback != nil },
            set: { if !$0 { feedback = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(feedback?.message ?? "")
        }
        .alert("My logs", isPresented: $showingSearchHint) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("可在内容中使用 #标签，方便后续检索与整理。")
        }
        .onChange(of: viewModel.latestSyncMessage) { _, msg in
            guard let msg else { return }
            feedback = StandardFeedback(title: "iCloud 同步提示", message: msg)
            viewModel.latestSyncMessage = nil
        }
        .navigationDestination(for: DiaryEntry.self) { entry in
            DiaryEntryDetailView(entry: entry)
        }
    }

    private var headerTitle: String {
        "My logs"
    }

    @ViewBuilder
    private var contentArea: some View {
        switch selectedBottomTab {
        case .diary:
            diaryHome
        case .calendar:
            calendarPage
        case .profile:
            profilePage
        }
    }

    private var diaryHome: some View {
        VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            DiarySecondaryTabs(selected: $selectedDiaryTab)
                .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)

            ScrollViewReader { proxy in
                ScrollView {
                    GeometryReader { g in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: g.frame(in: .named("diaryScroll")).minY)
                    }
                    .frame(height: 0)

                    Color.clear.frame(height: 1).id(timelineTopToken)

                    VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                        if selectedDiaryTab == .timeline {
                            timelineSection
                        } else if selectedDiaryTab == .onThisDay {
                            onThisDayContent
                        } else {
                            lifeLineContent
                        }
                    }
                    .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                    .padding(.top, DiaryStyle.Spacing.contentTop)
                    .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
                }
                .coordinateSpace(name: "diaryScroll")
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: handleScroll)
                .onChange(of: timelineTopToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.28)) { proxy.scrollTo(timelineTopToken, anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        if viewModel.isLoading {
            ForEach(0..<3, id: \.self) { _ in LoadingDiaryCard() }
        } else if viewModel.visibleEntries.isEmpty {
            DiaryEmptyCard()
        } else {
            ForEach(viewModel.visibleEntries) { entry in
                NavigationLink(value: entry) {
                    DiaryTimelineCard(
                        entry: entry,
                        onEdit: { editingEntry = entry },
                        onDelete: { viewModel.deleteEntry(id: entry.id) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var onThisDayContent: some View {
        let entries: [DiaryEntry] = {
            switch onThisDayMode {
            case .lastYear:
                return viewModel.onThisDayService.entriesForYearOffsetOnThisDay(from: viewModel.visibleEntries, yearOffset: 1, targetDate: selectedDate)
            case .recentFiveYears:
                return viewModel.onThisDayService.entriesForRecentYearsOnThisDay(from: viewModel.visibleEntries, years: 5, targetDate: selectedDate)
            }
        }()

        return VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            OnThisDayDateNavigatorCard(selectedDate: $selectedDate)
            OnThisDayFilterCard(mode: $onThisDayMode)
            OnThisDayEntriesCard(title: onThisDayMode == .lastYear ? "去年今日" : "近五年", entries: entries)
        }
    }

    private var lifeLineContent: some View {
        let grouped = Dictionary(grouping: viewModel.visibleEntries) { Calendar.current.component(.year, from: $0.entryDate) }
        let years = grouped.keys.sorted(by: >)

        return VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            if years.isEmpty {
                DiaryEmptyCard()
            } else {
                ForEach(years, id: \.self) { year in
                    let items = (grouped[year] ?? []).sorted { $0.entryDate > $1.entryDate }
                    LifeYearSection(year: year, entries: items)
                }
            }
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(selected ? .bold : .semibold))
                .foregroundStyle(selected ? DiaryColor.onTint : .secondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(selected ? DiaryColor.tintStrong : DiaryColor.controlBackground))
        }
        .buttonStyle(DiaryPressButtonStyle(cornerRadius: 16, pressedScale: 0.97))
    }

    private var calendarPage: some View {
        ScrollView {
            CalendarMonthGridCard(
                monthAnchor: $calendarMonthAnchor,
                selectedDate: $selectedCalendarDate,
                entries: viewModel.visibleEntries
            ) { tappedDate in
                selectedCalendarDate = tappedDate
            }
            .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
            .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            .padding(.top, DiaryStyle.Spacing.contentTop)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }

    private var profilePage: some View {
        ScrollView {
            VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                ProfileSummaryCard(entriesCount: viewModel.visibleEntries.count, imageCount: viewModel.allImageURLs.count, entries: viewModel.visibleEntries) {
                    showingSettings = true
                }
            }
            .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
            .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            .padding(.top, DiaryStyle.Spacing.contentTop)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func entries(on date: Date) -> [DiaryEntry] {
        let cal = Calendar.current
        return viewModel.visibleEntries.filter { cal.isDate($0.entryDate, inSameDayAs: date) }
    }


    private func doExport(_ format: ExportFormat) {
        do {
            exportFormat = format
            exportURL = try viewModel.exportService.export(entries: viewModel.visibleEntries, format: format)
            showingExporter = true
        } catch {
            feedback = StandardFeedback(title: "导出失败", message: "导出未完成，请稍后重试。")
        }
    }

    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        if delta < -6, fabVisible {
            withAnimation(.easeInOut(duration: 0.2)) { fabVisible = false }
        } else if delta > 4 || offset > -8 {
            withAnimation(.easeInOut(duration: 0.2)) { fabVisible = true }
        }
        lastScrollOffset = offset
    }
}

private struct StandardFeedback {
    let title: String
    let message: String
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var iCloudSyncEnabled: Bool
    let iCloudStatusTitle: String
    let iCloudStatusDetail: String
    let onExportJSON: () -> Void
    let onExportMarkdown: () -> Void

    var body: some View {
        List {
            Section {
                Toggle("iCloud 同步", isOn: $iCloudSyncEnabled)
                VStack(alignment: .leading, spacing: 6) {
                    Text("状态：\(iCloudStatusTitle)")
                        .font(.subheadline.weight(.semibold))
                    Text(iCloudStatusDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("云端同步")
            } footer: {
                Text("关闭后仅使用本地 JSON；开启后自动与 iCloud 文稿同步。")
            }

            Section {
                Button { onExportJSON(); dismiss() } label: { Label("导出 JSON 到 Files", systemImage: "doc.badge.arrow.up") }
                Button { onExportMarkdown(); dismiss() } label: { Label("导出 Markdown 到 Files", systemImage: "doc.text") }
            } header: { Text("数据与备份") } footer: { Text("导出后可在 Files 中保存或分享。") }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
    }
}

struct LocalFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .plainText] }
    let fileURL: URL
    init(fileURL: URL) { self.fileURL = fileURL }
    init(configuration: ReadConfiguration) throws { throw CocoaError(.fileReadUnknown) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct DiaryEntryDetailView: View {
    let entry: DiaryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.title.weight(.bold))
                Text(entry.entryDate.formatted(.dateTime.year().month(.wide).day().weekday(.wide).hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let emoji = entry.emoji, !emoji.isEmpty {
                    Text(emoji).font(.system(size: 28))
                }
                Text(entry.content)
                    .font(.body)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !entry.imageAssetPaths.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(entry.imageAssetPaths, id: \.self) { path in
                                if let image = UIImage(contentsOfFile: diaryLocalImageURL(for: path).path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("阅读")
        .navigationBarTitleDisplayMode(.inline)
        .background(DiaryColor.pageBackground)
    }
}

struct DiaryTopHeader: View {
    let title: String
    let onMenu: () -> Void
    let onSearch: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            chromeIconButton(systemName: "square.grid.2x2", accessibilityLabel: "菜单", accessibilityHint: "打开功能菜单") { onMenu() }
            Spacer(minLength: 8)
            Text(title).font(.largeTitle.weight(.heavy)).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                chromeIconButton(systemName: "magnifyingglass", accessibilityLabel: "搜索", accessibilityHint: "搜索日记内容", action: onSearch)
                chromeIconButton(systemName: "gearshape", accessibilityLabel: "设置", accessibilityHint: "打开应用设置", action: onSettings)
            }
        }
        .frame(minHeight: 48)
    }

    private func chromeIconButton(systemName: String, accessibilityLabel: String, accessibilityHint: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
                .background(DiaryColor.surfacePrimary)
                .clipShape(Circle())
                .overlay(Circle().stroke(DiaryColor.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(DiaryPressButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

struct DiarySecondaryTabs: View {
    @Binding var selected: DiaryTab

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(DiaryTab.allCases) { tab in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) { selected = tab }
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 15, weight: selected == tab ? .heavy : .medium))
                            .foregroundStyle(selected == tab ? DiaryColor.onTint : .secondary)
                            .padding(.horizontal, DiaryStyle.SecondaryTab.horizontalPadding)
                            .frame(height: DiaryStyle.SecondaryTab.height)
                            .background(Capsule(style: .continuous).fill(selected == tab ? DiaryColor.tintStrong : Color.clear))
                            .overlay(Capsule(style: .continuous).stroke(DiaryColor.strokeStrong.opacity(selected == tab ? 0 : 1), lineWidth: 1))
                    }
                    .buttonStyle(DiaryPressButtonStyle(cornerRadius: 18))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DiaryBottomNav: View {
    @Binding var selected: BottomTab
    let fabVisible: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(BottomTab.allCases) { tab in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) { selected = tab }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon).font(.system(size: 16, weight: .bold))
                            Text(tab.title).font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(selected == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DiaryStyle.BottomNav.barVerticalPadding)
                        .background {
                            if selected == tab {
                                Capsule(style: .continuous)
                                    .fill(DiaryColor.surfacePrimary)
                                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                                    .padding(.vertical, 1)
                            }
                        }
                    }
                    .buttonStyle(DiaryPressButtonStyle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(DiaryColor.bottomBarBackground).overlay(Capsule().stroke(DiaryColor.stroke, lineWidth: 1)))

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: DiaryStyle.BottomNav.fabSize, height: DiaryStyle.BottomNav.fabSize)
                    .background(DiaryColor.tintStrong)
                    .clipShape(Circle())
                    .shadow(color: DiaryStyle.Shadow.fabColor, radius: DiaryStyle.Shadow.fabRadius, y: DiaryStyle.Shadow.fabY)
            }
            .buttonStyle(DiaryPressButtonStyle(minimumSize: DiaryStyle.BottomNav.fabSize, cornerRadius: DiaryStyle.BottomNav.fabSize / 2, pressedScale: 0.94))
            .scaleEffect(fabVisible ? 1 : 0.82)
            .opacity(fabVisible ? 1 : 0.05)
            .offset(y: fabVisible ? 0 : 12)
            .allowsHitTesting(fabVisible)
            .animation(.easeInOut(duration: 0.2), value: fabVisible)
        }
        .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
        .padding(.bottom, DiaryStyle.BottomNav.bottomPadding)
    }
}

struct DiaryTimelineCard: View {
    let entry: DiaryEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? "无标题" : entry.title).font(.title3.weight(.bold)).lineLimit(2)
                    Text(entry.entryDate.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button(action: onEdit) {
                        Label("编辑", systemImage: "square.and.pencil")
                    }
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(DiaryColor.controlBackground)
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 6) {
                if let emoji = entry.emoji, !emoji.isEmpty { Text(emoji) }
                Text(entry.content).font(.subheadline).lineSpacing(2).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)
            }

            if let firstImage = entry.primaryDisplayImageURL {
                AsyncImage(url: firstImage) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: DiaryStyle.Radius.media).fill(DiaryColor.controlBackground).aspectRatio(4 / 3, contentMode: .fit).overlay { ProgressView() }
                    case .success(let image):
                        image.resizable().scaledToFill().aspectRatio(4 / 3, contentMode: .fit).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: DiaryStyle.Radius.media, style: .continuous))
                    case .failure:
                        RoundedRectangle(cornerRadius: DiaryStyle.Radius.media).fill(DiaryColor.controlBackground).aspectRatio(4 / 3, contentMode: .fit).overlay { Image(systemName: "photo") }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
        .confirmationDialog("删除这条日记？", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive, action: onDelete)
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将从时间线移除。")
        }
    }
}

struct LoadingDiaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 8).fill(DiaryColor.controlBackground).frame(height: 18)
            RoundedRectangle(cornerRadius: 8).fill(DiaryColor.controlBackground).frame(height: 14)
            RoundedRectangle(cornerRadius: 8).fill(DiaryColor.controlBackground).frame(height: 100)
        }
        .padding(16)
        .cardStyle()
        .redacted(reason: .placeholder)
    }
}

struct DiaryEmptyCard: View {
    var body: some View {
        VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            Image(systemName: "book.closed").font(.system(size: 28)).foregroundStyle(.secondary)
            Text("还没有日记").font(.headline)
            Text("点右下角 + 开始记录今天。").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .cardStyle()
    }
}

struct CalendarMonthGridCard: View {
    @Binding var monthAnchor: Date
    @Binding var selectedDate: Date
    let entries: [DiaryEntry]
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var monthDays: [Date?] {
        let cal = Calendar.current
        guard let monthRange = cal.range(of: .day, in: .month, for: monthAnchor),
              let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor)) else { return [] }

        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = Array(repeating: Optional<Date>.none, count: max(0, firstWeekday - cal.firstWeekday))
        let days = monthRange.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return leading + days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(monthAnchor.formatted(.dateTime.year().month(.wide)))
                    .font(.headline)
                Spacer()
                Button { monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { name in
                    Text(name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let dayEntries = entries.filter { Calendar.current.isDate($0.entryDate, inSameDayAs: day) }
                        let imageURL = dayEntries.compactMap { $0.primaryDisplayImageURL }.first
                        let hasRecord = !dayEntries.isEmpty
                        let targetEntry = dayEntries.sorted { $0.entryDate > $1.entryDate }.first

                        if let targetEntry {
                            NavigationLink(value: targetEntry) {
                                calendarCell(day: day, imageURL: imageURL, hasRecord: hasRecord)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                selectedDate = day
                                onSelectDate(day)
                            })
                        } else {
                            Button {
                                selectedDate = day
                                onSelectDate(day)
                            } label: {
                                calendarCell(day: day, imageURL: imageURL, hasRecord: hasRecord)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Color.clear.frame(height: 52)
                    }
                }
            }

            if entries.compactMap({ $0.primaryDisplayImageURL }).isEmpty {
                Text("本月暂无图片，添加带图片链接的日记后会显示在日期格中。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func calendarCell(day: Date, imageURL: URL?, hasRecord: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(DiaryColor.surfaceSecondary)
                .frame(height: 52)

            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 10).fill(DiaryColor.imagePlaceholder)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 10).fill(DiaryColor.imagePlaceholder)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("\(Calendar.current.component(.day, from: day))")
                .font(.caption.weight(.bold))
                .padding(5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(4)

            if hasRecord {
                Circle().fill(Color.green).frame(width: 6, height: 6).padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? DiaryColor.tintStrong : Color.clear, lineWidth: 2)
        )
    }
}

struct OnThisDayDateNavigatorCard: View {
    @Binding var selectedDate: Date
    var body: some View {
        HStack {
            arrowButton(systemName: "chevron.left", offset: -1)
            Spacer()
            VStack(spacing: 2) {
                Text(selectedDate.formatted(.dateTime.year().month(.wide).day())).font(.headline)
                Text("同一天回顾").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            arrowButton(systemName: "chevron.right", offset: 1)
        }
        .padding(16)
        .cardStyle()
    }

    private func arrowButton(systemName: String, offset: Int) -> some View {
        Button {
            selectedDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
        } label: {
            Image(systemName: systemName).font(.callout.weight(.semibold)).frame(width: 44, height: 44).background(DiaryColor.controlBackground).clipShape(Circle())
        }
        .buttonStyle(DiaryPressButtonStyle(cornerRadius: 20))
    }
}

struct OnThisDayFilterCard: View {
    @Binding var mode: OnThisDayMode
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("筛选").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(OnThisDayMode.allCases) { item in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) { mode = item }
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(mode == item ? .bold : .semibold))
                            .foregroundStyle(mode == item ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(mode == item ? DiaryColor.tintStrong : Color.clear))
                    }
                    .buttonStyle(DiaryPressButtonStyle(cornerRadius: 10))
                }
            }
            .padding(4)
            .background(DiaryColor.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .cardStyle()
    }
}

struct OnThisDayEntriesCard: View {
    let title: String
    let entries: [DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("这一天还没有记录").font(.subheadline.weight(.semibold))
                    Text("点右下角 + 写下今天，未来会在这里重逢。").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                    ForEach(entries) { entry in OnThisDayEntryRow(entry: entry) }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct OnThisDayEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.title.isEmpty ? "无标题" : entry.title).font(.headline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.entryDate.formatted(.dateTime.year().month().day())).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            Text(entry.content).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(12)
        .background(DiaryColor.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


struct LifeYearSection: View {
    let year: Int
    let entries: [DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(year)年")
                    .font(.headline)
                Spacer()
                Text("\(entries.count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.prefix(4)) { entry in
                HStack(alignment: .top) {
                    Circle().fill(DiaryColor.tintStrong).frame(width: 8, height: 8).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title.isEmpty ? "无标题" : entry.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(entry.entryDate.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct EditEntryView: View {
    @Environment(\.dismiss) private var dismiss
    let entry: DiaryEntry
    let onSave: (String, String, Date, Mood?, String?, [String]) -> Void

    @State private var title: String
    @State private var content: String
    @State private var date: Date
    @State private var emoji: String?
    @State private var imageAssetPaths: [String]
    @State private var pickedPhotoItem: PhotosPickerItem?

    init(entry: DiaryEntry, onSave: @escaping (String, String, Date, Mood?, String?, [String]) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _title = State(initialValue: entry.title)
        _content = State(initialValue: entry.content)
        _date = State(initialValue: entry.entryDate)
        _emoji = State(initialValue: entry.emoji)
        _imageAssetPaths = State(initialValue: entry.imageAssetPaths)
    }

    var body: some View {
        Form {
            Section("标题") { TextField("无标题", text: $title) }
            Section("时间") { DatePicker("", selection: $date).labelsHidden() }
            Section("内容") { TextEditor(text: $content).frame(minHeight: 180) }
            Section("表情") {
                TextField("emoji", text: Binding(get: { emoji ?? "" }, set: { emoji = $0.isEmpty ? nil : $0 }))
            }
            Section("图片") {
                PhotosPicker(selection: $pickedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("添加图片", systemImage: "photo")
                }
                if !imageAssetPaths.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(imageAssetPaths, id: \.self) { path in
                                if let image = UIImage(contentsOfFile: diaryLocalImageURL(for: path).path) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    .frame(height: 96)
                }
            }
        }
        .onChange(of: pickedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let path = try? saveDiaryImageData(data) {
                    await MainActor.run { imageAssetPaths.append(path) }
                }
                await MainActor.run { pickedPhotoItem = nil }
            }
        }
        .navigationTitle("编辑记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    onSave(title, content, date, entry.mood, emoji, imageAssetPaths)
                    dismiss()
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct ProfileSummaryCard: View {
    let entriesCount: Int
    let imageCount: Int
    let entries: [DiaryEntry]
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RoundedRectangle(cornerRadius: 10).fill(DiaryColor.avatarBackground).frame(width: 62, height: 62).overlay { Image(systemName: "bird") }
                Text("🐰").font(.title3)
                Spacer()
            }

            HStack(spacing: 10) {
                StatBlock(title: "笔记", value: "\(entriesCount)")
                StatBlock(title: "媒体", value: "\(imageCount)")
                StatBlock(title: "字数", value: "\(entriesCount * 40)")
                StatBlock(title: "位置", value: "1")
            }

            ActivityHeatmap(entries: entries)

            Button(action: onExport) {
                Label("导出", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(DiaryColor.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(DiaryPressButtonStyle(cornerRadius: 12))
        }
        .padding(16)
        .cardStyle()
    }
}

struct StatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct ActivityHeatmap: View {
    let entries: [DiaryEntry]
    private let levels = [Color(uiColor: .systemGray5), Color(hex: 0xC6E48B), Color(hex: 0x7BC96F), Color(hex: 0x239A3B), Color(hex: 0x196127)]

    private var cells: [(Date, Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -181, to: today) ?? today
        let byDay = Dictionary(grouping: entries) { cal.startOfDay(for: $0.entryDate) }
        return (0...181).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (day, byDay[day]?.count ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("活跃热力图")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<min($0+7, cells.count)]) }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 4) {
                            ForEach(week, id: \.0) { day, count in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(levelColor(count))
                                    .frame(width: 10, height: 10)
                                    .accessibilityLabel(day.formatted(.dateTime.year().month().day()))
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            HStack(spacing: 6) {
                Text("少").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(levels[i]).frame(width: 10, height: 10)
                }
                Text("多").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func levelColor(_ count: Int) -> Color {
        switch count {
        case 0: return levels[0]
        case 1: return levels[1]
        case 2: return levels[2]
        case 3: return levels[3]
        default: return levels[4]
        }
    }
}


private func diaryLocalImageURL(for relativePath: String) -> URL {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    return docs.appendingPathComponent(relativePath)
}

private func saveDiaryImageData(_ data: Data) throws -> String {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    let dir = docs.appendingPathComponent("entry-images", isDirectory: true)
    if !FileManager.default.fileExists(atPath: dir.path) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    let name = "\(UUID().uuidString).jpg"
    try data.write(to: dir.appendingPathComponent(name), options: .atomic)
    return "entry-images/\(name)"
}

enum BottomTab: CaseIterable, Identifiable {
    case diary
    case calendar
    case profile
    var id: String { title }
    var title: String {
        switch self {
        case .diary: return "日记"
        case .calendar: return "日历"
        case .profile: return "用户"
        }
    }
    var icon: String {
        switch self {
        case .diary: return "book"
        case .calendar: return "calendar"
        case .profile: return "person"
        }
    }
}

enum DiaryTab: CaseIterable, Identifiable {
    case onThisDay
    case timeline
    case life
    var id: String { title }
    var title: String {
        switch self {
        case .onThisDay: return "那年今日"
        case .timeline: return "时间线"
        case .life: return "人生线"
        }
    }
}

enum OnThisDayMode: CaseIterable, Identifiable {
    case lastYear
    case recentFiveYears
    var id: String { title }
    var title: String {
        switch self {
        case .lastYear: return "去年今日"
        case .recentFiveYears: return "近五年"
        }
    }
}

extension DiaryEntry {
    func extractImageURLs() -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return imageAssetPaths.map { diaryLocalImageURL(for: $0) } }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let remote = detector.matches(in: content, options: [], range: range)
            .compactMap { $0.url }
            .filter { ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"].contains($0.pathExtension.lowercased()) }
        return imageAssetPaths.map { diaryLocalImageURL(for: $0) } + remote
    }

    var primaryDisplayImageURL: URL? {
        extractImageURLs().first
    }


    func extractTags() -> [String] {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { $0.hasPrefix("#") && $0.count > 1 }
            .map { String($0.dropFirst()).trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
}

enum DiaryColor {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let surfacePrimary = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceSecondary = Color(uiColor: .tertiarySystemGroupedBackground)
    static let controlBackground = Color(uiColor: .secondarySystemBackground)
    static let imagePlaceholder = Color(uiColor: .quaternarySystemFill)
    static let bottomBarBackground = Color(uiColor: .systemGray6).opacity(0.96)
    static let tintStrong = Color.primary
    static let onTint = Color(uiColor: .systemBackground)
    static let avatarBackground = Color(uiColor: .systemBlue).opacity(0.25)
    static let strokeSoft = Color.primary.opacity(0.08)
    static let stroke = Color.primary.opacity(0.1)
    static let strokeStrong = Color.primary.opacity(0.14)
}

enum DiaryStyle {
    enum Spacing {
        static let pageHorizontal: CGFloat = 20
        static let sectionGap: CGFloat = 14
        static let contentTop: CGFloat = 6
        static let bottomSafe: CGFloat = 124
    }
    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 14
        static let media: CGFloat = 16
    }
    enum Shadow {
        static let cardColor = DiaryColor.strokeStrong
        static let cardRadius: CGFloat = 12
        static let cardY: CGFloat = 6
        static let fabColor = Color.black.opacity(0.2)
        static let fabRadius: CGFloat = 12
        static let fabY: CGFloat = 7
    }
    enum TopBar {
        static let iconSize: CGFloat = 40
        static let titleSize: CGFloat = 32
        static let horizontalPadding: CGFloat = 20
        static let topPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 12
    }
    enum SecondaryTab {
        static let height: CGFloat = 36
        static let horizontalPadding: CGFloat = 16
    }
    enum BottomNav {
        static let fabSize: CGFloat = 58
        static let barVerticalPadding: CGFloat = 8
        static let bottomPadding: CGFloat = 8
    }
    enum Motion {
        static let selectionSpring = Animation.spring(response: 0.32, dampingFraction: 0.84)
        static let interactionSpring = Animation.spring(response: 0.2, dampingFraction: 0.82)
    }
}

struct DiaryPressButtonStyle: ButtonStyle {
    var minimumSize: CGFloat = 44
    var cornerRadius: CGFloat = 14
    var pressedScale: CGFloat = 0.96
    var pressedOpacity: CGFloat = 0.82

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: minimumSize, minHeight: minimumSize)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DiaryColor.strokeSoft.opacity(configuration.isPressed ? 1 : 0))
            )
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(DiaryStyle.Motion.interactionSpring, value: configuration.isPressed)
    }
}

struct DiaryCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DiaryStyle.Radius.card, style: .continuous)
                    .fill(DiaryColor.surfacePrimary)
                    .overlay(RoundedRectangle(cornerRadius: DiaryStyle.Radius.card, style: .continuous).stroke(DiaryColor.strokeSoft, lineWidth: 1))
            )
            .shadow(color: DiaryStyle.Shadow.cardColor, radius: DiaryStyle.Shadow.cardRadius, y: DiaryStyle.Shadow.cardY)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(DiaryCardModifier())
    }
}

extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
