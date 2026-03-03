import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var viewModel: DiaryViewModel

    @State private var selectedBottomTab: BottomTab = .diary
    @State private var selectedDiaryTab: DiaryTab = .timeline
    @State private var onThisDayMode: OnThisDayMode = .lastYear
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var selectedCalendarDate: Date = Calendar.current.startOfDay(for: .now)

    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportFormat: ExportFormat = .json
    @State private var exportError = false
    @State private var showingSearchHint = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: 0xF2F3F5).ignoresSafeArea()

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
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            }

            DiaryBottomNav(selected: $selectedBottomTab) {
                showingNewEntry = true
            }
            .safeAreaPadding(.bottom, DiaryStyle.BottomNav.bottomPadding)
        }
        .animation(DiaryStyle.Motion.selectionSpring, value: selectedBottomTab)
        .animation(DiaryStyle.Motion.selectionSpring, value: selectedDiaryTab)
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                NewEntryView { title, content, date, mood in
                    viewModel.addEntry(title: title, content: content, date: date, mood: mood)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(
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
        ) { _ in }
        .alert("导出失败", isPresented: $exportError) {
            Button("知道了", role: .cancel) {}
        }
        .alert("搜索功能即将上线", isPresented: $showingSearchHint) {
            Button("好的", role: .cancel) {}
        }
    }

    private var headerTitle: String {
        switch selectedBottomTab {
        case .diary: return "海獭日记"
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

            ScrollView {
                VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                    switch selectedDiaryTab {
                    case .timeline:
                        if viewModel.visibleEntries.isEmpty {
                            DiaryEmptyCard()
                        } else {
                            ForEach(viewModel.visibleEntries) { entry in
                                DiaryTimelineCard(entry: entry) {
                                    viewModel.deleteEntry(id: entry.id)
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    case .onThisDay:
                        onThisDayContent
                    case .life, .books:
                        comingSoonCard
                    }
                }
                .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                .padding(.top, DiaryStyle.Spacing.contentTop)
                .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            }
            .scrollIndicators(.hidden)
        }
        .animation(DiaryStyle.Motion.selectionSpring, value: selectedDiaryTab)
    }

    private var onThisDayContent: some View {
        let entries: [DiaryEntry] = {
            switch onThisDayMode {
            case .lastYear:
                return viewModel.onThisDayService.entriesForYearOffsetOnThisDay(
                    from: viewModel.visibleEntries,
                    yearOffset: 1,
                    targetDate: selectedDate
                )
            case .recentFiveYears:
                return viewModel.onThisDayService.entriesForRecentYearsOnThisDay(
                    from: viewModel.visibleEntries,
                    years: 5,
                    targetDate: selectedDate
                )
            }
        }()

        return VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            OnThisDayDateNavigatorCard(selectedDate: $selectedDate)
            OnThisDayFilterCard(mode: $onThisDayMode)
            OnThisDayEntriesCard(title: onThisDayMode == .lastYear ? "去年今日" : "近五年", entries: entries)
        }
    }

    private var comingSoonCard: some View {
        VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            Image(systemName: "clock.badge")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text("正在构建中")
                .font(.headline)
            Text("先使用「时间线」和「那年今日」。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var calendarPage: some View {
        ScrollView {
            VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                CalendarDateBrowserCard(selectedDate: $selectedCalendarDate)
                CalendarDayContentCard(date: selectedCalendarDate, entries: entries(on: selectedCalendarDate))
                CalendarImageAggregationCard(groupedImages: groupedImagesByMonth)
            }
            .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
            .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            .padding(.top, DiaryStyle.Spacing.contentTop)
        }
        .scrollIndicators(.hidden)
    }

    private var profilePage: some View {
        ScrollView {
            VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                ProfileSummaryCard(entriesCount: viewModel.visibleEntries.count, imageCount: viewModel.allImageURLs.count) {
                    showingSettings = true
                }
            }
            .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
            .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
            .padding(.top, DiaryStyle.Spacing.contentTop)
        }
    }

    private func entries(on date: Date) -> [DiaryEntry] {
        let cal = Calendar.current
        return viewModel.visibleEntries.filter { cal.isDate($0.entryDate, inSameDayAs: date) }
    }

    private var groupedImagesByMonth: [(String, [URL])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"

        var bucket: [String: [URL]] = [:]
        var order: [String] = []

        for entry in viewModel.visibleEntries {
            let images = entry.extractImageURLs()
            guard !images.isEmpty else { continue }

            let key = formatter.string(from: entry.entryDate)
            if bucket[key] == nil {
                bucket[key] = []
                order.append(key)
            }
            bucket[key]?.append(contentsOf: images)
        }

        return order.map { key in
            let unique = Array(Set(bucket[key] ?? [])).sorted { $0.absoluteString < $1.absoluteString }
            return (key, unique)
        }
    }

    private func doExport(_ format: ExportFormat) {
        do {
            exportFormat = format
            exportURL = try viewModel.exportService.export(entries: viewModel.visibleEntries, format: format)
            showingExporter = true
        } catch {
            exportError = true
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let onExportJSON: () -> Void
    let onExportMarkdown: () -> Void

    var body: some View {
        List {
            Section {
                Button {
                    onExportJSON()
                    dismiss()
                } label: {
                    Label("导出 JSON 到 Files", systemImage: "doc.badge.arrow.up")
                }

                Button {
                    onExportMarkdown()
                    dismiss()
                } label: {
                    Label("导出 Markdown 到 Files", systemImage: "doc.text")
                }
            } header: {
                Text("数据与备份")
            } footer: {
                Text("导出后可在 Files 中保存或分享。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
            }
        }
    }
}

struct LocalFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json, .plainText] }

    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnknown)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try Data(contentsOf: fileURL)
        return FileWrapper(regularFileWithContents: data)
    }
}


struct DiaryTopHeader: View {
    let title: String
    let onMenu: () -> Void
    let onSearch: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            chromeIconButton(systemName: "square.grid.2x2") { onMenu() }

            Spacer(minLength: 8)

            Text(title)
                .font(.system(size: DiaryStyle.TopBar.titleSize, weight: .heavy, design: .rounded))

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                chromeIconButton(systemName: "magnifyingglass", action: onSearch)
                chromeIconButton(systemName: "gearshape", action: onSettings)
            }
        }
        .frame(height: 48)
    }

    private func chromeIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
                .background(.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
         .buttonStyle(DiaryPressButtonStyle())
    }
}

struct DiarySecondaryTabs: View {
    @Binding var selected: DiaryTab

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(DiaryTab.allCases) { tab in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) {
                            selected = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.system(size: 15, weight: selected == tab ? .heavy : .medium))
                            .foregroundStyle(selected == tab ? .white : .secondary)
                            .padding(.horizontal, DiaryStyle.SecondaryTab.horizontalPadding)
                            .frame(height: DiaryStyle.SecondaryTab.height)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selected == tab ? Color.black : Color.clear)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.black.opacity(selected == tab ? 0 : 0.07), lineWidth: 1)
                            )
                    }
                     .buttonStyle(DiaryPressButtonStyle(cornerRadius: 18))
                    .scaleEffect(selected == tab ? 1 : 0.98)
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
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 2) {
                ForEach(BottomTab.allCases) { tab in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) {
                            selected = tab
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .bold))
                            Text(tab.title)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(selected == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DiaryStyle.BottomNav.barVerticalPadding)
                        .background {
                            if selected == tab {
                                Capsule(style: .continuous)
                                    .fill(.white)
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
            .background(
                Capsule(style: .continuous)
                    .fill(Color(hex: 0xEAECF0).opacity(0.96))
                    .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
            )

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: DiaryStyle.BottomNav.fabSize, height: DiaryStyle.BottomNav.fabSize)
                    .background(Color.black)
                    .clipShape(Circle())
                    .shadow(color: DiaryStyle.Shadow.fabColor, radius: DiaryStyle.Shadow.fabRadius, y: DiaryStyle.Shadow.fabY)
            }
             .buttonStyle(DiaryPressButtonStyle(minimumSize: DiaryStyle.BottomNav.fabSize, cornerRadius: DiaryStyle.BottomNav.fabSize / 2, pressedScale: 0.94))
            .accessibilityLabel("新建日记")
        }
        .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
        .padding(.bottom, DiaryStyle.BottomNav.bottomPadding)
    }
}

struct DiaryTimelineCard: View {
    let entry: DiaryEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? "无标题" : entry.title)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text(entry.entryDate.formatted(.dateTime.month(.wide).day().weekday(.wide)))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)


                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                         .frame(width: 44, height: 44)
                        .background(Color(hex: 0xF3F4F6))
                        .clipShape(Circle())
                }
            }

            Text(entry.content)
                .font(.subheadline)
                .lineSpacing(2)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let firstImage = entry.extractImageURLs().first {
                AsyncImage(url: firstImage) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: DiaryStyle.Radius.media)
                            .fill(Color(hex: 0xF3F4F6))
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: DiaryStyle.Radius.media, style: .continuous))
                    case .failure:
                        RoundedRectangle(cornerRadius: DiaryStyle.Radius.media)
                            .fill(Color(hex: 0xF3F4F6))
                            .aspectRatio(4 / 3, contentMode: .fit)
                            .overlay { Image(systemName: "photo") }
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            HStack(spacing: 16) {
                Label("贝尔维尤", systemImage: "location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                cardIconButton(systemName: "face.smiling")
                cardIconButton(systemName: "heart")
                cardIconButton(systemName: "bubble.right")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .cardStyle()
    }

    private func cardIconButton(systemName: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(DiaryPressButtonStyle(minimumSize: 44, cornerRadius: 12, pressedOpacity: 0.75))
    }
}

struct DiaryEmptyCard: View {
    var body: some View {
        VStack(spacing: DiaryStyle.Spacing.sectionGap) {
            Image(systemName: "book.closed")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("还没有日记")
                .font(.headline)
            Text("点右下角 + 开始记录今天。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .cardStyle()
    }
}

struct CalendarDateBrowserCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("按日期浏览")
                    .font(.headline)
                Spacer()
                Text(selectedDate.formatted(.dateTime.year().month().day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
        }
        .padding(16)
        .cardStyle()
    }
}

struct CalendarDayContentCard: View {
    let date: Date
    let entries: [DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当日内容")
                .font(.headline)

            if entries.isEmpty {
                Text("这一天没有记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DiaryStyle.BottomNav.barVerticalPadding)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.title.isEmpty ? "无标题" : entry.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(entry.entryDate.formatted(.dateTime.month().day()))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(minWidth: 52, alignment: .trailing)
                        }

                        Text(entry.content)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        if let image = entry.extractImageURLs().first {
                            AsyncImage(url: image) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: 0xF3F4F6))
                                        .frame(height: 120)
                                        .overlay { ProgressView() }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 120)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(hex: 0xF3F4F6))
                                        .frame(height: 120)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(hex: 0xF8F8F9))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct CalendarImageAggregationCard: View {
    let groupedImages: [(String, [URL])]

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("图片聚合")
                .font(.headline)

            if groupedImages.isEmpty {
                Text("暂无图片")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(groupedImages, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(group.1, id: \.absoluteString) { url in
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: 0xF2F3F5))
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(hex: 0xF2F3F5))
                                            .overlay { Image(systemName: "photo") }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

struct OnThisDayDateNavigatorCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack {
            arrowButton(systemName: "chevron.left", offset: -1)

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate.formatted(.dateTime.year().month(.wide).day()))
                    .font(.headline)
                Text("同一天回顾")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            Image(systemName: systemName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                 .frame(width: 44, height: 44)
                .background(Color(hex: 0xF3F4F6))
                .clipShape(Circle())
        }
        .buttonStyle(DiaryPressButtonStyle(cornerRadius: 20))
    }
}

struct OnThisDayFilterCard: View {
    @Binding var mode: OnThisDayMode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("筛选")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(OnThisDayMode.allCases) { item in
                    Button {
                        withAnimation(DiaryStyle.Motion.selectionSpring) {
                            mode = item
                        }
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(mode == item ? .bold : .semibold))
                            .foregroundStyle(mode == item ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(mode == item ? Color.black : Color.clear)
                            )
                    }
                    .buttonStyle(DiaryPressButtonStyle(cornerRadius: 10))
                }
            }
            .padding(4)
            .background(Color(hex: 0xF3F4F6))
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
            Text(title)
                .font(.headline)

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                    Text("这一天还没有记录")
                        .font(.subheadline.weight(.semibold))
                    Text("点右下角 + 写下今天，未来会在这里重逢。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: DiaryStyle.Spacing.sectionGap) {
                    ForEach(entries) { entry in
                        OnThisDayEntryRow(entry: entry)
                    }
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
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.entryDate.formatted(.dateTime.year().month().day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(minWidth: 84, alignment: .trailing)
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color(hex: 0xF8F8F9))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ProfileSummaryCard: View {
    let entriesCount: Int
    let imageCount: Int
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: 0xCDE6FB))
                    .frame(width: 62, height: 62)
                    .overlay { Image(systemName: "bird") }
                Text("🐰")
                    .font(.title3)
                Spacer()
                Button("获取PRO") {}
                    .buttonStyle(DiaryPressButtonStyle(cornerRadius: 12))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, DiaryStyle.BottomNav.barVerticalPadding)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
            }

            HStack(spacing: 10) {
                StatBlock(title: "笔记", value: "\(entriesCount)")
                StatBlock(title: "媒体", value: "\(imageCount)")
                StatBlock(title: "字数", value: "\(entriesCount * 40)")
                StatBlock(title: "位置", value: "1")
            }

            Button(action: onExport) {
                Label("导出", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xF3F4F6))
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
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    case books

    var id: String { title }

    var title: String {
        switch self {
        case .onThisDay: return "那年今日"
        case .timeline: return "时间线"
        case .life: return "人生线"
        case .books: return "书籍线"
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
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return detector.matches(in: content, options: [], range: range)
            .compactMap { $0.url }
            .filter {
                ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"].contains($0.pathExtension.lowercased())
            }
    }
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
        static let cardColor = Color.black.opacity(0.06)
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
                    .fill(Color.black.opacity(configuration.isPressed ? 0.06 : 0))
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
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: DiaryStyle.Radius.card, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
            )
            .shadow(
                color: DiaryStyle.Shadow.cardColor,
                radius: DiaryStyle.Shadow.cardRadius,
                y: DiaryStyle.Shadow.cardY
            )
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
