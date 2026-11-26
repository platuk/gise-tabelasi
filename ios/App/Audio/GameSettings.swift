import UIKit

/// Oyuncu ayarları (yalnızca bu cihazda saklanır). SwiftUI tarafı aynı anahtarları @AppStorage ile kullanır.
enum GameSettings {
    static let musicVolumeKey = "musicVolume"
    static let sfxVolumeKey = "sfxVolume"
    static let hapticsKey = "hapticsOn"
    static let screenShakeKey = "screenShake"
    static let filmEffectsKey = "filmEffects"

    /// Varsayılanlar. iPhone'da "Hareketi Azalt" açıksa ekran sarsıntısı ve film titremesi kapalı başlar
    /// (oyuncu Ayarlar'dan yine açabilir).
    static func register() {
        let calm = UIAccessibility.isReduceMotionEnabled
        UserDefaults.standard.register(defaults: [
            musicVolumeKey: 0.7,
            sfxVolumeKey: 0.85,
            hapticsKey: true,
            screenShakeKey: !calm,
            filmEffectsKey: !calm,
        ])
    }

    static var musicVolume: Double { UserDefaults.standard.double(forKey: musicVolumeKey) }
    static var sfxVolume: Double { UserDefaults.standard.double(forKey: sfxVolumeKey) }
    static var haptics: Bool { UserDefaults.standard.bool(forKey: hapticsKey) }
    static var screenShake: Bool { UserDefaults.standard.bool(forKey: screenShakeKey) }
    /// Film titremesi, gren ve çizikler (ışığa duyarlı oyuncular kapatabilir).
    static var filmEffects: Bool { UserDefaults.standard.bool(forKey: filmEffectsKey) }
}
