import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []
    @Published var isLoading: Bool = true
    @Published var isICloudSyncEnabled: Bool = false
    @Published var iCloudSyncState: ICloudSyncState = .disabled
    @Published var latestSyncMessage: String?

    let onThisDayService = OnThisDayService()
    let exportService = ExportService()
    private let store = DiaryStore()

    init() {
        isICloudSyncEnabled = store.isICloudSyncEnabled
        iCloudSyncState = store.syncState()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            let loaded = store.load().sorted { $0.entryDate > $1.entryDate }
            self.entries = self.migrateTagsIfNeeded(in: loaded)
            self.iCloudSyncState = store.syncState()
            self.isLoading = false
        }
    }

    func addEntry(title: String, content: String, date: Date, mood: Mood?, emoji: String?, tags: [String] = [], location: String? = nil, weather: String? = nil, imageAssetPaths: [String]) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = DiaryEntry(
            entryDate: date,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: trimmed,
            mood: mood,
            emoji: emoji,
            location: location?.trimmingCharacters(in: .whitespacesAndNewlines),
            weather: weather?.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: normalizedTags(inputTags: tags, content: trimmed),
            imageAssetPaths: imageAssetPaths
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

    func updateEntry(id: UUID, title: String, content: String, date: Date, mood: Mood?, emoji: String?, tags: [String] = [], location: String? = nil, weather: String? = nil, imageAssetPaths: [String]) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        entries[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[i].content = trimmed
        entries[i].entryDate = date
        entries[i].mood = mood
        entries[i].emoji = emoji
        entries[i].location = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[i].weather = weather?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[i].tags = normalizedTags(inputTags: tags, content: trimmed)
        entries[i].imageAssetPaths = imageAssetPaths
        entries[i].updatedAt = .now
        persist()
    }

    func persist() {
        let state = store.save(entries)
        iCloudSyncState = state
        if case .failed(let reason) = state {
            latestSyncMessage = reason
        }
    }

    func toggleICloudSync(_ enabled: Bool) {
        let state = store.setICloudEnabled(enabled)
        isICloudSyncEnabled = enabled
        iCloudSyncState = state
        let loaded = store.load().sorted { $0.entryDate > $1.entryDate }
        entries = migrateTagsIfNeeded(in: loaded)
        if case .failed(let reason) = state {
            latestSyncMessage = reason
        }
    }

    func firstEnableNoticeIfNeeded() -> String? {
        guard store.shouldShowFirstEnableNotice else { return nil }
        store.markFirstEnableNoticeShown()
        return "已开启 iCloud 同步：日记仍可离线使用；当网络可用时会自动同步，多端冲突按最近更新时间覆盖。"
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
            for path in entry.imageAssetPaths {
                let localURL = localImageURL(for: path)
                if !seen.contains(localURL) {
                    seen.insert(localURL)
                    urls.append(localURL)
                }
            }
            for url in extractImageURLs(from: entry.content) where !seen.contains(url) {
                seen.insert(url)
                urls.append(url)
            }
        }

        return urls
    }




    private func migrateTagsIfNeeded(in loaded: [DiaryEntry]) -> [DiaryEntry] {
        var didChange = false
        let migrated = loaded.map { original -> DiaryEntry in
            var entry = original
            let merged = normalizedTags(inputTags: entry.tags, content: entry.content)
            if merged != entry.tags {
                entry.tags = merged
                entry.updatedAt = .now
                didChange = true
            }
            return entry
        }
        if didChange {
            _ = store.save(migrated)
        }
        return migrated
    }

    private func normalizedTags(inputTags: [String], content: String) -> [String] {
        DiaryEntry.normalizedTags(inputTags + extractHashTags(from: content))
    }

    private func extractHashTags(from text: String) -> [String] {
        let pattern = "#([\\p{L}\\p{N}_-]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > 1, let tagRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[tagRange])
        }
    }

    private func localImageURL(for relativePath: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent(relativePath)
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
