import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var viewModel: DiaryViewModel

    @State private var showingNewEntry = false
    @State private var exportURL: URL?
    @State private var showingExporter = false
    @State private var exportFormat: ExportFormat = .json
    @State private var exportError = false

    var body: some View {
        List {
            Section {
                if viewModel.onThisDayEntries.isEmpty {
                    Text("去年今日还没有记录，今天写下第一条吧。")
                        .foregroundStyle(.secondary)
                } else {
                    NavigationLink {
                        OnThisDayListView(entries: viewModel.onThisDayEntries)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("去年今日")
                                .font(.headline)
                            Text(viewModel.onThisDayEntries.first?.title.isEmpty == false ? viewModel.onThisDayEntries.first!.title : "查看往年同日记录")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("全部日记") {
                if viewModel.visibleEntries.isEmpty {
                    Text("还没有日记，点右上角 + 开始记录。")
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
        .navigationTitle("Otter Diary")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("导出 JSON 到 Files") { doExport(.json) }
                    Button("导出 Markdown 到 Files") { doExport(.markdown) }
                } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingNewEntry = true
                } label: {
                    Label("新建", systemImage: "plus")
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
