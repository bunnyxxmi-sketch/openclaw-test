import Foundation

enum ICloudSyncState: Equatable {
    case disabled
    case enabledReady
    case unavailable(reason: String)
    case failed(reason: String)

    var title: String {
        switch self {
        case .disabled:
            return "未开启"
        case .enabledReady:
            return "已开启"
        case .unavailable:
            return "不可用"
        case .failed:
            return "同步失败"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            return "当前仅保存在本地设备。"
        case .enabledReady:
            return "本地与 iCloud 将自动同步（冲突按最近更新时间覆盖）。"
        case .unavailable(let reason), .failed(let reason):
            return reason
        }
    }
}

final class DiaryStore {
    private enum Keys {
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let iCloudNoticeShown = "iCloudSyncFirstNoticeShown"
    }

    private let fileManager: FileManager
    private let localFileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let defaults: UserDefaults

    init(fileManager: FileManager = .default, defaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.defaults = defaults

        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.localFileURL = docs.appendingPathComponent("diary_entries.json")

        self.encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    var isICloudSyncEnabled: Bool {
        get { defaults.bool(forKey: Keys.iCloudSyncEnabled) }
        set { defaults.set(newValue, forKey: Keys.iCloudSyncEnabled) }
    }

    var shouldShowFirstEnableNotice: Bool {
        !defaults.bool(forKey: Keys.iCloudNoticeShown)
    }

    func markFirstEnableNoticeShown() {
        defaults.set(true, forKey: Keys.iCloudNoticeShown)
    }

    func syncState() -> ICloudSyncState {
        guard isICloudSyncEnabled else { return .disabled }
        guard hasICloudAccount else {
            return .unavailable(reason: "设备未登录 iCloud 或当前构建未启用 iCloud Capability。")
        }
        guard cloudFileURL != nil else {
            return .unavailable(reason: "找不到 iCloud 容器，请检查 Xcode 中 iCloud Documents 配置。")
        }
        return .enabledReady
    }

    @discardableResult
    func setICloudEnabled(_ enabled: Bool) -> ICloudSyncState {
        isICloudSyncEnabled = enabled
        if enabled {
            let merged = mergeLatest(local: readEntries(from: localFileURL), cloud: readEntries(from: cloudFileURL))
            saveLocal(merged)
            if !saveCloud(merged) {
                return .failed(reason: "已开启，但首次同步未完成。请稍后重试（本地数据不受影响）。")
            }
        }
        return syncState()
    }

    func load() -> [DiaryEntry] {
        let localEntries = readEntries(from: localFileURL)
        guard isICloudSyncEnabled else { return localEntries }

        let cloudEntries = readEntries(from: cloudFileURL)
        let merged = mergeLatest(local: localEntries, cloud: cloudEntries)
        saveLocal(merged)
        _ = saveCloud(merged)
        return merged
    }

    @discardableResult
    func save(_ entries: [DiaryEntry]) -> ICloudSyncState {
        saveLocal(entries)
        guard isICloudSyncEnabled else { return .disabled }
        guard saveCloud(entries) else {
            return .failed(reason: "已保存到本地，但 iCloud 暂时不可写，稍后会自动重试。")
        }
        return .enabledReady
    }

    private var hasICloudAccount: Bool {
        fileManager.ubiquityIdentityToken != nil
    }

    private var cloudFileURL: URL? {
        guard let container = fileManager.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let docs = container.appendingPathComponent("Documents", isDirectory: true)
        if !fileManager.fileExists(atPath: docs.path) {
            try? fileManager.createDirectory(at: docs, withIntermediateDirectories: true)
        }
        return docs.appendingPathComponent("diary_entries.json")
    }

    private func readEntries(from url: URL?) -> [DiaryEntry] {
        guard let url else { return [] }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([DiaryEntry].self, from: data)) ?? []
    }

    private func saveLocal(_ entries: [DiaryEntry]) {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: localFileURL, options: .atomic)
    }

    private func saveCloud(_ entries: [DiaryEntry]) -> Bool {
        guard let url = cloudFileURL else { return false }
        guard let data = try? encoder.encode(entries) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func mergeLatest(local: [DiaryEntry], cloud: [DiaryEntry]) -> [DiaryEntry] {
        var map: [UUID: DiaryEntry] = [:]

        for entry in (local + cloud) {
            if let existing = map[entry.id] {
                map[entry.id] = entry.updatedAt >= existing.updatedAt ? entry : existing
            } else {
                map[entry.id] = entry
            }
        }

        return map.values.sorted { $0.entryDate > $1.entryDate }
    }
}
