import Foundation

public enum Mood: String, Codable, CaseIterable, Sendable {
    case happy
    case calm
    case tired
    case sad
    case excited
}

public struct DiaryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var entryDate: Date
    public var title: String?
    public var content: String
    public var mood: Mood?
    public var tags: [String]
    public var isDeleted: Bool

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        entryDate: Date = .now,
        title: String? = nil,
        content: String,
        mood: Mood? = nil,
        tags: [String] = [],
        isDeleted: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.entryDate = entryDate
        self.title = title
        self.content = content
        self.mood = mood
        self.tags = tags
        self.isDeleted = isDeleted
    }

    public mutating func touchUpdate() {
        updatedAt = .now
    }

    /// Key used for on-this-day matching, e.g. "03-02"
    public var monthDayKey: String {
        let calendar = Calendar(identifier: .gregorian)
        let month = calendar.component(.month, from: entryDate)
        let day = calendar.component(.day, from: entryDate)
        return String(format: "%02d-%02d", month, day)
    }
}
