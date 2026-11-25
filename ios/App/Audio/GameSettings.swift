import Foundation

/// Oyuncu ayarları (yalnızca bu cihazda saklanır). SwiftUI tarafı aynı anahtarları @AppStorage ile kullanır.
enum GameSettings {
    static let musicVolumeKey = "musicVolume"
    static let sfxVolumeKey = "sfxVolume"
    static let hapticsKey = "hapticsOn"
    static let screenShakeKey = "screenShake"
    static let filmEffectsKey = "filmEffects"

    static func register() {
        UserDefaults.standard.register(defaults: [
            musicVolumeKey: 0.7,
            sfxVolumeKey: 0.85,
            hapticsKey: true,
            screenShakeKey: true,
            filmEffectsKey: true,
        ])
    }

    static var musicVolume: Double { UserDefaults.standard.double(forKey: musicVolumeKey) }
    static var sfxVolume: Double { UserDefaults.standard.double(forKey: sfxVolumeKey) }
    static var haptics: Bool { UserDefaults.standard.bool(forKey: hapticsKey) }
    static var screenShake: Bool { UserDefaults.standard.bool(forKey: screenShakeKey) }
    /// Film titremesi, gren ve çizikler (ışığa duyarlı oyuncular kapatabilir).
    static var filmEffects: Bool { UserDefaults.standard.bool(forKey: filmEffectsKey) }
}
