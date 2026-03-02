import Foundation

public enum ExportFormat: String, CaseIterable, Sendable {
    case json
    case markdown

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .markdown: return "md"
        }
    }
}

public struct ExportResult: Sendable {
    public let fileURL: URL
    public let format: ExportFormat
}

public enum ExportServiceError: Error {
    case encodeFailed
    case writeFailed
}

public struct ExportService {
    private let encoder: JSONEncoder

    public init() {
        var encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func export(
        entries: [DiaryEntry],
        as format: ExportFormat,
        fileManager: FileManager = .default
    ) throws -> ExportResult {
        let validEntries = entries.filter { !$0.isDeleted }
        let filename = "otter-diary-export-\(timestamp()).\(format.fileExtension)"
        let url = fileManager.temporaryDirectory.appendingPathComponent(filename)

        switch format {
        case .json:
            let data = try encoder.encode(validEntries)
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                throw ExportServiceError.writeFailed
            }

        case .markdown:
            let markdown = renderMarkdown(validEntries)
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw ExportServiceError.writeFailed
            }
        }

        return ExportResult(fileURL: url, format: format)
    }

    private func renderMarkdown(_ entries: [DiaryEntry]) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"

        let sorted = entries.sorted { $0.entryDate > $1.entryDate }

        var output = "# Otter Diary Export\n\n"
        for entry in sorted {
            let title = (entry.title?.isEmpty == false) ? entry.title! : "无标题"
            let date = formatter.string(from: entry.entryDate)
            let moodText = entry.mood?.rawValue ?? "none"
            let tagsText = entry.tags.isEmpty ? "-" : entry.tags.joined(separator: ", ")

            output += "## \(title)\n"
            output += "- Date: \(date)\n"
            output += "- Mood: \(moodText)\n"
            output += "- Tags: \(tagsText)\n\n"
            output += "\(entry.content)\n\n---\n\n"
        }

        return output
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
