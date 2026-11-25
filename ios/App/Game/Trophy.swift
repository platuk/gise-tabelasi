import SpriteKit
import SwiftUI

/// Her 100 katta kazanılan kupa. Kupa, ödül kupasıdır (karakter değil).
enum TrophyTier: Int, CaseIterable {
    case bronze = 1
    case silver
    case gold
    case diamond
    case legend

    static let floorsPerTrophy = 100

    /// Kupanın kazanıldığı kat (100, 200, ...) için seviye. 500 ve sonrası "Efsane".
    init?(checkpointFloor floor: Int) {
        guard floor >= TrophyTier.floorsPerTrophy else { return nil }
        self = TrophyTier(rawValue: min(floor / TrophyTier.floorsPerTrophy, TrophyTier.legend.rawValue)) ?? .legend
    }

    var name: String {
        switch self {
        case .bronze: return String(localized: "trophy.bronze")
        case .silver: return String(localized: "trophy.silver")
        case .gold: return String(localized: "trophy.gold")
        case .diamond: return String(localized: "trophy.diamond")
        case .legend: return String(localized: "trophy.legend")
        }
    }

    private var rgb: (CGFloat, CGFloat, CGFloat) {
        switch self {
        case .bronze: return (0.80, 0.50, 0.26)
        case .silver: return (0.82, 0.84, 0.87)
        case .gold: return (1.00, 0.80, 0.26)
        case .diamond: return (0.64, 0.89, 0.96)
        case .legend: return (0.86, 0.33, 0.30)
        }
    }

    var skColor: SKColor { SKColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1) }
    var color: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }

    /// Kupa silueti; birim kare içinde, y yukarı.
    static func cupPath(transform: CGAffineTransform) -> CGPath {
        let t = transform
        let path = CGMutablePath()
        // Kulplar
        path.addEllipse(in: CGRect(x: 0.03, y: 0.56, width: 0.24, height: 0.30), transform: t)
        path.addEllipse(in: CGRect(x: 0.73, y: 0.56, width: 0.24, height: 0.30), transform: t)
        // Kâse
        path.move(to: CGPoint(x: 0.16, y: 0.96), transform: t)
        path.addLine(to: CGPoint(x: 0.84, y: 0.96), transform: t)
        path.addQuadCurve(to: CGPoint(x: 0.5, y: 0.36), control: CGPoint(x: 0.84, y: 0.40), transform: t)
        path.addQuadCurve(to: CGPoint(x: 0.16, y: 0.96), control: CGPoint(x: 0.16, y: 0.40), transform: t)
        path.closeSubpath()
        // Gövde ve kaide
        path.addRect(CGRect(x: 0.44, y: 0.14, width: 0.12, height: 0.24), transform: t)
        path.addRect(CGRect(x: 0.22, y: 0.0, width: 0.56, height: 0.14), transform: t)
        return path
    }
}

/// SpriteKit kupası: merkezde, `size` boyunda.
final class TrophyNode: SKNode {
    init(tier: TrophyTier, size: CGFloat) {
        super.init()
        let transform = CGAffineTransform(a: size, b: 0, c: 0, d: size, tx: -size / 2, ty: -size / 2)
        let cup = SKShapeNode(path: TrophyTier.cupPath(transform: transform))
        cup.fillColor = tier.skColor
        cup.strokeColor = Palette.ink
        cup.lineWidth = max(1.5, size / 16)
        addChild(cup)
        let shine = SKShapeNode(rect: CGRect(x: -size * 0.2, y: size * 0.12, width: size * 0.07, height: size * 0.26), cornerRadius: size * 0.03)
        shine.fillColor = .white
        shine.strokeColor = .clear
        shine.alpha = 0.7
        addChild(shine)
    }

    required init?(coder aDecoder: NSCoder) { return nil }
}

/// SwiftUI kupa ikonu.
struct TrophyIcon: View {
    let tier: TrophyTier
    var earned = true

    var body: some View {
        ZStack {
            CupShape().fill(earned ? tier.color : Theme.ink.opacity(0.12))
            CupShape().stroke(Theme.ink.opacity(earned ? 1 : 0.35), lineWidth: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct CupShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Birim kare (y yukarı) → görünüm (y aşağı).
        let transform = CGAffineTransform(a: rect.width, b: 0, c: 0, d: -rect.height, tx: rect.minX, ty: rect.maxY)
        return Path(TrophyTier.cupPath(transform: transform))
    }
}
