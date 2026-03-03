import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var viewModel: DiaryViewModel

    @State private var selectedPage: HomePage = .timeline
    @State private var onThisDayMode: OnThisDayMode = .lastYear
    @State private var showingNewEntry = false
    @State private var showingSettings = false
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportFormat: ExportFormat = .json
    @State private var exportError = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                pagePicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                TabView(selection: $selectedPage) {
                    timelinePage
                        .tag(HomePage.timeline)

                    GalleryView(imageURLs: viewModel.allImageURLs)
                        .tag(HomePage.gallery)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.34, dampingFraction: 0.9), value: selectedPage)
            }

            fabButton
        }
        .navigationTitle("Otter Diary")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(greetingText)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                Text(todayPrompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 10, y: 6)
        }
    }

    private var pagePicker: some View {
        HStack(spacing: 8) {
            ForEach(HomePage.allCases) { page in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedPage = page
                    }
                } label: {
                    Text(page.title)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selectedPage == page {
                                Capsule(style: .continuous)
                                    .fill(Color.accentColor.opacity(0.15))
                            }
                        }
                        .foregroundStyle(selectedPage == page ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var timelinePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                onThisDaySection
                allEntriesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
    }

    private var onThisDaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同一天回顾")
                .font(.headline)

            Picker("筛选", selection: $onThisDayMode) {
                Text("去年今日").tag(OnThisDayMode.lastYear)
                Text("近五年").tag(OnThisDayMode.recentFiveYears)
            }
            .pickerStyle(.segmented)

            let entries = onThisDayMode == .lastYear ? viewModel.lastYearOnThisDayEntries : Array(viewModel.recentFiveYearOnThisDayEntries)

            if entries.isEmpty {
                ContentUnavailableView(
                    onThisDayMode == .lastYear ? "去年今日还没有记录" : "近五年的今天还没有记录",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("今天写下新的一页，明年就能在这里重逢。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        NavigationLink {
                            OnThisDayListView(entries: onThisDayMode == .lastYear ? [entry] : viewModel.recentFiveYearOnThisDayEntries)
                        } label: {
                            OnThisDayCard(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeOut(duration: 0.25), value: entries.count)
            }
        }
    }

    private var allEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部日记")
                .font(.headline)

            if viewModel.visibleEntries.isEmpty {
                ContentUnavailableView("还没有日记", systemImage: "book.closed", description: Text("点右下角新建，开始记录今天。"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.visibleEntries) { entry in
                        EntryCard(entry: entry) {
                            viewModel.deleteEntry(id: entry.id)
                        }
                    }
                }
            }
        }
    }

    private var fabButton: some View {
        Button {
            showingNewEntry = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.blue.gradient)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 22)
        .safeAreaPadding(.bottom, 4)
        .accessibilityLabel("新建日记")
        .accessibilityHint("打开新建日记页面")
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "早安，今天也记录一点吧"
        case 12..<18: return "下午好，今天过得怎么样？"
        default: return "晚上好，留住今天的片段"
        }
    }

    private var todayPrompt: String {
        "写下一个瞬间、一句心情，都会成为未来的礼物。"
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

private struct OnThisDayCard: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(entry.entryDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct EntryCard: View {
    let entry: DiaryEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                Spacer(minLength: 8)
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private enum HomePage: String, CaseIterable, Identifiable {
    case timeline
    case gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "今天"
        case .gallery: return "图片"
        }
    }
}

private enum OnThisDayMode {
    case lastYear
    case recentFiveYears
}

struct GalleryView: View {
    let imageURLs: [URL]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            if imageURLs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary)
                    Text("还没有图片回忆")
                        .font(.headline)
                    Text("在日记正文里粘贴图片链接，这里会自动汇总成相册。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.top, 90)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(imageURLs, id: \.absoluteString) { url in
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
                                    .overlay {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.secondary)
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .background(Color(.systemGroupedBackground))
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
