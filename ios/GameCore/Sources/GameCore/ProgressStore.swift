import Foundation

/// Oyuncunun bir dildeki ilerlemesi. (Foundation'daki `Progress` ile karışmasın diye bu ad.)
public struct PlayerProgress: Codable, Equatable, Sendable {
    public var completedLevelIDs: Set<Int>

    public init(completedLevelIDs: Set<Int> = []) {
        self.completedLevelIDs = completedLevelIDs
    }

    public func isCompleted(_ levelID: Int) -> Bool {
        completedLevelIDs.contains(levelID)
    }

    /// Kilit kuralı: listedeki ilk bölüm her zaman açık; diğerleri bir önceki bölüm bitince açılır.
    public func isUnlocked(_ level: Level, in pack: LevelPack) -> Bool {
        guard let index = pack.levels.firstIndex(where: { $0.id == level.id }) else { return false }
        return index == 0 || completedLevelIDs.contains(pack.levels[index - 1].id)
    }
}

public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
}

public final class UserDefaultsStore: KeyValueStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func setData(_ data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }
}

/// İlerlemeyi dil başına ayrı saklar. Her kayıtta bir önceki geçerli kayıt yedeklenir;
/// asıl kayıt bozulursa yedekten okunur, oyuncunun ilerlemesi sıfırlanmaz.
public final class ProgressStore {
    private let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    static func primaryKey(_ language: String) -> String { "progress.\(language)" }
    static func backupKey(_ language: String) -> String { "progress.\(language).backup" }

    public func load(language: String) -> PlayerProgress {
        for key in [Self.primaryKey(language), Self.backupKey(language)] {
            if let data = store.data(forKey: key),
               let progress = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
                return progress
            }
        }
        return PlayerProgress()
    }

    public func save(_ progress: PlayerProgress, language: String) {
        let primary = Self.primaryKey(language)
        if let current = store.data(forKey: primary),
           (try? JSONDecoder().decode(PlayerProgress.self, from: current)) != nil {
            store.setData(current, forKey: Self.backupKey(language))
        }
        guard let data = try? JSONEncoder().encode(progress) else { return }
        store.setData(data, forKey: primary)
    }
}
