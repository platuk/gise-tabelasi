import XCTest
@testable import GameCore

private final class MemoryStore: KeyValueStore {
    var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func setData(_ data: Data?, forKey key: String) { values[key] = data }
}

final class ProgressStoreTests: XCTestCase {
    func testSaveAndLoad() {
        let store = ProgressStore(store: MemoryStore())
        store.save(PlayerProgress(completedLevelIDs: [1, 2]), language: "tr")
        XCTAssertEqual(store.load(language: "tr").completedLevelIDs, [1, 2])
    }

    func testLanguagesAreIndependent() {
        let store = ProgressStore(store: MemoryStore())
        store.save(PlayerProgress(completedLevelIDs: [1, 2, 3]), language: "tr")
        XCTAssertEqual(store.load(language: "en"), PlayerProgress())
        XCTAssertEqual(store.load(language: "tr").completedLevelIDs, [1, 2, 3])
    }

    func testCorruptPrimaryFallsBackToBackup() {
        let memory = MemoryStore()
        let store = ProgressStore(store: memory)
        store.save(PlayerProgress(completedLevelIDs: [1]), language: "tr")
        store.save(PlayerProgress(completedLevelIDs: [1, 2]), language: "tr")
        memory.setData(Data("bozuk".utf8), forKey: ProgressStore.primaryKey("tr"))
        XCTAssertEqual(store.load(language: "tr").completedLevelIDs, [1])
    }

    func testCorruptPrimaryIsNotCopiedOverBackup() {
        let memory = MemoryStore()
        let store = ProgressStore(store: memory)
        store.save(PlayerProgress(completedLevelIDs: [1]), language: "tr")
        store.save(PlayerProgress(completedLevelIDs: [1, 2]), language: "tr")
        memory.setData(Data("bozuk".utf8), forKey: ProgressStore.primaryKey("tr"))
        store.save(PlayerProgress(completedLevelIDs: [1, 2, 3]), language: "tr")
        memory.setData(Data("bozuk".utf8), forKey: ProgressStore.primaryKey("tr"))
        XCTAssertEqual(store.load(language: "tr").completedLevelIDs, [1])
    }

    func testEverythingCorruptGivesEmptyProgress() {
        let memory = MemoryStore()
        memory.setData(Data("x".utf8), forKey: ProgressStore.primaryKey("tr"))
        memory.setData(Data("y".utf8), forKey: ProgressStore.backupKey("tr"))
        XCTAssertEqual(ProgressStore(store: memory).load(language: "tr"), PlayerProgress())
    }

    func testUnlockRule() {
        let pack = LevelPack(language: "tr", levels: [
            Level(id: 1, reels: [["A"]], targets: ["A"]),
            Level(id: 2, reels: [["B"]], targets: ["B"]),
            Level(id: 3, reels: [["C"]], targets: ["C"]),
        ])
        var progress = PlayerProgress()
        XCTAssertTrue(progress.isUnlocked(pack.levels[0], in: pack))
        XCTAssertFalse(progress.isUnlocked(pack.levels[1], in: pack))
        progress.completedLevelIDs.insert(1)
        XCTAssertTrue(progress.isUnlocked(pack.levels[1], in: pack))
        XCTAssertFalse(progress.isUnlocked(pack.levels[2], in: pack))
        XCTAssertFalse(progress.isUnlocked(Level(id: 99, reels: [["Z"]], targets: ["Z"]), in: pack))
    }
}
