import Foundation

public enum LevelError: Error, Equatable, Sendable {
    case noReels
    case emptyReel(index: Int)
    case noTargets
    case duplicateTarget(String)
    case unreachableTarget(String)
}

public enum MoveResult: Equatable, Sendable {
    /// Yeni bir hedef kelime bulundu, bir ışık yandı.
    case newWord(String)
    /// Tabelada daha önce bulunmuş bir kelime okunuyor.
    case alreadyFound(String)
    /// Tabeladaki satır bu bölümün hedeflerinden biri değil.
    case notATarget
    /// Hamle yapılmadı (tek harfli makara, geçersiz makara ya da bölüm bitmiş).
    case ignored
}

/// Bir bölümün oynanış durumu. Saf değer tipi: arayüzden bağımsız, tamamen test edilebilir.
public struct GameState: Equatable, Sendable {
    public let level: Level
    public private(set) var positions: [Int]
    public private(set) var foundWords: [String]
    private var history: [[Int]] = []

    public init(level: Level) throws {
        try GameState.validate(level)
        self.level = level
        self.positions = Array(repeating: 0, count: level.reels.count)
        self.foundWords = []
        // Tabela açıldığında okunan satır bir hedefse, o ışık yanık başlar.
        let start = currentWord
        if level.targets.contains(start) {
            foundWords.append(start)
        }
    }

    /// Bölüm verisini kontrol eder. Geçersiz bölüm oyunu çökertmek yerine hata fırlatır.
    public static func validate(_ level: Level) throws {
        guard !level.reels.isEmpty else { throw LevelError.noReels }
        for (index, reel) in level.reels.enumerated() where reel.isEmpty {
            throw LevelError.emptyReel(index: index)
        }
        guard !level.targets.isEmpty else { throw LevelError.noTargets }

        var seen = Set<String>()
        for word in level.targets {
            guard seen.insert(word).inserted else { throw LevelError.duplicateTarget(word) }
            let letters = word.map { String($0) }
            guard letters.count == level.reels.count,
                  zip(letters, level.reels).allSatisfy({ $0.1.contains($0.0) })
            else { throw LevelError.unreachableTarget(word) }
        }
    }

    public var currentWord: String {
        zip(level.reels, positions).map { $0.0[$0.1] }.joined()
    }

    public var isComplete: Bool { foundWords.count == level.targets.count }

    public var canUndo: Bool { !history.isEmpty && !isComplete }

    public func letter(atReel reel: Int) -> String {
        level.reels[reel][positions[reel]]
    }

    public func canRotate(reel: Int) -> Bool {
        level.reels.indices.contains(reel) && level.reels[reel].count > 1 && !isComplete
    }

    /// Makarayı `step` kadar çevirir (pozitif: sonraki harf, negatif: önceki harf). Uçlarda başa sarar.
    @discardableResult
    public mutating func rotate(reel: Int, by step: Int) -> MoveResult {
        guard canRotate(reel: reel) else { return .ignored }
        let count = level.reels[reel].count
        guard step % count != 0 else { return .ignored }
        history.append(positions)
        positions[reel] = ((positions[reel] + step) % count + count) % count
        return evaluate()
    }

    /// Son hamleyi geri alır. Bulunan kelimeler geri alınmaz: oyuncu cezalandırılmaz.
    @discardableResult
    public mutating func undo() -> Bool {
        guard canUndo, let previous = history.popLast() else { return false }
        positions = previous
        return true
    }

    private mutating func evaluate() -> MoveResult {
        let word = currentWord
        guard level.targets.contains(word) else { return .notATarget }
        if foundWords.contains(word) { return .alreadyFound(word) }
        foundWords.append(word)
        return .newWord(word)
    }
}
