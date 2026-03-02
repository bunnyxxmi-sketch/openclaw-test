import Foundation

@MainActor
final class DiaryViewModel: ObservableObject {
    @Published var entries: [DiaryEntry] = []

    let onThisDayService = OnThisDayService()
    let exportService = ExportService()
    private let store = DiaryStore()

    init() {
        self.entries = store.load().sorted { $0.entryDate > $1.entryDate }
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
}
