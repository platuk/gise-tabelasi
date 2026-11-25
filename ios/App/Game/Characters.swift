import SpriteKit

/// Karakterin baş süsü.
enum Accessory {
    case none
    /// Asansörcü/komi şapkası (Tıpı).
    case bellhop
    case dogEars
    case catEars
    case topHat
    case propeller
}

/// Kuyruk: arkadan sallanır, hareketin gerisinden gelir (follow-through).
enum Tail {
    case none
    /// Uzun, kıvrık.
    case cat
    /// Kısa, sevinince sallanır.
    case dog
}

/// Bir karakterin renkleri, süsü ve oranları. Hepsi aynı lastik hortum iskeletini kullanır;
/// oranlar her birine ayrı bir siluet verir (tombul köpek, ince kedi, uzun beyefendi, iri kafalı çocuk).
struct CharacterStyle {
    var body: SKColor
    var head: SKColor
    var face: SKColor
    var shoes: SKColor
    var gloves: SKColor
    var accent: SKColor
    var accessory: Accessory
    var tail: Tail = .none
    var bodyWidth: CGFloat = 22
    var bodyHeight: CGFloat = 21
    var headScale: CGFloat = 1
    /// Gövdede iki düğme (ceket).
    var buttons = false
    /// Boyunda papyon.
    var bowTie = false
    var alpha: CGFloat = 1

    /// Dirilişte yukarı süzülen hayalet.
    static let ghost = CharacterStyle(
        body: SKColor(white: 0.97, alpha: 1), head: SKColor(white: 0.97, alpha: 1), face: .white,
        shoes: SKColor(white: 0.9, alpha: 1), gloves: .white, accent: SKColor(white: 0.9, alpha: 1),
        accessory: .none, alpha: 0.75
    )
}

/// Kupalarla açılan 5 özgün karakter. Gerçek parayla satın alma yoktur; para birimi kazanılan kupalardır.
enum GameCharacter: Int, CaseIterable, Identifiable {
    case tipi = 0
    case fistik
    case mirnav
    case beyefendi
    case pervane

    var id: Int { rawValue }

    /// Açmak için gereken kupa sayısı.
    var price: Int {
        switch self {
        case .tipi: return 0
        case .fistik: return 1
        case .mirnav: return 2
        case .beyefendi: return 3
        case .pervane: return 5
        }
    }

    var name: String {
        switch self {
        case .tipi: return String(localized: "character.tipi")
        case .fistik: return String(localized: "character.fistik")
        case .mirnav: return String(localized: "character.mirnav")
        case .beyefendi: return String(localized: "character.beyefendi")
        case .pervane: return String(localized: "character.pervane")
        }
    }

    var style: CharacterStyle {
        let ink = Palette.ink
        let skin = SKColor(red: 0.99, green: 0.86, blue: 0.70, alpha: 1)
        switch self {
        case .tipi:
            // Gökdelenin komisi: kırmızı ceket, yuvarlak şapka, pirinç düğmeler.
            return CharacterStyle(body: SKColor(red: 0.78, green: 0.17, blue: 0.14, alpha: 1), head: skin, face: skin,
                                  shoes: ink, gloves: .white, accent: SKColor(red: 0.78, green: 0.17, blue: 0.14, alpha: 1),
                                  accessory: .bellhop, buttons: true)
        case .fistik:
            let brown = SKColor(red: 0.62, green: 0.40, blue: 0.24, alpha: 1)
            return CharacterStyle(body: brown, head: brown, face: Palette.cream, shoes: ink, gloves: .white,
                                  accent: SKColor(red: 0.33, green: 0.20, blue: 0.12, alpha: 1), accessory: .dogEars,
                                  tail: .dog, bodyWidth: 26, bodyHeight: 22, headScale: 1.04)
        case .mirnav:
            let grey = SKColor(red: 0.47, green: 0.47, blue: 0.53, alpha: 1)
            return CharacterStyle(body: grey, head: grey, face: Palette.cream, shoes: ink, gloves: .white,
                                  accent: grey, accessory: .catEars, tail: .cat, bodyWidth: 18, bodyHeight: 21)
        case .beyefendi:
            return CharacterStyle(body: SKColor(red: 0.18, green: 0.20, blue: 0.36, alpha: 1), head: skin, face: skin,
                                  shoes: ink, gloves: .white, accent: SKColor(red: 0.72, green: 0.14, blue: 0.12, alpha: 1),
                                  accessory: .topHat, bodyWidth: 20, bodyHeight: 24, headScale: 0.95, buttons: true, bowTie: true)
        case .pervane:
            return CharacterStyle(body: SKColor(red: 0.20, green: 0.50, blue: 0.34, alpha: 1), head: skin, face: skin,
                                  shoes: SKColor(red: 0.45, green: 0.22, blue: 0.12, alpha: 1), gloves: .white,
                                  accent: SKColor(red: 0.88, green: 0.22, blue: 0.16, alpha: 1), accessory: .propeller,
                                  bodyWidth: 21, bodyHeight: 19, headScale: 1.14)
        }
    }

    /// "0,2,3" biçimindeki kayıttan açık karakterler. Tıpı her zaman açıktır.
    static func unlocked(from stored: String) -> Set<GameCharacter> {
        var result: Set<GameCharacter> = [.tipi]
        for part in stored.split(separator: ",") {
            if let raw = Int(part), let character = GameCharacter(rawValue: raw) {
                result.insert(character)
            }
        }
        return result
    }

    static func store(_ characters: Set<GameCharacter>) -> String {
        characters.map(\.rawValue).sorted().map(String.init).joined(separator: ",")
    }
}
