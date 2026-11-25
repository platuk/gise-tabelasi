import XCTest
@testable import GameCore

/// Gerçek bölüm dosyalarını (repo kökündeki levels/) uygulamanın kullandığı kodla okur ve oynar.
final class LevelPackTests: XCTestCase {
    static let languages = ["tr", "en"]

    static let levelsDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // Tests/GameCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // GameCore
        .deletingLastPathComponent() // ios
        .deletingLastPathComponent() // repo kökü
        .appendingPathComponent("levels")

    private func loadPack(_ language: String) throws -> LevelPack {
        let url = Self.levelsDirectory.appendingPathComponent("\(language).json")
        return try LevelPack.decode(from: Data(contentsOf: url))
    }

    func testPacksDecodeAndEveryLevelIsValid() throws {
        for language in Self.languages {
            let pack = try loadPack(language)
            XCTAssertEqual(pack.language, language)
            XCTAssertFalse(pack.levels.isEmpty)
            for level in pack.levels {
                XCTAssertNoThrow(try GameState.validate(level), "\(language) bölüm \(level.id)")
            }
        }
    }

    /// Her bölümü, makaraları kilometre sayacı gibi çevirerek baştan sona oynar.
    /// Bölüm tamamlanamıyorsa test başarısız olur.
    func testEveryLevelCanBeCompletedByPlaying() throws {
        for language in Self.languages {
            for level in try loadPack(language).levels {
                var game = try GameState(level: level)
                let combinations = level.reels.reduce(1) { $0 * $1.count }
                var moves = 0
                while !game.isComplete && moves < combinations {
                    advance(&game)
                    moves += 1
                }
                XCTAssertTrue(game.isComplete, "\(language) bölüm \(level.id) tamamlanamadı")
            }
        }
    }

    func testNextLevelAndLookup() throws {
        let pack = try loadPack("tr")
        XCTAssertEqual(pack.level(withID: 1)?.id, 1)
        XCTAssertEqual(pack.nextLevel(after: 1)?.id, 2)
        XCTAssertNil(pack.nextLevel(after: pack.levels.last!.id))
        XCTAssertNil(pack.level(withID: 9999))
    }

    private func advance(_ game: inout GameState) {
        var reel = game.level.reels.count - 1
        while reel >= 0 {
            game.rotate(reel: reel, by: 1)
            if game.positions[reel] != 0 { return }
            reel -= 1
        }
    }
}
