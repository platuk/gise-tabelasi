import Foundation

/// Tek bir bölüm. `reels[i]`, tabeladaki i. konumda dönebilen harfler.
/// Veri kaynağı: repo kökündeki `levels/<dil>.json`.
public struct Level: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let reels: [[String]]
    public let targets: [String]

    public init(id: Int, reels: [[String]], targets: [String]) {
        self.id = id
        self.reels = reels
        self.targets = targets
    }

    public var wordLength: Int { reels.count }
}

/// Bir dilin tüm bölümleri.
public struct LevelPack: Codable, Equatable, Sendable {
    public let language: String
    public let levels: [Level]

    public init(language: String, levels: [Level]) {
        self.language = language
        self.levels = levels
    }

    public static func decode(from data: Data) throws -> LevelPack {
        try JSONDecoder().decode(LevelPack.self, from: data)
    }

    public func level(withID id: Int) -> Level? {
        levels.first { $0.id == id }
    }

    public func nextLevel(after id: Int) -> Level? {
        guard let index = levels.firstIndex(where: { $0.id == id }), index + 1 < levels.count else {
            return nil
        }
        return levels[index + 1]
    }
}
