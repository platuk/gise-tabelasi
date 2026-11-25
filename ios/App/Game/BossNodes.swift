import SpriteKit
import GameCore

/// "Kaptan Mürekkep": 1930'lar lastik hortum tarzı özgün ahtapot boss.
/// Kaptan şapkası, çatık kaşlar, dişli ağız, 8 dalgalanan kol (emicili).
/// Saldırıdan önce kollarını kaldırır ve parlar (uyarı); vurulunca beyaz yanıp söner; son aşamada kızarır.
/// Orijin: başın ortası (simülasyondaki boss konumu). Çizim 12 fps'te yenilenir.
final class OctopusNode: SKNode {
    private let tentacles: [SKShapeNode] = (0..<8).map { _ in SKShapeNode() }
    private let suckers: [SKShapeNode] = (0..<8).map { _ in SKShapeNode() }
    private let mantle = SKShapeNode()
    private let spots = SKShapeNode()
    private let shine = SKShapeNode()
    private let eyes = SKShapeNode()
    private let pupils = SKShapeNode()
    private let brows = SKShapeNode()
    private let mouth = SKShapeNode()
    private let teeth = SKShapeNode()
    private let capTop = SKShapeNode()
    private let capBand = SKShapeNode()
    private let capBrim = SKShapeNode()
    private let warning = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
    private var raise: CGFloat = 0
    private var isDefeated = false

    private static let purple = SKColor(red: 0.58, green: 0.26, blue: 0.64, alpha: 1)
    private static let angry = SKColor(red: 0.80, green: 0.22, blue: 0.36, alpha: 1)
    private static let spotColor = SKColor(red: 0.78, green: 0.50, blue: 0.82, alpha: 1)

    override init() {
        super.init()
        for (tentacle, sucker) in zip(tentacles, suckers) {
            tentacle.fillColor = Self.purple
            tentacle.strokeColor = Palette.ink
            tentacle.lineWidth = 3
            tentacle.lineJoin = .round
            addChild(tentacle)
            sucker.fillColor = Palette.cream
            sucker.strokeColor = Palette.ink
            sucker.lineWidth = 1
            addChild(sucker)
        }
        mantle.path = CGPath(ellipseIn: CGRect(x: -60, y: -32, width: 120, height: 108), transform: nil)
        mantle.fillColor = Self.purple
        mantle.strokeColor = Palette.ink
        mantle.lineWidth = 4
        addChild(mantle)
        let spotPath = CGMutablePath()
        for (x, y, r) in [(-38.0, 38.0, 7.0), (-26, 58, 5), (34, 44, 8), (44, 22, 5), (18, 64, 4), (-46, 14, 4)] {
            spotPath.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        spots.path = spotPath
        spots.fillColor = Self.spotColor
        spots.strokeColor = .clear
        addChild(spots)
        shine.path = CGPath(ellipseIn: CGRect(x: -30, y: 46, width: 26, height: 14), transform: nil)
        shine.fillColor = SKColor.white.withAlphaComponent(0.5)
        shine.strokeColor = .clear
        addChild(shine)

        // Gözler: iri krem ovaller, turta gözbebekleri
        let eyePath = CGMutablePath()
        eyePath.addEllipse(in: CGRect(x: -34, y: 4, width: 28, height: 34))
        eyePath.addEllipse(in: CGRect(x: 6, y: 4, width: 28, height: 34))
        eyes.path = eyePath
        eyes.fillColor = Palette.cream
        eyes.strokeColor = Palette.ink
        eyes.lineWidth = 3
        addChild(eyes)
        pupils.fillColor = Palette.ink
        pupils.strokeColor = .clear
        addChild(pupils)
        brows.strokeColor = Palette.ink
        brows.lineWidth = 6
        brows.lineCap = .round
        addChild(brows)
        mouth.fillColor = SKColor(red: 0.30, green: 0.05, blue: 0.12, alpha: 1)
        mouth.strokeColor = Palette.ink
        mouth.lineWidth = 3
        addChild(mouth)
        teeth.fillColor = Palette.cream
        teeth.strokeColor = Palette.ink
        teeth.lineWidth = 1.5
        addChild(teeth)

        // Kaptan şapkası
        capTop.path = CGPath(roundedRect: CGRect(x: -34, y: 72, width: 68, height: 26), cornerWidth: 12, cornerHeight: 12, transform: nil)
        capTop.fillColor = Palette.cream
        capTop.strokeColor = Palette.ink
        capTop.lineWidth = 3
        addChild(capTop)
        capBand.path = CGPath(rect: CGRect(x: -34, y: 72, width: 68, height: 9), transform: nil)
        capBand.fillColor = SKColor(red: 0.16, green: 0.20, blue: 0.40, alpha: 1)
        capBand.strokeColor = Palette.ink
        capBand.lineWidth = 2
        addChild(capBand)
        capBrim.path = CGPath(ellipseIn: CGRect(x: -40, y: 64, width: 80, height: 12), transform: nil)
        capBrim.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1)
        capBrim.strokeColor = Palette.ink
        capBrim.lineWidth = 2
        addChild(capBrim)

        warning.text = "!"
        warning.fontSize = 40
        warning.fontColor = Palette.flame
        warning.position = CGPoint(x: 0, y: 108)
        warning.isHidden = true
        addChild(warning)
        tick(step: 0, telegraph: nil, phase: 1, flash: false)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    /// Saniyede 12 kez çağrılır.
    func tick(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        guard !isDefeated else { return }
        // Uyarıda kollar kalkar; değilse yavaşça iner.
        let target: CGFloat = telegraph == nil ? 0 : 1
        raise += (target - raise) * 0.5

        let body: SKColor
        if flash {
            body = SKColor(white: 0.97, alpha: 1)
        } else if telegraph != nil && step % 2 == 0 {
            body = SKColor(red: 0.86, green: 0.55, blue: 0.95, alpha: 1)
        } else {
            body = phase >= 3 ? Self.angry : Self.purple
        }
        mantle.fillColor = body
        for tentacle in tentacles { tentacle.fillColor = body }
        warning.isHidden = telegraph == nil
        warning.setScale(step % 2 == 0 ? 1.15 : 0.95)

        // Gözbebekleri hafifçe oynar; uyarıda büyür.
        let look = boilJitter(step: step, index: 50, amount: 3)
        let pupilSize: CGFloat = telegraph == nil ? 10 : 13
        let pupilPath = CGMutablePath()
        for eyeX in [CGFloat(-20), 20] {
            pupilPath.addEllipse(in: CGRect(x: eyeX - pupilSize / 2 + look, y: 12, width: pupilSize, height: pupilSize * 1.4))
        }
        pupils.path = pupilPath

        let browPath = CGMutablePath()
        let anger: CGFloat = phase >= 2 ? 8 : 4
        browPath.move(to: CGPoint(x: -36, y: 44 + anger))
        browPath.addLine(to: CGPoint(x: -8, y: 40))
        browPath.move(to: CGPoint(x: 36, y: 44 + anger))
        browPath.addLine(to: CGPoint(x: 8, y: 40))
        brows.path = browPath

        let open: CGFloat = telegraph == nil ? 8 : 16
        mouth.path = CGPath(ellipseIn: CGRect(x: -22, y: -18 - open / 2, width: 44, height: open + 8), transform: nil)
        let teethPath = CGMutablePath()
        for index in 0..<5 {
            let x = -18 + CGFloat(index) * 9
            teethPath.addLines(between: [CGPoint(x: x, y: -14 + open / 2), CGPoint(x: x + 4.5, y: -22 + open / 2), CGPoint(x: x + 9, y: -14 + open / 2)])
        }
        teeth.path = teethPath

        // Kollar: tabandan çıkan, incelen, dalgalanan şekiller.
        for (index, tentacle) in tentacles.enumerated() {
            let spread = (CGFloat(index) - 3.5) / 3.5
            let baseX = spread * 46
            let restAngle = -CGFloat.pi / 2 + spread * 0.55
            let raisedAngle = spread >= 0 ? -CGFloat.pi / 2 + 1.9 + spread * 0.4 : -CGFloat.pi / 2 - 1.9 + spread * 0.4
            let angle = restAngle + (raisedAngle - restAngle) * raise
            let (outline, dots) = tentaclePath(base: CGPoint(x: baseX, y: -20), angle: angle, length: 78,
                                               phase: CGFloat(step) * 0.9 + CGFloat(index) * 0.8,
                                               jitterIndex: index, step: step)
            tentacle.path = outline
            suckers[index].path = dots
        }
    }

    /// Tek bir kol: orta çizgi boyunca dalga, kenarlar incelerek uca kavuşur.
    private func tentaclePath(base: CGPoint, angle: CGFloat, length: CGFloat, phase: CGFloat,
                              jitterIndex: Int, step: Int) -> (CGPath, CGPath) {
        let segments = 10
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        let dots = CGMutablePath()
        for segment in 0...segments {
            let t = CGFloat(segment) / CGFloat(segments)
            let wave = sin(phase + t * 4) * 12 * t
            let along = CGPoint(x: cos(angle), y: sin(angle))
            let normal = CGPoint(x: -along.y, y: along.x)
            let center = base + along * (t * length) + normal * (wave + boilJitter(step: step, index: jitterIndex * 20 + segment, amount: 0.8))
            let width = 13 * (1 - t) + 2.5
            left.append(center + normal * width)
            right.append(center - normal * width)
            if segment % 2 == 1 && segment < segments - 1 {
                let dot = center - normal * (width * 0.45)
                dots.addEllipse(in: CGRect(x: dot.x - 2.5, y: dot.y - 2.5, width: 5, height: 5))
            }
        }
        let outline = CGMutablePath()
        outline.addLines(between: left + right.reversed())
        outline.closeSubpath()
        return (outline, dots)
    }

    /// Yenilgi: yanıp söner, döner, küçülür, mürekkep sıçrar, düşer.
    func playDefeat(in parent: SKNode) {
        isDefeated = true
        warning.isHidden = true
        var flashes: [SKAction] = []
        for index in 0..<8 {
            flashes.append(.run { [weak self] in
                self?.mantle.fillColor = index % 2 == 0 ? .white : Self.angry
            })
            flashes.append(.wait(forDuration: 1.0 / 12.0))
        }
        for index in 0..<10 {
            let splash = SKShapeNode(circleOfRadius: CGFloat(6 + index % 3 * 4))
            splash.fillColor = SKColor(red: 0.25, green: 0.10, blue: 0.30, alpha: 1)
            splash.strokeColor = Palette.ink
            splash.lineWidth = 2
            splash.position = position
            splash.zPosition = zPosition + 1
            parent.addChild(splash)
            let angle = CGFloat(index) / 10 * 2 * .pi
            splash.run(.sequence([
                .wait(forDuration: 0.6),
                .group([.moveBy(x: cos(angle) * 140, y: sin(angle) * 140 - 40, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent(),
            ]))
        }
        run(.sequence([
            .sequence(flashes),
            .group([
                .rotate(byAngle: .pi * 4, duration: 1.2),
                .scale(to: 0.2, duration: 1.2),
                .moveBy(x: 0, y: -260, duration: 1.2),
                .fadeOut(withDuration: 1.2),
            ]),
            .removeFromParent(),
        ]))
    }
}

/// Boss ve oyuncu mermileri.
final class ProjectileNode: SKNode {
    let kind: ProjectileKind
    private let main = SKShapeNode()
    private let detail = SKShapeNode()

    init(kind: ProjectileKind, radius: CGFloat) {
        self.kind = kind
        super.init()
        addChild(main)
        addChild(detail)
        switch kind {
        case .fireball:
            main.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            main.fillColor = Palette.flame
            main.strokeColor = Palette.ink
            main.lineWidth = 2.5
            detail.path = CGPath(ellipseIn: CGRect(x: -radius * 0.5, y: -radius * 0.3, width: radius, height: radius), transform: nil)
            detail.fillColor = Palette.flameCore
            detail.strokeColor = .clear
        case .ink:
            main.path = CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
            main.fillColor = SKColor(red: 0.26, green: 0.10, blue: 0.32, alpha: 1)
            main.strokeColor = Palette.ink
            main.lineWidth = 2.5
            detail.path = CGPath(ellipseIn: CGRect(x: -radius * 0.55, y: radius * 0.1, width: radius * 0.5, height: radius * 0.35), transform: nil)
            detail.fillColor = SKColor.white.withAlphaComponent(0.7)
            detail.strokeColor = .clear
        case .wave:
            let arch = CGMutablePath()
            arch.move(to: CGPoint(x: -radius * 1.6, y: -radius))
            arch.addQuadCurve(to: CGPoint(x: radius * 1.6, y: -radius), control: CGPoint(x: 0, y: radius * 2.2))
            arch.closeSubpath()
            main.path = arch
            main.fillColor = SKColor(red: 0.36, green: 0.36, blue: 0.78, alpha: 1)
            main.strokeColor = Palette.ink
            main.lineWidth = 3
            let foam = CGMutablePath()
            for dx in [CGFloat(-10), 0, 10] {
                foam.addEllipse(in: CGRect(x: dx - 5, y: radius * 0.35, width: 10, height: 8))
            }
            detail.path = foam
            detail.fillColor = Palette.cream
            detail.strokeColor = Palette.ink
            detail.lineWidth = 1.5
        case .bullet:
            main.path = CGPath(roundedRect: CGRect(x: -3.5, y: -9, width: 7, height: 18), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            main.fillColor = Palette.cream
            main.strokeColor = Palette.ink
            main.lineWidth = 2
            detail.path = CGPath(ellipseIn: CGRect(x: -7, y: -14, width: 14, height: 10), transform: nil)
            detail.fillColor = Palette.flameCore.withAlphaComponent(0.6)
            detail.strokeColor = .clear
            detail.zPosition = -1
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    /// Kesik titreşim: ateş topu ve dalga 12 fps'te nabız gibi atar.
    func tick(step: Int) {
        switch kind {
        case .fireball: setScale(step % 2 == 0 ? 1 : 1.12)
        case .wave: yScale = step % 2 == 0 ? 1 : 1.1
        default: break
        }
    }
}

/// Kalp: oyuncunun boss dövüşündeki canı.
enum HeartShape {
    static func path(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let s = size / 2
        path.move(to: CGPoint(x: 0, y: -s))
        path.addCurve(to: CGPoint(x: -s, y: s * 0.35), control1: CGPoint(x: -s * 0.4, y: -s * 0.55), control2: CGPoint(x: -s, y: -s * 0.2))
        path.addArc(center: CGPoint(x: -s * 0.5, y: s * 0.35), radius: s * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addArc(center: CGPoint(x: s * 0.5, y: s * 0.35), radius: s * 0.5, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addCurve(to: CGPoint(x: 0, y: -s), control1: CGPoint(x: s, y: -s * 0.2), control2: CGPoint(x: s * 0.4, y: -s * 0.55))
        path.closeSubpath()
        return path
    }
}
