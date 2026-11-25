import SpriteKit

/// Karakterin baş süsü.
enum Accessory {
    case none
    case dogEars
    case catEars
    case topHat
    case propeller
}

/// Bir karakterin renkleri ve süsü. Hepsi aynı lastik hortum iskeletini kullanır.
struct CharacterStyle {
    var body: SKColor
    var face: SKColor
    var shoes: SKColor
    var gloves: SKColor
    var accent: SKColor
    var accessory: Accessory
    var alpha: CGFloat = 1

    /// Dirilişte yukarı süzülen hayalet.
    static let ghost = CharacterStyle(
        body: SKColor(white: 0.97, alpha: 1), face: .white, shoes: SKColor(white: 0.9, alpha: 1),
        gloves: .white, accent: SKColor(white: 0.9, alpha: 1), accessory: .none, alpha: 0.75
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
        switch self {
        case .tipi:
            return CharacterStyle(body: ink, face: Palette.cream, shoes: ink, gloves: .white, accent: ink, accessory: .none)
        case .fistik:
            return CharacterStyle(body: SKColor(red: 0.50, green: 0.31, blue: 0.19, alpha: 1), face: Palette.cream, shoes: ink,
                                  gloves: .white, accent: SKColor(red: 0.30, green: 0.18, blue: 0.11, alpha: 1), accessory: .dogEars)
        case .mirnav:
            return CharacterStyle(body: SKColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1), face: Palette.cream, shoes: ink,
                                  gloves: .white, accent: SKColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1), accessory: .catEars)
        case .beyefendi:
            return CharacterStyle(body: SKColor(red: 0.18, green: 0.20, blue: 0.36, alpha: 1), face: Palette.cream, shoes: ink,
                                  gloves: .white, accent: SKColor(red: 0.72, green: 0.14, blue: 0.12, alpha: 1), accessory: .topHat)
        case .pervane:
            return CharacterStyle(body: SKColor(red: 0.20, green: 0.42, blue: 0.30, alpha: 1), face: Palette.cream, shoes: ink,
                                  gloves: .white, accent: SKColor(red: 0.85, green: 0.20, blue: 0.16, alpha: 1), accessory: .propeller)
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
