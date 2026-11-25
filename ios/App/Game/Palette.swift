import SpriteKit
import GameCore

/// 1930'lar film afişi paleti. Her şey bu renklerle çizilir; ayrıca renk filtresine gerek kalmaz.
enum Palette {
    static let paper = SKColor(red: 0.95, green: 0.89, blue: 0.75, alpha: 1)
    static let cream = SKColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1)
    static let ink = SKColor(red: 0.12, green: 0.09, blue: 0.07, alpha: 1)
    static let beam = SKColor(red: 0.78, green: 0.33, blue: 0.22, alpha: 1)
    static let milestone = SKColor(red: 0.98, green: 0.80, blue: 0.32, alpha: 1)
    static let slidingBeam = SKColor(red: 0.27, green: 0.50, blue: 0.53, alpha: 1)
    static let slipperyBeam = SKColor(red: 0.74, green: 0.87, blue: 0.93, alpha: 1)
    static let brick = SKColor(red: 0.52, green: 0.25, blue: 0.18, alpha: 1)
    static let flame = SKColor(red: 1.00, green: 0.52, blue: 0.14, alpha: 1)
    static let flameCore = SKColor(red: 1.00, green: 0.88, blue: 0.46, alpha: 1)
    static let charred = SKColor(red: 0.16, green: 0.10, blue: 0.07, alpha: 1)

    /// Yükseldikçe gökyüzü öğleden akşama, akşamdan geceye döner.
    static func sky(forHeight height: Double) -> SKColor {
        let stops: [(Double, (CGFloat, CGFloat, CGFloat))] = [
            (0, (0.95, 0.89, 0.75)),
            (8_000, (0.96, 0.79, 0.56)),
            (24_000, (0.62, 0.48, 0.50)),
            (48_000, (0.22, 0.21, 0.29)),
        ]
        guard height > stops[0].0 else { return paper }
        for index in 1..<stops.count where height < stops[index].0 {
            let (h0, c0) = stops[index - 1]
            let (h1, c1) = stops[index]
            let t = CGFloat((height - h0) / (h1 - h0))
            return SKColor(
                red: c0.0 + (c1.0 - c0.0) * t,
                green: c0.1 + (c1.1 - c0.1) * t,
                blue: c0.2 + (c1.2 - c0.2) * t,
                alpha: 1
            )
        }
        let last = stops[stops.count - 1].1
        return SKColor(red: last.0, green: last.1, blue: last.2, alpha: 1)
    }
}

/// Elle çizilmiş "kaynayan çizgi" titremesi: aynı adım ve sıra için her zaman aynı küçük kayma.
func boilJitter(step: Int, index: Int, amount: CGFloat = 0.7) -> CGFloat {
    var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: step &* 7_919 &+ index &* 104_729 &+ 17))
    return CGFloat(rng.nextUnit() * 2 - 1) * amount
}

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }
}
