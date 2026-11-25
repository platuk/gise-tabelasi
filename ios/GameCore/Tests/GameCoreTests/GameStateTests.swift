import XCTest
@testable import GameCore

final class GameStateTests: XCTestCase {
    private let karKas = Level(id: 1, reels: [["K"], ["A"], ["R", "Ş"]], targets: ["KAR", "KAŞ"])
    private let abc = Level(id: 2, reels: [["A", "B", "C"], ["X"], ["Y"]], targets: ["AXY", "BXY", "CXY"])

    func testStartingWordIsFoundAutomatically() throws {
        let game = try GameState(level: karKas)
        XCTAssertEqual(game.currentWord, "KAR")
        XCTAssertEqual(game.foundWords, ["KAR"])
        XCTAssertFalse(game.isComplete)
    }

    func testRotateFindsNewWordAndCompletesLevel() throws {
        var game = try GameState(level: karKas)
        XCTAssertEqual(game.rotate(reel: 2, by: 1), .newWord("KAŞ"))
        XCTAssertTrue(game.isComplete)
    }

    func testRotationWrapsInBothDirections() throws {
        var game = try GameState(level: abc)
        XCTAssertEqual(game.rotate(reel: 0, by: -1), .newWord("CXY"))
        XCTAssertEqual(game.positions, [2, 0, 0])
        XCTAssertEqual(game.rotate(reel: 0, by: 1), .alreadyFound("AXY"))
        XCTAssertEqual(game.positions, [0, 0, 0])
    }

    func testFullTurnIsIgnored() throws {
        var game = try GameState(level: abc)
        XCTAssertEqual(game.rotate(reel: 0, by: 3), .ignored)
        XCTAssertFalse(game.canUndo)
    }

    func testSingleLetterAndInvalidReelsAreIgnored() throws {
        var game = try GameState(level: abc)
        XCTAssertEqual(game.rotate(reel: 1, by: 1), .ignored)
        XCTAssertEqual(game.rotate(reel: 9, by: 1), .ignored)
        XCTAssertEqual(game.rotate(reel: -1, by: 1), .ignored)
        XCTAssertFalse(game.canRotate(reel: 1))
        XCTAssertFalse(game.canUndo)
        XCTAssertEqual(game.positions, [0, 0, 0])
    }

    func testUndoRestoresPositionsButKeepsFoundWords() throws {
        var game = try GameState(level: abc)
        XCTAssertEqual(game.rotate(reel: 0, by: 1), .newWord("BXY"))
        XCTAssertTrue(game.undo())
        XCTAssertEqual(game.positions, [0, 0, 0])
        XCTAssertTrue(game.foundWords.contains("BXY"))
        XCTAssertFalse(game.undo())
    }

    func testNoInputAfterCompletion() throws {
        var game = try GameState(level: karKas)
        game.rotate(reel: 2, by: 1)
        XCTAssertTrue(game.isComplete)
        XCTAssertEqual(game.rotate(reel: 2, by: 1), .ignored)
        XCTAssertFalse(game.canUndo)
        XCTAssertFalse(game.undo())
    }

    func testNonTargetWordIsReported() throws {
        let level = Level(id: 3, reels: [["K"], ["E"], ["D"], ["İ", "I"]], targets: ["KEDİ"])
        var game = try GameState(level: level)
        XCTAssertTrue(game.isComplete) // tek hedef, başlangıçta bulundu
        let level2 = Level(id: 4, reels: [["K", "Y"], ["E"], ["D"], ["İ", "I"]], targets: ["KEDİ", "YEDİ"])
        game = try GameState(level: level2)
        // Türkçe İ ile I farklı harflerdir: KEDI hedef değildir.
        XCTAssertEqual(game.rotate(reel: 3, by: 1), .notATarget)
        XCTAssertEqual(game.currentWord, "KEDI")
    }

    func testValidationErrors() {
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [], targets: ["A"]))) {
            XCTAssertEqual($0 as? LevelError, .noReels)
        }
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [["A"], []], targets: ["AB"]))) {
            XCTAssertEqual($0 as? LevelError, .emptyReel(index: 1))
        }
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [["A"]], targets: []))) {
            XCTAssertEqual($0 as? LevelError, .noTargets)
        }
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [["A"], ["B"]], targets: ["AB", "AB"]))) {
            XCTAssertEqual($0 as? LevelError, .duplicateTarget("AB"))
        }
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [["A"], ["B"]], targets: ["AC"]))) {
            XCTAssertEqual($0 as? LevelError, .unreachableTarget("AC"))
        }
        XCTAssertThrowsError(try GameState(level: Level(id: 1, reels: [["A"], ["B"]], targets: ["ABB"]))) {
            XCTAssertEqual($0 as? LevelError, .unreachableTarget("ABB"))
        }
    }
}
