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
    @State private var profileMonthAnchor: Date = Calendar.current.startOfDay(for: .now)
    @State private var editingEntry: DiaryEntry?

    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportFormat: ExportFormat = .json
    @State private var feedback: StandardFeedback?
    @State private var showingSearchSheet = false
    
    @State private var timelineTopToken = UUID()
    @State private var fabVisible = true
    @State private var lastScrollOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            DiaryColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                DiaryTopHeader(
                    title: headerTitle,
                    onSearch: { showingSearchSheet = true },
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
                NewEntryView { title, content, date, mood, emoji, tags, imageAssetPaths in
                    viewModel.addEntry(title: title, content: content, date: date, mood: mood, emoji: emoji, tags: tags, imageAssetPaths: imageAssetPaths)
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
                EditEntryView(entry: entry) { title, content, date, mood, emoji, tags, location, weather, imageAssetPaths in
                    viewModel.updateEntry(id: entry.id, title: title, content: content, date: date, mood: mood, emoji: emoji, tags: tags, location: location, weather: weather, imageAssetPaths: imageAssetPaths)
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
        .sheet(isPresented: $showingSearchSheet) {
            NavigationStack {
                SearchEntriesView(entries: viewModel.visibleEntries)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
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
        switch selectedBottomTab {
        case .diary: return "面包屑"
        case .calendar: return "日历"
        case .profile: return "用户"
        }
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

            TabView(selection: $selectedDiaryTab) {
                diaryPageContent(for: .onThisDay)
                    .tag(DiaryTab.onThisDay)
                diaryPageContent(for: .timeline)
                    .tag(DiaryTab.timeline)
                diaryPageContent(for: .life)
                    .tag(DiaryTab.life)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(DiaryStyle.Motion.selectionSpring, value: selectedDiaryTab)
        }
    }

    @ViewBuilder
    private func diaryPageContent(for tab: DiaryTab) -> some View {
        if tab == .timeline {
            ScrollViewReader { proxy in
                ScrollView {
                    GeometryReader { g in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: g.frame(in: .named("timelineScroll")).minY)
                    }
                    .frame(height: 0)

                    Color.clear.frame(height: 1).id(timelineTopToken)

                    VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                        timelineSection
                    }
                    .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                    .padding(.top, DiaryStyle.Spacing.contentTop)
                    .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
                }
                .coordinateSpace(name: "timelineScroll")
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: handleScroll)
                .onChange(of: timelineTopToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.28)) { proxy.scrollTo(timelineTopToken, anchor: .top) }
                }
            }
        } else {
            ScrollView {
                VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                    if tab == .onThisDay {
                        onThisDayContent
                    } else {
                        lifeLineContent
                    }
                }
                .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                .padding(.top, DiaryStyle.Spacing.contentTop)
                .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .onAppear { fabVisible = true }
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
                ProfileCard()
                StatsCard(entriesCount: viewModel.visibleEntries.count, imageCount: viewModel.allImageURLs.count, entries: viewModel.visibleEntries)
                DualCalendarCard(entries: viewModel.visibleEntries, monthAnchor: $profileMonthAnchor)
                ActionGridCard(onSettings: { showingSettings = true })
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
        .navigationBarTitleDisplayMode(.inline)
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
                if let title = entry.displayTitle {
                    Text(title)
                        .font(.title2.weight(.bold))
                }
                Text(entry.entryDate.formatted(.dateTime.year().month(.wide).day().weekday(.wide).hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !entry.displayTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("标签")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(entry.displayTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(DiaryColor.controlBackground)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(DiaryColor.strokeStrong, lineWidth: 1))
                            }
                        }
                    }
                }

                if let emoji = entry.reactionEmoji {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("心情")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(emoji)
                            .font(.system(size: 28))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(DiaryColor.controlBackground))
                            .overlay(Capsule().stroke(DiaryColor.strokeStrong, lineWidth: 1))
                    }
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
    let onSearch: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.title.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Spacer(minLength: 0)
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
            HStack(alignment: .top, spacing: 12) {
                dateBlock

                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.weekdayTimeText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let title = entry.displayTitle {
                        Text(title).font(.title3.weight(.bold)).lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(entry.content).font(.subheadline).lineSpacing(2).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)

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

            HStack(alignment: .center, spacing: 8) {
                Text(entry.locationWeatherText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let emoji = entry.reactionEmoji {
                    Text(emoji)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(DiaryColor.controlBackground))
                        .overlay(Capsule().stroke(DiaryColor.strokeStrong, lineWidth: 1))
                }
                menuButton
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

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.dayNumberText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(entry.yearMonthText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(DiaryColor.controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DiaryColor.stroke, lineWidth: 1))
    }

    private var menuButton: some View {
        Menu {
            Button(action: onEdit) { Label("编辑", systemImage: "square.and.pencil") }
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(DiaryColor.controlBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(DiaryColor.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(DiaryPressButtonStyle(minimumSize: 28, cornerRadius: 14, pressedScale: 0.96))
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
if let title = entry.displayTitle {
                    Text(title).font(.headline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
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

    private var yearLabel: String {
        "\(String(year))年"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(yearLabel)
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
                        if let title = entry.displayTitle {
                            Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        } else {
                            Text(entry.content).font(.subheadline.weight(.semibold)).lineLimit(1)
                        }
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
    let onSave: (String, String, Date, Mood?, String?, [String], String?, String?, [String]) -> Void

    @State private var title: String
    @State private var content: String
    @State private var date: Date
    @State private var emoji: String?
    @State private var tags: [String]
    @State private var newTagText: String = ""
    @State private var location: String
    @State private var weather: String
    @State private var imageAssetPaths: [String]
    @State private var pickedPhotoItem: PhotosPickerItem?

    init(entry: DiaryEntry, onSave: @escaping (String, String, Date, Mood?, String?, [String], String?, String?, [String]) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _title = State(initialValue: entry.title)
        _content = State(initialValue: entry.content)
        _date = State(initialValue: entry.entryDate)
        _emoji = State(initialValue: entry.emoji)
        _tags = State(initialValue: entry.tags)
        _location = State(initialValue: entry.location ?? "")
        _weather = State(initialValue: entry.weather ?? "")
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
            Section("标签") {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("#\(tag)")
                                    Image(systemName: "xmark")
                                        .font(.caption2.weight(.bold))
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                TextField("添加标签（如 #学习）", text: $newTagText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        let cleaned = newTagText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                        guard !cleaned.isEmpty else { return }
                        if !tags.contains(cleaned) { tags.append(cleaned) }
                        newTagText = ""
                    }
            }
            Section("地点与天气") {
                TextField("地点（如：旧金山）", text: $location)
                TextField("天气（如：☀️ 52°F）", text: $weather)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    onSave(title, content, date, entry.mood, emoji, tags, location.isEmpty ? nil : location, weather.isEmpty ? nil : weather, imageAssetPaths)
                    dismiss()
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct ProfileCard: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(DiaryColor.avatarBackground)
                .frame(width: 64, height: 64)
                .overlay { Image(systemName: "person.fill").font(.title3) }
            VStack(alignment: .leading, spacing: 4) {
                Text("我的日记")
                    .font(.headline.weight(.bold))
                Text("记录每一天的情绪与灵感")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .cardStyle()
    }
}

struct StatsCard: View {
    let entriesCount: Int
    let imageCount: Int
    let entries: [DiaryEntry]

    private var wordCount: Int {
        entries.reduce(0) { $0 + $1.content.count }
    }

    var body: some View {
        HStack(spacing: 10) {
            StatBlock(title: "笔记", value: "\(entriesCount)")
            StatBlock(title: "媒体", value: "\(imageCount)")
            StatBlock(title: "字数", value: "\(wordCount)")
            StatBlock(title: "连记", value: "\(currentStreak(entries))")
        }
        .padding(16)
        .cardStyle()
    }

    private func currentStreak(_ entries: [DiaryEntry]) -> Int {
        let cal = Calendar.current
        let days = Set(entries.map { cal.startOfDay(for: $0.entryDate) })
        var streak = 0
        var cursor = cal.startOfDay(for: .now)
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}

struct StatBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DualCalendarCard: View {
    let entries: [DiaryEntry]
    @Binding var monthAnchor: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(monthAnchor.formatted(.dateTime.year().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button { monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor } label: { Image(systemName: "chevron.right") }
            }

            HStack(alignment: .top, spacing: 10) {
                HeatmapMonthView(entries: entries, monthAnchor: monthAnchor)
                EmojiMonthView(entries: entries, monthAnchor: monthAnchor)
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct HeatmapMonthView: View {
    let entries: [DiaryEntry]
    let monthAnchor: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("热力图")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            WeekdayHeader()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(levelColor(countOn(day)))
                            .frame(height: 18)
                    } else {
                        Color.clear.frame(height: 18)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthCells: [Date?] { monthDays(for: monthAnchor) }

    private func countOn(_ day: Date) -> Int {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.entryDate, inSameDayAs: day) }.count
    }

    private func levelColor(_ count: Int) -> Color {
        switch count {
        case 0: return Color(uiColor: .systemGray5)
        case 1: return Color(hex: 0xDDECC8)
        case 2: return Color(hex: 0xBDE19D)
        case 3: return Color(hex: 0x8ACA69)
        default: return Color(hex: 0x4A9B38)
        }
    }
}

struct EmojiMonthView: View {
    let entries: [DiaryEntry]
    let monthAnchor: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Emoji 日历")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            WeekdayHeader()
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        ZStack {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(DiaryColor.surfaceSecondary)
                                .overlay(RoundedRectangle(cornerRadius: 5).stroke(DiaryColor.strokeSoft, lineWidth: 1))
                            if let emoji = emojiOn(day), !emoji.isEmpty {
                                Text(emoji).font(.caption)
                            } else {
                                Text("·")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(height: 18)
                    } else {
                        Color.clear.frame(height: 18)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthCells: [Date?] { monthDays(for: monthAnchor) }

    private func emojiOn(_ day: Date) -> String? {
        let cal = Calendar.current
        return entries
            .filter { cal.isDate($0.entryDate, inSameDayAs: day) }
            .sorted { $0.entryDate > $1.entryDate }
            .compactMap { $0.emoji?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first
    }
}

struct WeekdayHeader: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { name in
                Text(name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private func monthDays(for monthAnchor: Date) -> [Date?] {
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

struct ActionGridCard: View {
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            actionButton(title: "设置", icon: "gearshape", action: onSettings)
        }
        .padding(16)
        .cardStyle()
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(DiaryColor.controlBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(DiaryPressButtonStyle(cornerRadius: 12))
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


struct SearchEntriesView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [DiaryEntry]
    @State private var keyword: String = ""

    private var filteredEntries: [DiaryEntry] {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            ($0.emoji?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        List {
            if filteredEntries.isEmpty {
                Text("没有匹配的记录")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredEntries) { entry in
                    VStack(alignment: .leading, spacing: 6) {
if let title = entry.displayTitle {
                            Text(title)
                                .font(.headline)
                                .lineLimit(1)
                        }
                        Text(entry.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Text(entry.entryDate.formatted(.dateTime.year().month().day()))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题或正文")
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
    }
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
    var displayTitle: String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    var reactionEmoji: String? {
        guard let emoji else { return nil }
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") { return nil }
        return trimmed.containsEmoji ? trimmed : nil
    }

    var dayNumberText: String {
        String(Calendar.current.component(.day, from: entryDate))
    }

    var yearMonthText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM"
        return formatter.string(from: entryDate)
    }

    var weekdayTimeText: String {
        entryDate.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).weekday(.abbreviated).hour().minute())
    }

    var locationWeatherText: String {
        let place = (location?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "待补充地点"
        let weatherText = (weather?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "☀️ 52°F"
        return "📍\(place) · \(weatherText)"
    }

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


    var displayTags: [String] {
        var seen = Set<String>()
        let merged = tags + extractTags()
        return merged.compactMap { raw in
            let cleaned = normalizeTag(raw)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }

    func extractTags() -> [String] {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map(String.init)
            .filter { $0.hasPrefix("#") && $0.count > 1 }
            .map { String($0.dropFirst()) }
            .map(normalizeTag)
            .filter { !$0.isEmpty }
    }

    private func normalizeTag(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
    }
}


private extension String {
    var containsEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
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
