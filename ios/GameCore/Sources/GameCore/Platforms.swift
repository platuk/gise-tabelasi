import Foundation

/// Küçük, hızlı ve her platformda aynı sonucu veren rastgele sayı üreteci.
/// Aynı tohum (seed) her zaman aynı kuleyi üretir; testler bu sayede tekrarlanabilir.
public struct SplitMix64: Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// [0, 1) aralığında sayı.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    public mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }
}

/// Kirişlerin üstünde süzülen sürpriz baloncuklar.
public enum PowerUp: String, CaseIterable, Equatable, Sendable {
    /// 50 kat yukarı uçuş.
    case boost
    /// Dünya bir süre yavaşlar.
    case slowTime
    /// Bir süre daha hızlı koşu, daha yüksek zıplama.
    case adrenaline
    /// Bir süre yanan film yakamaz.
    case shield
}

public enum PlatformKind: Equatable, Sendable {
    /// Sabit çelik kiriş.
    case steel
    /// Sağa sola kayan kiriş: konum = merkez + genlik · sin(faz + hız · zaman).
    case sliding(amplitude: Double, speed: Double, phase: Double)
    /// Kaygan kiriş: sürtünme ve ivme düşük.
    case slippery
}

/// Bir kattaki kiriş. `y`, üst yüzeyin yüksekliğidir (oyuncunun ayakları buraya basar).
/// `minX`/`maxX` kirişin taban konumudur; kayan kirişlerde anlık konum için `bounds(at:)`.
public struct Platform: Equatable, Sendable {
    public let floor: Int
    public let minX: Double
    public let maxX: Double
    public let y: Double
    public let isMilestone: Bool
    public let kind: PlatformKind
    /// Kirişin üstünde (taban merkezinde, `bubbleHeight` yukarıda) süzülen baloncuk.
    public let bubble: PowerUp?

    public init(floor: Int, minX: Double, maxX: Double, y: Double, isMilestone: Bool,
                kind: PlatformKind = .steel, bubble: PowerUp? = nil) {
        self.floor = floor
        self.minX = minX
        self.maxX = maxX
        self.y = y
        self.isMilestone = isMilestone
        self.kind = kind
        self.bubble = bubble
    }

    public var width: Double { maxX - minX }
    public var centerX: Double { (minX + maxX) / 2 }
    public var isSlippery: Bool { kind == .slippery }

    public var amplitude: Double {
        if case let .sliding(amplitude, _, _) = kind { return amplitude }
        return 0
    }

    public func offset(at time: Double) -> Double {
        if case let .sliding(amplitude, speed, phase) = kind {
            return amplitude * sin(phase + speed * time)
        }
        return 0
    }

    public func bounds(at time: Double) -> (minX: Double, maxX: Double) {
        let offset = offset(at: time)
        return (minX + offset, maxX + offset)
    }
}

/// Katları sırayla ve adil şekilde üretir. Her 100 katta bir bölüm değişir:
/// 0: çelik, 1: kısa ve kayan, 2: kaygan, 3+: karışık. Kirişler yukarı çıktıkça daralır;
/// ardışık iki kirişin taban merkezleri arasındaki fark `platformMaxShift + slidingAmplitude.upperBound`'u geçmez.
public struct PlatformGenerator: Sendable {
    public let config: TowerConfig
    private var rng: SplitMix64
    private var platforms: [Platform] = []

    public init(config: TowerConfig, seed: UInt64) {
        self.config = config
        self.rng = SplitMix64(seed: seed)
    }

    public mutating func platform(floor: Int) -> Platform {
        let floor = max(0, floor)
        while platforms.count <= floor {
            platforms.append(makeNext())
        }
        return platforms[floor]
    }

    private mutating func makeNext() -> Platform {
        let floor = platforms.count
        let y = Double(floor) * config.floorSpacing
        if floor == 0 || floor % config.milestoneInterval == 0 {
            return Platform(floor: floor, minX: config.playMinX, maxX: config.playMaxX, y: y, isMilestone: floor != 0)
        }

        // Her kat aynı sayıda rastgele sayı tüketir; böylece bir bölümdeki değişiklik diğerlerini kaydırmaz.
        let shift = (rng.nextUnit() * 2 - 1) * config.platformMaxShift
        let kindRoll = rng.nextUnit()
        let amplitudeRoll = rng.next(in: config.slidingAmplitude)
        let speedRoll = rng.next(in: config.slidingSpeed)
        let phaseRoll = rng.nextUnit() * 2 * .pi
        let bubbleRoll = rng.nextUnit()
        let bubbleKindRoll = rng.nextUnit()

        var width = max(config.platformMinWidth, config.platformStartWidth - Double(floor) * config.platformShrinkPerFloor)
        let isSliding: Bool
        let isSlippery: Bool
        switch config.chapter(forFloor: floor) {
        case 0:
            isSliding = false
            isSlippery = false
        case 1:
            isSliding = true
            isSlippery = false
        case 2:
            isSliding = false
            isSlippery = true
        default:
            isSliding = kindRoll < 1.0 / 3.0
            isSlippery = kindRoll >= 2.0 / 3.0
        }

        var amplitude = 0.0
        if isSlippery {
            let playWidth = config.playMaxX - config.playMinX
            width = min(playWidth * 0.6, width * config.slipperyWidthFactor)
        }
        if isSliding {
            width = max(config.platformMinWidth, width * config.slidingWidthFactor)
            let playWidth = config.playMaxX - config.playMinX
            amplitude = min(amplitudeRoll, max(0, (playWidth - width) / 2))
        }

        let previousCenter = platforms[floor - 1].centerX
        let minCenter = config.playMinX + width / 2 + amplitude
        let maxCenter = config.playMaxX - width / 2 - amplitude
        let center = min(max(previousCenter + shift, minCenter), maxCenter)

        let kind: PlatformKind
        if isSliding {
            kind = .sliding(amplitude: amplitude, speed: speedRoll, phase: phaseRoll)
        } else if isSlippery {
            kind = .slippery
        } else {
            kind = .steel
        }

        // Baloncuk: roket nadir, diğerleri daha sık.
        var bubble: PowerUp?
        if floor >= config.bubbleMinFloor && bubbleRoll < config.bubbleChance {
            switch bubbleKindRoll {
            case ..<0.15: bubble = .boost
            case ..<0.45: bubble = .slowTime
            case ..<0.75: bubble = .adrenaline
            default: bubble = .shield
            }
        }
        return Platform(floor: floor, minX: center - width / 2, maxX: center + width / 2, y: y, isMilestone: false,
                        kind: kind, bubble: bubble)
    }
}
