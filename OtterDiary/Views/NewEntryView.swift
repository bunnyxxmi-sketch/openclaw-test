import SwiftUI

struct NewEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var date = Date()
    @State private var mood: Mood? = nil

    let onSave: (_ title: String, _ content: String, _ date: Date, _ mood: Mood?) -> Void

    var body: some View {
        Form {
            Section("内容") {
                TextField("标题（可选）", text: $title)
                    .textInputAutocapitalization(.sentences)
                DatePicker("日期", selection: $date, displayedComponents: .date)
                Picker("心情", selection: $mood) {
                    Text("未填写").tag(Mood?.none)
                    ForEach(Mood.allCases) { m in
                        Text(m.rawValue).tag(Mood?.some(m))
                    }
                }
                TextField("写下今天…", text: $content, axis: .vertical)
                    .lineLimit(6...12)
            }
        }
        .navigationTitle("新建日记")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(title, content, date, mood)
                    dismiss()
                }
                .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
