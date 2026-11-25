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
}

/// Bir kattaki kiriş. `y`, üst yüzeyin yüksekliğidir (oyuncunun ayakları buraya basar).
public struct Platform: Equatable, Sendable {
    public let floor: Int
    public let minX: Double
    public let maxX: Double
    public let y: Double
    public let isMilestone: Bool

    public init(floor: Int, minX: Double, maxX: Double, y: Double, isMilestone: Bool) {
        self.floor = floor
        self.minX = minX
        self.maxX = maxX
        self.y = y
        self.isMilestone = isMilestone
    }

    public var width: Double { maxX - minX }
    public var centerX: Double { (minX + maxX) / 2 }
}

/// Katları sırayla ve adil şekilde üretir: kirişler yukarı çıktıkça daralır,
/// iki ardışık kiriş arasındaki yatay kayma `platformMaxShift`'i asla geçmez.
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
        let width = max(config.platformMinWidth, config.platformStartWidth - Double(floor) * config.platformShrinkPerFloor)
        let previousCenter = platforms[floor - 1].centerX
        let shift = (rng.nextUnit() * 2 - 1) * config.platformMaxShift
        let minCenter = config.playMinX + width / 2
        let maxCenter = config.playMaxX - width / 2
        let center = min(max(previousCenter + shift, minCenter), maxCenter)
        return Platform(floor: floor, minX: center - width / 2, maxX: center + width / 2, y: y, isMilestone: false)
    }
}
