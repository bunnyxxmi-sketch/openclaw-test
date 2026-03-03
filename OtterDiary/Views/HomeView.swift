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
            VStack(spacing: 12) {
                Picker("页面", selection: $selectedPage) {
                    ForEach(HomePage.allCases) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                TabView(selection: $selectedPage) {
                    timelinePage
                        .tag(HomePage.timeline)

                    GalleryView(imageURLs: viewModel.allImageURLs)
                        .tag(HomePage.gallery)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            Button {
                showingNewEntry = true
            } label: {
                Label("新建日记", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4, y: 2)
            }
            .padding()
            .accessibilityLabel("新建日记")
            .accessibilityHint("打开新建日记页面")
        }
        .navigationTitle("Otter Diary")
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

    private var timelinePage: some View {
        List {
            Section("同一天回顾") {
                Picker("筛选", selection: $onThisDayMode) {
                    Text("去年今日").tag(OnThisDayMode.lastYear)
                    Text("最近五年").tag(OnThisDayMode.recentFiveYears)
                }
                .pickerStyle(.segmented)

                let entries = onThisDayMode == .lastYear ? viewModel.lastYearOnThisDayEntries : Array(viewModel.recentFiveYearOnThisDayEntries)

                if entries.isEmpty {
                    Text(onThisDayMode == .lastYear ? "去年今日还没有记录，今天写下第一条吧。" : "最近五年的今天还没有记录。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entries)) { entry in
                        NavigationLink {
                            OnThisDayListView(entries: onThisDayMode == .lastYear ? [entry] : viewModel.recentFiveYearOnThisDayEntries)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(entry.title.isEmpty ? "无标题" : entry.title)
                                    .font(.headline)
                                Text(entry.content)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section("全部日记") {
                if viewModel.visibleEntries.isEmpty {
                    Text("还没有日记，点右下角新建开始记录。")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.visibleEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title.isEmpty ? "无标题" : entry.title)
                            .font(.headline)
                        Text(entry.content)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                        Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteEntry(id: entry.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
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

private enum HomePage: String, CaseIterable, Identifiable {
    case timeline
    case gallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: return "今天"
        case .gallery: return "所有图片"
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
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            if imageURLs.isEmpty {
                ContentUnavailableView("暂无图片", systemImage: "photo.on.rectangle.angled", description: Text("在日记正文中加入图片链接后会显示在这里。"))
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(imageURLs, id: \.absoluteString) { url in
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.15))
                                    .overlay { ProgressView() }
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.gray.opacity(0.15))
                                    .overlay {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.secondary)
                                    }
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let onExportJSON: () -> Void
    let onExportMarkdown: () -> Void

    var body: some View {
        List {
            Section("数据") {
                Button("导出 JSON 到 Files") {
                    onExportJSON()
                    dismiss()
                }
                Button("导出 Markdown 到 Files") {
                    onExportMarkdown()
                    dismiss()
                }
            }
        }
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
