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
    var location: String?
    var weather: String?
    var tags: [String]
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
        location: String? = nil,
        weather: String? = nil,
        tags: [String] = [],
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
        self.location = location
        self.weather = weather
        self.tags = tags
        self.imageAssetPaths = imageAssetPaths
        self.isDeleted = isDeleted
    }
}

extension DiaryEntry {
    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, entryDate, title, content, mood, emoji, location, weather, tags, imageAssetPaths, isDeleted
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case tag
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        entryDate = try c.decode(Date.self, forKey: .entryDate)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        mood = try c.decodeIfPresent(Mood.self, forKey: .mood)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        location = try c.decodeIfPresent(String.self, forKey: .location)
        weather = try c.decodeIfPresent(String.self, forKey: .weather)

        let decodedTags = (try? c.decodeIfPresent([String].self, forKey: .tags)) ?? []
        let legacyTags = (try? legacy?.decodeIfPresent([String].self, forKey: .tag)) ?? []
        tags = Self.normalizedTags(decodedTags + legacyTags)

        imageAssetPaths = try c.decodeIfPresent([String].self, forKey: .imageAssetPaths) ?? []
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }

    static func normalizedTags(_ rawTags: [String]) -> [String] {
        var seen = Set<String>()
        return rawTags.compactMap { raw in
            let cleaned = normalizeTag(raw)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }

    static func normalizeTag(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
    }
}
