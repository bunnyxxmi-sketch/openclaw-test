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
            Color(hex: 0xF3F4F6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            bottomOverlay
        }
        .sheet(isPresented: $showingNewEntry) {
            NavigationStack {
                NewEntryView { title, content, date, mood in
                    viewModel.addEntry(title: title, content: content, date: date, mood: mood)
                }
            }
            .presentationDetents([.large])
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

    private var topHeader: some View {
        HStack(spacing: 10) {
            iconCircleButton(systemName: "line.3.horizontal", action: {})

            Spacer(minLength: 8)

            Text(headerTitle)
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                iconCircleButton(systemName: "magnifyingglass") {
                    showingSearchHint = true
                }
                iconCircleButton(systemName: "gearshape") {
                    showingSettings = true
                }
            }
        }
    }

    private var headerTitle: String {
        switch selectedBottomTab {
        case .diary: return "日记"
        case .calendar: return "日历"
        case .profile: return "用户"
        }
    }

    private var contentArea: some View {
        Group {
            switch selectedBottomTab {
            case .diary:
                diaryHome
            case .calendar:
                calendarPage
            case .profile:
                profilePage
            }
        }
    }

    private var diaryHome: some View {
        VStack(spacing: 12) {
            diaryTabBar
                .padding(.horizontal, 20)

            Group {
                switch selectedDiaryTab {
                case .timeline:
                    timelinePage
                case .onThisDay:
                    onThisDayPage
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
    }

    private var diaryTabBar: some View {
        HStack(spacing: 6) {
            ForEach(DiaryTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        selectedDiaryTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedDiaryTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selectedDiaryTab == tab {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.72))
        )
    }

    private var onThisDayPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                dateNavigatorCard
                onThisDayFilterCard
                onThisDayListCard
            }
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var dateNavigatorCard: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0xF3F4F6))
                    .clipShape(Circle())
            }

            Spacer()

            Button("今天") {
                selectedDate = Calendar.current.startOfDay(for: .now)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)

            VStack(spacing: 3) {
                Text(selectedDate.formatted(.dateTime.year().month(.wide).day()))
                    .font(.headline)
                Text("同一天回顾")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0xF3F4F6))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var onThisDayFilterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("筛选")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Picker("模式", selection: $onThisDayMode) {
                ForEach(OnThisDayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .cardStyle()
    }

    private var onThisDayListCard: some View {
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

        return VStack(alignment: .leading, spacing: 12) {
            Text(onThisDayMode == .lastYear ? "去年今日" : "近五年")
                .font(.headline)

            if entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
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
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        NavigationLink {
                            OnThisDayListView(entries: entries)
                        } label: {
                            OnThisDayEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var timelinePage: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.visibleEntries.isEmpty {
                    emptyTimeline
                } else {
                    ForEach(viewModel.visibleEntries) { entry in
                        TimelineEntryCard(entry: entry) {
                            viewModel.deleteEntry(id: entry.id)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyTimeline: some View {
        VStack(spacing: 10) {
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
        .padding(.vertical, 28)
        .cardStyle()
    }

    private var calendarPage: some View {
        ScrollView {
            VStack(spacing: 12) {
                CalendarDateCard(selectedDate: $selectedCalendarDate)

                CalendarDayEntriesCard(
                    date: selectedCalendarDate,
                    entries: entries(on: selectedCalendarDate)
                )

                CalendarAllImagesSection(groupedImages: groupedImagesByMonth)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
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

    private var profilePage: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("我的统计")
                        .font(.headline)

                    HStack(spacing: 10) {
                        StatCard(title: "日记总数", value: "\(viewModel.visibleEntries.count)")
                        StatCard(title: "图片回忆", value: "\(viewModel.allImageURLs.count)")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Label("打开设置与导出", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: 0xF3F4F6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .cardStyle()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private var bottomOverlay: some View {
        HStack(alignment: .bottom) {
            bottomNavBar
            Spacer(minLength: 10)
            addButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .safeAreaPadding(.bottom, 6)
    }

    private var bottomNavBar: some View {
        HStack(spacing: 4) {
            ForEach(BottomTab.allCases) { tab in
                Button {
                    selectedBottomTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selectedBottomTab == tab ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        )
    }

    private var addButton: some View {
        Button {
            showingNewEntry = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.black)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.22), radius: 14, y: 7)
        }
        .accessibilityLabel("新建日记")
    }

    private func iconCircleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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

private struct CalendarDateCard: View {
    @Binding var selectedDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
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

private struct CalendarDayEntriesCard: View {
    let date: Date
    let entries: [DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当日记录")
                .font(.headline)

            if entries.isEmpty {
                Text("这一天没有记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.title.isEmpty ? "无标题" : entry.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if let image = entry.extractImageURLs().first {
                            AsyncImage(url: image) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: 0xF3F4F6))
                                        .frame(height: 140)
                                        .overlay { ProgressView() }
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 140)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                case .failure:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(hex: 0xF3F4F6))
                                        .frame(height: 140)
                                        .overlay { Image(systemName: "photo") }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        Text(entry.content)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .background(Color(hex: 0xF7F8FA))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .cardStyle()
    }
}

private struct CalendarAllImagesSection: View {
    let groupedImages: [(String, [URL])]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("所有图片")
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(group.1, id: \.absoluteString) { url in
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.gray.opacity(0.12))
                                            .overlay { ProgressView() }
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.gray.opacity(0.12))
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

private struct OnThisDayEntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(entry.entryDate.formatted(.dateTime.year().month().day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF7F8FA))
        )
    }
}

private struct TimelineEntryCard: View {
    let entry: DiaryEntry
    let onDelete: () -> Void

    var firstImageURL: URL? {
        entry.extractImageURLs().first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title.isEmpty ? "无标题" : entry.title)
                        .font(.headline)
                    Text(entry.entryDate.formatted(.dateTime.year().month(.wide).day()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color(hex: 0xF3F4F6))
                        .clipShape(Circle())
                }
            }

            if let imageURL = firstImageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0xF3F4F6))
                            .frame(height: 180)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    case .failure:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: 0xF3F4F6))
                            .frame(height: 180)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .cardStyle()
    }
}

private struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: 0xF3F4F6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum BottomTab: CaseIterable, Identifiable {
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

private enum DiaryTab: CaseIterable, Identifiable {
    case timeline
    case onThisDay

    var id: String { title }

    var title: String {
        switch self {
        case .timeline: return "时间线"
        case .onThisDay: return "那年今日"
        }
    }
}

private enum OnThisDayMode: CaseIterable, Identifiable {
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

private extension DiaryEntry {
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

private extension View {
    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

private extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
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
