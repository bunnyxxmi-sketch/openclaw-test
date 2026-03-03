import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var isLoading: Bool = true

    let onThisDayService = OnThisDayService()
    let exportService = ExportService()
    private let store = DiaryStore()

    init() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            self.entries = store.load().sorted { $0.entryDate > $1.entryDate }
            self.isLoading = false
        }
    }

    func addEntry(title: String, content: String, date: Date, mood: Mood?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = DiaryEntry(
            entryDate: date,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: trimmed,
            mood: mood
        )
        entries.insert(entry, at: 0)
        persist()
    }

    func deleteEntry(id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].isDeleted = true
        entries[i].updatedAt = .now
        persist()
    }

    func persist() {
        store.save(entries)
    }

    var visibleEntries: [DiaryEntry] {
        entries.filter { !$0.isDeleted }.sorted { $0.entryDate > $1.entryDate }
    }

    var onThisDayEntries: [DiaryEntry] {
        onThisDayService.entriesForOnThisDay(from: visibleEntries)
    }

    var lastYearOnThisDayEntries: [DiaryEntry] {
        onThisDayService.entriesForYearOffsetOnThisDay(from: visibleEntries, yearOffset: 1)
    }

    var recentFiveYearOnThisDayEntries: [DiaryEntry] {
        onThisDayService.entriesForRecentYearsOnThisDay(from: visibleEntries, years: 5)
    }

    var allImageURLs: [URL] {
        var seen = Set<URL>()
        var urls: [URL] = []

        for entry in visibleEntries {
            for url in extractImageURLs(from: entry.content) where !seen.contains(url) {
                seen.insert(url)
                urls.append(url)
            }
        }

        return urls
    }

    private func extractImageURLs(from text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range)
            .compactMap { $0.url }
            .filter { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"].contains(ext)
            }
    }
}
