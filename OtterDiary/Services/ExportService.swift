import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case json = "JSON"
    case markdown = "Markdown"

    var id: String { rawValue }
    var fileExtension: String { self == .json ? "json" : "md" }
}

struct ExportService {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    func export(entries: [DiaryEntry], format: ExportFormat) throws -> URL {
        let entries = entries.filter { !$0.isDeleted }.sorted { $0.entryDate > $1.entryDate }
        let filename = "otter-diary-\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        switch format {
        case .json:
            let data = try encoder.encode(entries)
            try data.write(to: url, options: .atomic)
        case .markdown:
            try renderMarkdown(entries).write(to: url, atomically: true, encoding: .utf8)
        }

        return url
    }

    private func renderMarkdown(_ entries: [DiaryEntry]) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var result = "# Otter Diary Export\n\n"
        for e in entries {
            result += "## \(e.title.isEmpty ? "无标题" : e.title)\n"
            result += "- 日期: \(formatter.string(from: e.entryDate))\n"
            result += "- 心情: \(e.mood?.rawValue ?? "未填写")\n\n"
            result += "\(e.content)\n\n---\n\n"
        }
        return result
    }
}
