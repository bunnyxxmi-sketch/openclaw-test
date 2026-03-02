import SwiftUI

public struct HomeView: View {
    @State private var entries: [DiaryEntry]
    @State private var draftText: String = ""

    private let onThisDayService = OnThisDayService()

    public init(entries: [DiaryEntry] = []) {
        _entries = State(initialValue: entries)
    }

    public var body: some View {
        NavigationStack {
            List {
                quickEntrySection
                onThisDaySection
                recentEntriesSection
            }
            .navigationTitle("海獭日记")
        }
    }

    private var quickEntrySection: some View {
        Section("今天写点什么") {
            TextField("记录这一刻…", text: $draftText, axis: .vertical)
                .lineLimit(3...6)

            Button("保存一条") {
                guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                let newEntry = DiaryEntry(
                    entryDate: .now,
                    content: draftText,
                    mood: .calm
                )
                entries.insert(newEntry, at: 0)
                draftText = ""
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var onThisDaySection: some View {
        let onThisDayEntries = onThisDayService.entriesForOnThisDay(from: entries)

        return Section("去年今日") {
            if onThisDayEntries.isEmpty {
                Text("去年今日还没有记录，今天写下第一条吧。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(onThisDayEntries.prefix(3)) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title ?? "无标题")
                            .font(.headline)
                        Text(entry.content)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var recentEntriesSection: some View {
        Section("最近记录") {
            if entries.isEmpty {
                Text("还没有日记，先写下今天的心情。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.sorted(by: { $0.entryDate > $1.entryDate }).prefix(20)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title ?? "无标题")
                            .font(.headline)
                        Text(entry.content)
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            markDeleted(id: entry.id)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func markDeleted(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isDeleted = true
        entries[index].touchUpdate()
    }
}

#Preview {
    HomeView(entries: [
        DiaryEntry(entryDate: .now.addingTimeInterval(-86400 * 365), title: "去年的今天", content: "在海边散步，风很轻。", mood: .happy),
        DiaryEntry(entryDate: .now, title: "今天", content: "把 MVP 骨架搭好了。", mood: .excited)
    ])
}
