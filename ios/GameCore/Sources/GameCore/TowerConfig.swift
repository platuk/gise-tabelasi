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
    /// Her bu kadar katta bir, duvardan duvara tam genişlikte "dinlenme" katı.
    public var milestoneInterval: Int = 100
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

    public init() {}

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
