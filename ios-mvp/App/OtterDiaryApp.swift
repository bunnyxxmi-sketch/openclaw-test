import SwiftUI

@main
struct OtterDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView(entries: seedEntries)
        }
    }

    /// Temporary seed for MVP preview/demo.
    private var seedEntries: [DiaryEntry] {
        [
            DiaryEntry(
                entryDate: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now,
                title: "去年今日",
                content: "给自己煮了一杯热可可，晚上看了海獭纪录片。",
                mood: .calm,
                tags: ["生活", "治愈"]
            ),
            DiaryEntry(
                entryDate: .now,
                title: "MVP Day 1",
                content: "完成了首页、去年今日与导出服务骨架。",
                mood: .excited,
                tags: ["开发", "iOS"]
            )
        ]
    }
}
