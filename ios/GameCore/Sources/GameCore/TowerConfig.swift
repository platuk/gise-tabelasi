import Foundation

/// Oyunun tüm ayar değerleri. Birimler: nokta (pt), saniye.
/// Dünya genişliği sabittir (360 pt); ekran ne olursa olsun aynı oynanış.
public struct TowerConfig: Equatable, Sendable {
    // Dünya
    public var worldWidth: Double = 360
    public var wallThickness: Double = 18
    public var floorSpacing: Double = 80

    // Oyuncu
    public var playerWidth: Double = 26
    public var playerHeight: Double = 44
    public var gravity: Double = 2400
    public var groundAcceleration: Double = 1700
    public var airAcceleration: Double = 1100
    public var groundFriction: Double = 1900
    public var maxRunSpeed: Double = 540
    public var baseJumpVelocity: Double = 860
    /// Koşu hızının zıplamaya eklenen payı: hızlı koşan daha yükseğe zıplar.
    public var jumpSpeedBonus: Double = 0.85
    public var wallBounceDamping: Double = 0.9
    /// Platformdan düştükten hemen sonra hâlâ zıplayabilme süresi.
    public var coyoteTime: Double = 0.08
    /// Yere değmeden hemen önce basılan zıplamanın hatırlanma süresi.
    public var jumpBufferTime: Double = 0.12

    // Kombo
    public var comboWindow: Double = 3.0

    // Platformlar
    public var platformStartWidth: Double = 200
    public var platformMinWidth: Double = 70
    public var platformShrinkPerFloor: Double = 0.6
    public var platformMaxShift: Double = 170
    /// Bölüm uzunluğu: her bu kadar katta bir kupa, kayıt noktası ve duvardan duvara "dinlenme" katı.
    public var milestoneInterval: Int = 100

    // Bölüm 2: kayan kirişler
    public var slidingWidthFactor: Double = 0.8
    public var slidingAmplitude: ClosedRange<Double> = 24...70
    /// Radyan/saniye.
    public var slidingSpeed: ClosedRange<Double> = 0.9...1.8

    // Bölüm 3: kaygan kirişler (çelikten ~4 kat kaygan; durabilmek için daha geniş)
    public var slipperyFriction: Double = 450
    public var slipperyAcceleration: Double = 1000
    public var slipperyWidthFactor: Double = 1.35
    /// Ekranda kart gösterilen kat aralığı.
    public var cardInterval: Int = 25

    // Yanan film
    public var burnStartFloor: Int = 5
    public var burnStartDistance: Double = 420
    public var burnBaseSpeed: Double = 38
    public var burnAcceleration: Double = 1.5
    public var burnMaxSpeed: Double = 240
    /// Oyuncu çok uzaklaşırsa film bu mesafeye kadar yetişir.
    public var burnMaxLag: Double = 640

    // Gizli yardım (assist)
    /// İnişte kirişin kenarını bu kadar kaçıran oyuncu kirişe doğru çekilir.
    public var landingAssistMargin: Double = 20
    /// Çekme hızı (pt/sn); küçük tutulur ki fark edilmesin.
    public var landingAssistSpeed: Double = 150
    /// Havadayken duvara en az bu hızla çarpan oyuncu takla atıp yükselir.
    public var wallKickMinSpeed: Double = 300
    public var wallKickVelocity: Double = 1000
    /// Takladan sonra ulaşılabilecek en yüksek kirişe doğru yönlendirme ivmesi (pt/sn²).
    public var wallKickSteer: Double = 700

    // Baloncuklar
    public var bubbleChance: Double = 0.08
    public var bubbleMinFloor: Int = 8
    public var bubbleHeight: Double = 70
    public var bubbleRadius: Double = 24
    public var boostFloors: Int = 50
    public var boostDuration: Double = 2.2
    public var slowDuration: Double = 6
    public var slowFactor: Double = 0.5
    public var adrenalineDuration: Double = 8
    public var adrenalineSpeedFactor: Double = 1.35
    public var shieldDuration: Double = 10

    // Diriliş
    public var freeRespawns: Int = 1
    public var respawnShield: Double = 3

    public init() {}

    /// 0'dan başlayan bölüm numarası (0: kat 0–99, 1: kat 100–199, ...).
    public func chapter(forFloor floor: Int) -> Int {
        max(0, floor) / max(1, milestoneInterval)
    }

    public var playMinX: Double { wallThickness }
    public var playMaxX: Double { worldWidth - wallThickness }

    public func jumpVelocity(forSpeed speed: Double) -> Double {
        baseJumpVelocity + jumpSpeedBonus * min(abs(speed), maxRunSpeed)
    }

    /// Verilen koşu hızıyla zıplamanın tepe yüksekliği.
    public func jumpHeight(forSpeed speed: Double) -> Double {
        let velocity = jumpVelocity(forSpeed: speed)
        return velocity * velocity / (2 * gravity)
    }
}
