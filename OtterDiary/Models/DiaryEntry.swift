import Foundation

enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy = "开心"
    case calm = "平静"
    case tired = "疲惫"
    case sad = "难过"
    case excited = "兴奋"

    var id: String { rawValue }
}

struct DiaryEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var entryDate: Date
    var title: String
    var content: String
    var mood: Mood?
    var emoji: String?
    var imageAssetPaths: [String]
    var isDeleted: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        entryDate: Date = .now,
        title: String = "",
        content: String,
        mood: Mood? = nil,
        emoji: String? = nil,
        imageAssetPaths: [String] = [],
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.entryDate = entryDate
        self.title = title
        self.content = content
        self.mood = mood
        self.emoji = emoji
        self.imageAssetPaths = imageAssetPaths
        self.isDeleted = isDeleted
    }
}
