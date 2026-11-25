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
    public var platformMinWidth: Double = 80
    /// Kirişler her bölümün başında geniş başlar, bölüm boyunca daralır.
    public var platformShrinkPerFloor: Double = 0.11
    public var platformMaxShift: Double = 170
    /// Her bu kadar katta bir kupa, kayıt noktası ve duvardan duvara "dinlenme" katı.
    public var milestoneInterval: Int = 100
    /// Bölüm uzunluğu: kiriş türü bu aralıkla değişir ve her bölüm sonunda boss dövüşü vardır.
    public var chapterLength: Int = 1000

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

    // Tempo: oyun sakin başlar, katlar ve bölümler ilerledikçe hızlanır (dünya zamanı çarpanı).
    public var paceStart: Double = 0.8
    /// Her kat için tempo artışı (kat 800'de normal hıza ulaşır).
    public var pacePerFloor: Double = 0.00025
    public var paceMax: Double = 1.12

    // Yanan film (yavaş başlar; azami hızı bölümle artar)
    public var burnStartFloor: Int = 5
    public var burnStartDistance: Double = 420
    public var burnBaseSpeed: Double = 28
    public var burnAcceleration: Double = 0.8
    public var burnMaxSpeed: Double = 150
    public var burnMaxSpeedPerChapter: Double = 35
    public var burnMaxSpeedCap: Double = 260
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
    /// Yere basmadan arka arkaya en fazla bu kadar duvar taklası; sonrasında duvar yalnızca seker.
    public var maxWallKicks: Int = 10

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

    // Boss dövüşü (her bölüm sonunda)
    public var bossBaseHP: Int = 70
    public var bossHPPerChapter: Int = 25
    /// Boss'un arena zemininden yüksekliği.
    public var bossHeight: Double = 470
    public var bossSway: Double = 110
    public var bossHitRadius: Double = 62
    public var playerMaxHP: Int = 3
    /// Vurulduktan sonra dokunulmazlık süresi.
    public var hurtInvulnerability: Double = 1.4
    /// Oyuncu otomatik ateş eder.
    public var fireInterval: Double = 0.22
    public var bulletSpeed: Double = 760
    public var attackInterval: Double = 2.4
    /// Saldırıdan önceki uyarı süresi (ahtapot kollarını kaldırır).
    public var telegraphTime: Double = 0.75
    public var bossDefeatBonus: Int = 500

    public init() {}

    /// 0'dan başlayan bölüm numarası (0: kat 0–999, 1: kat 1000–1999, ...).
    public func chapter(forFloor floor: Int) -> Int {
        max(0, floor) / max(1, chapterLength)
    }

    /// Oyunun temposu (dünya zamanı çarpanı): kat 0'da 0.8, kat 800'de 1.0, en çok 1.12.
    public func pace(forFloor floor: Int) -> Double {
        min(paceMax, paceStart + pacePerFloor * Double(max(0, floor)))
    }

    /// Yanan filmin bu bölümdeki azami hızı.
    public func burnSpeedLimit(forFloor floor: Int) -> Double {
        min(burnMaxSpeedCap, burnMaxSpeed + burnMaxSpeedPerChapter * Double(chapter(forFloor: floor)))
    }

    /// Bu kat bir boss arenası mı (1000, 2000, ...).
    public func isBossFloor(_ floor: Int) -> Bool {
        floor > 0 && floor % max(1, chapterLength) == 0
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
