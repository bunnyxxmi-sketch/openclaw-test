import SwiftUI

struct OnThisDayListView: View {
    let entries: [DiaryEntry]

    var body: some View {
        List(entries) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title.isEmpty ? "无标题" : entry.title)
                    .font(.headline)
                Text(entry.content)
                    .font(.body)
                Text(entry.entryDate.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("去年今日")
    }
}
