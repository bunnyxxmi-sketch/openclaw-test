import SwiftUI

struct OnThisDayListView: View {
    let entries: [DiaryEntry]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(entry.title.isEmpty ? "无标题" : entry.title)
                                .font(.headline)
                            Spacer(minLength: 8)
                            Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text(entry.content)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(entries.count > 1 ? "近五年" : "去年今日")
    }
}
