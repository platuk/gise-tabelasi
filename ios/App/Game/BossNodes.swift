import CoreImage
import SpriteKit
import GameCore

/// Bütün boss çizimlerinin ortak tabanı: uyarı işareti, 12 fps çizim, yenilgi gösterisi.
/// Her boss 1930'lar lastik hortum tarzında, özgün bir karakterdir.
/// Orijin: boss'un gövde merkezi (simülasyondaki boss konumu).
class BossNode: SKNode {
    let kind: BossKind
    private let warning = SKLabelNode(fontNamed: Palette.fontName)
    private(set) var isDefeated = false
    /// Uyarıda kalkan kollar/kanatlar için yumuşatılmış 0...1 değer.
    var raise: CGFloat = 0
    private var lastX: CGFloat = 0
    /// Gidiş yönü (-1 sol, 1 sağ): sarkan gövde, kuyruk gibi parçalar ters yöne savrulur.
    private(set) var heading: CGFloat = 1

    init(kind: BossKind, warningY: CGFloat) {
        self.kind = kind
        super.init()
        warning.text = "!"
        warning.fontSize = 40
        warning.fontColor = Palette.flame
        warning.position = CGPoint(x: 0, y: warningY)
        warning.zPosition = 20
        warning.isHidden = true
        addChild(warning)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    static func make(_ kind: BossKind) -> BossNode {
        switch kind {
        case .octopus: return OctopusNode()
        case .worm: return WormNode()
        case .bat: return BatNode()
        case .alien: return AlienNode()
        case .robot: return RobotNode()
        case .bulldog: return BulldogNode()
        }
    }

    static func displayName(_ kind: BossKind) -> String {
        switch kind {
        case .octopus: return String(localized: "boss.octopus")
        case .worm: return String(localized: "boss.worm")
        case .bat: return String(localized: "boss.bat")
        case .alien: return String(localized: "boss.alien")
        case .robot: return String(localized: "boss.robot")
        case .bulldog: return String(localized: "boss.bulldog")
        }
    }

    /// Boss can çubuğunun rengi.
    static func barColor(_ kind: BossKind) -> SKColor {
        switch kind {
        case .octopus: return SKColor(red: 0.58, green: 0.26, blue: 0.64, alpha: 1)
        case .worm: return SKColor(red: 0.90, green: 0.50, blue: 0.55, alpha: 1)
        case .bat: return SKColor(red: 0.36, green: 0.24, blue: 0.44, alpha: 1)
        case .alien: return SKColor(red: 0.40, green: 0.75, blue: 0.35, alpha: 1)
        case .robot: return SKColor(red: 0.74, green: 0.46, blue: 0.28, alpha: 1)
        case .bulldog: return SKColor(red: 0.80, green: 0.64, blue: 0.44, alpha: 1)
        }
    }

    /// Saniyede 12 kez çağrılır.
    final func tick(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        guard !isDefeated else { return }
        let target: CGFloat = telegraph == nil ? 0 : 1
        raise += (target - raise) * 0.5
        let dx = position.x - lastX
        if abs(dx) > 0.5 { heading = dx > 0 ? 1 : -1 }
        lastX = position.x
        warning.isHidden = telegraph == nil
        warning.setScale(step % 2 == 0 ? 1.15 : 0.95)
        draw(step: step, telegraph: telegraph, phase: phase, flash: flash)
    }

    /// Alt sınıflar çizer.
    func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {}
    /// Yenilgide yanıp sönme: gövde beyaz/öfke rengi.
    func paintFlash(_ white: Bool) {}
    var splashColor: SKColor { Palette.ink }

    /// Yenilgi: yanıp söner, sıçrantılar saçılır, döne döne küçülüp düşer.
    func playDefeat(in parent: SKNode) {
        isDefeated = true
        warning.isHidden = true
        var flashes: [SKAction] = []
        for index in 0..<8 {
            flashes.append(.run { [weak self] in self?.paintFlash(index % 2 == 0) })
            flashes.append(.wait(forDuration: 1.0 / 12.0))
        }
        for index in 0..<12 {
            let splash = SKShapeNode(circleOfRadius: CGFloat(6 + index % 3 * 4))
            splash.fillColor = splashColor
            splash.strokeColor = Palette.ink
            splash.lineWidth = 2
            splash.position = position
            splash.zPosition = zPosition + 1
            parent.addChild(splash)
            let angle = CGFloat(index) / 12 * 2 * .pi
            splash.run(.sequence([
                .wait(forDuration: 0.6),
                .group([.moveBy(x: cos(angle) * 150, y: sin(angle) * 150 - 40, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent(),
            ]))
        }
        // Çizgi film yıldızları: başın etrafında döner.
        for index in 0..<5 {
            let star = SKLabelNode(fontNamed: Palette.fontName)
            star.text = "★"
            star.fontSize = 22
            star.fontColor = Palette.milestone
            star.zPosition = 30
            addChild(star)
            var orbit: [SKAction] = []
            for frame in 0..<16 {
                let angle = CGFloat(frame) * 0.55 + CGFloat(index) * 1.256
                orbit.append(.move(to: CGPoint(x: cos(angle) * 60, y: 70 + sin(angle) * 16), duration: 0))
                orbit.append(.wait(forDuration: 1.0 / 12.0))
            }
            star.run(.sequence(orbit))
        }
        run(.sequence([
            .sequence(flashes),
            .wait(forDuration: 0.6),
            .group([
                .rotate(byAngle: .pi * 4, duration: 1.2),
                .scale(to: 0.2, duration: 1.2),
                .moveBy(x: 0, y: -260, duration: 1.2),
                .fadeOut(withDuration: 1.2),
            ]),
            .removeFromParent(),
        ]))
    }

    // MARK: Çizim yardımcıları

    static func shape(_ fill: SKColor, _ width: CGFloat = 3) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = fill
        node.strokeColor = width > 0 ? Palette.ink : .clear
        node.lineWidth = width
        node.lineJoin = .round
        node.lineCap = .round
        return node
    }

    static func line(_ width: CGFloat = 3, color: SKColor = Palette.ink) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = .clear
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        return node
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), transform: nil)
    }

    /// İki iri göz: krem beyaz, turta kesikli göz bebekleri; bakış oyuncuya doğru (aşağı).
    static func eyes(_ centers: [CGPoint], size: CGSize, pupil: CGFloat, look: CGPoint) -> (CGPath, CGPath) {
        let whites = CGMutablePath()
        let pupils = CGMutablePath()
        for c in centers {
            whites.addEllipse(in: CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height))
            let p = c + look
            let transform = CGAffineTransform(translationX: p.x, y: p.y).scaledBy(x: pupil * 0.7, y: pupil)
            pupils.move(to: .zero, transform: transform)
            pupils.addArc(center: .zero, radius: 1, startAngle: .pi * 0.2, endAngle: .pi * 1.8, clockwise: false, transform: transform)
            pupils.closeSubpath()
        }
        return (whites, pupils)
    }
}

// MARK: - 1. Kaptan Mürekkep (ahtapot)

/// Kaptan şapkası, çatık kaşlar, dişli ağız, 8 dalgalanan emicili kol.
final class OctopusNode: BossNode {
    private let tentacles: [SKShapeNode] = (0..<8).map { _ in BossNode.shape(OctopusNode.purple) }
    private let suckers: [SKShapeNode] = (0..<8).map { _ in BossNode.shape(Palette.cream, 1) }
    private let mantle = BossNode.shape(OctopusNode.purple, 4)
    private let spots = BossNode.shape(OctopusNode.spotColor, 0)
    private let shine = BossNode.shape(SKColor.white.withAlphaComponent(0.5), 0)
    private let eyeWhites = BossNode.shape(Palette.cream)
    private let pupils = BossNode.shape(Palette.ink, 0)
    private let brows = BossNode.line(6)
    private let mouth = BossNode.shape(SKColor(red: 0.30, green: 0.05, blue: 0.12, alpha: 1))
    private let teeth = BossNode.shape(Palette.cream, 1.5)
    private let capTop = BossNode.shape(Palette.cream)
    private let capBand = BossNode.shape(SKColor(red: 0.16, green: 0.20, blue: 0.40, alpha: 1), 2)
    private let capBrim = BossNode.shape(SKColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1), 2)

    static let purple = SKColor(red: 0.58, green: 0.26, blue: 0.64, alpha: 1)
    private static let angry = SKColor(red: 0.80, green: 0.22, blue: 0.36, alpha: 1)
    private static let spotColor = SKColor(red: 0.78, green: 0.50, blue: 0.82, alpha: 1)

    init() {
        super.init(kind: .octopus, warningY: 108)
        for (tentacle, sucker) in zip(tentacles, suckers) {
            addChild(tentacle)
            addChild(sucker)
        }
        mantle.path = Self.ellipse(0, 22, 120, 108)
        let spotPath = CGMutablePath()
        for (x, y, r) in [(-38.0, 38.0, 7.0), (-26, 58, 5), (34, 44, 8), (44, 22, 5), (18, 64, 4), (-46, 14, 4)] {
            spotPath.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        spots.path = spotPath
        shine.path = Self.ellipse(-17, 53, 26, 14)
        capTop.path = CGPath(roundedRect: CGRect(x: -34, y: 72, width: 68, height: 26), cornerWidth: 12, cornerHeight: 12, transform: nil)
        capBand.path = CGPath(rect: CGRect(x: -34, y: 72, width: 68, height: 9), transform: nil)
        capBrim.path = Self.ellipse(0, 70, 80, 12)
        for node in [mantle, spots, shine, eyeWhites, pupils, brows, mouth, teeth, capTop, capBand, capBrim] { addChild(node) }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { SKColor(red: 0.25, green: 0.10, blue: 0.30, alpha: 1) }

    override func paintFlash(_ white: Bool) {
        mantle.fillColor = white ? .white : Self.angry
        for tentacle in tentacles { tentacle.fillColor = mantle.fillColor }
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
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

        let look = CGPoint(x: boilJitter(step: step, index: 50, amount: 3), y: -3)
        let (whites, pupilPath) = Self.eyes([CGPoint(x: -20, y: 21), CGPoint(x: 20, y: 21)], size: CGSize(width: 28, height: 34),
                                            pupil: telegraph == nil ? 7 : 9, look: look)
        eyeWhites.path = whites
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

        for (index, tentacle) in tentacles.enumerated() {
            let spread = (CGFloat(index) - 3.5) / 3.5
            let restAngle = -CGFloat.pi / 2 + spread * 0.55
            let raisedAngle = spread >= 0 ? -CGFloat.pi / 2 + 1.9 + spread * 0.4 : -CGFloat.pi / 2 - 1.9 + spread * 0.4
            let angle = restAngle + (raisedAngle - restAngle) * raise
            let (outline, dots) = Self.tentacle(base: CGPoint(x: spread * 46, y: -20), angle: angle, length: 78,
                                                phase: CGFloat(step) * 0.9 + CGFloat(index) * 0.8, jitterIndex: index, step: step)
            tentacle.path = outline
            suckers[index].path = dots
        }
    }

    /// Tek bir kol: orta çizgi boyunca dalga, kenarlar incelerek uca kavuşur.
    static func tentacle(base: CGPoint, angle: CGFloat, length: CGFloat, phase: CGFloat, jitterIndex: Int, step: Int) -> (CGPath, CGPath) {
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
}

// MARK: - 2. Profesör Kıvrım (solucan)

/// Kep, tek gözlük, kıvrık bıyık. Halkalı gövdesi havada kıvrılarak başının arkasından gelir.
final class WormNode: BossNode {
    private let segments: [SKShapeNode] = (0..<8).map { _ in BossNode.shape(WormNode.pink, 2.5) }
    private let rings: [SKShapeNode] = (0..<8).map { _ in BossNode.line(2, color: WormNode.stripe) }
    private let head = BossNode.shape(WormNode.pink, 4)
    private let cheeks = BossNode.shape(SKColor(red: 0.96, green: 0.42, blue: 0.48, alpha: 0.7), 0)
    private let eyeWhites = BossNode.shape(Palette.cream)
    private let pupils = BossNode.shape(Palette.ink, 0)
    private let monocle = BossNode.line(3, color: Palette.milestone)
    private let brows = BossNode.line(5)
    private let nose = BossNode.shape(SKColor(red: 0.85, green: 0.38, blue: 0.45, alpha: 1), 2.5)
    private let mustache = BossNode.shape(SKColor(red: 0.35, green: 0.22, blue: 0.16, alpha: 1), 2)
    private let mouth = BossNode.shape(SKColor(red: 0.30, green: 0.05, blue: 0.12, alpha: 1))
    private let teeth = BossNode.shape(Palette.cream, 1.5)
    private let capBoard = BossNode.shape(Palette.ink, 2)
    private let capBase = BossNode.shape(Palette.ink, 2)
    private let tassel = BossNode.line(3, color: Palette.milestone)

    static let pink = SKColor(red: 0.95, green: 0.60, blue: 0.62, alpha: 1)
    private static let stripe = SKColor(red: 0.78, green: 0.38, blue: 0.44, alpha: 1)
    private static let angry = SKColor(red: 0.90, green: 0.30, blue: 0.30, alpha: 1)

    init() {
        super.init(kind: .worm, warningY: 118)
        for (segment, ring) in zip(segments, rings).reversed() {
            addChild(segment)
            addChild(ring)
        }
        head.path = Self.ellipse(0, 0, 108, 100)
        cheeks.path = {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: -44, y: -22, width: 18, height: 12))
            path.addEllipse(in: CGRect(x: 28, y: -22, width: 18, height: 12))
            return path
        }()
        capBase.path = CGPath(rect: CGRect(x: -26, y: 42, width: 52, height: 16), transform: nil)
        let board = CGMutablePath()
        board.addLines(between: [CGPoint(x: -52, y: 60), CGPoint(x: 0, y: 74), CGPoint(x: 52, y: 60), CGPoint(x: 0, y: 48)])
        board.closeSubpath()
        capBoard.path = board
        for node in [head, cheeks, eyeWhites, pupils, monocle, brows, nose, mustache, mouth, teeth, capBase, capBoard, tassel] {
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { SKColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1) }

    override func paintFlash(_ white: Bool) {
        head.fillColor = white ? .white : Self.angry
        for segment in segments { segment.fillColor = head.fillColor }
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        let color = flash ? SKColor(white: 0.97, alpha: 1) : (telegraph != nil && step % 2 == 0 ? Palette.milestone : (phase >= 3 ? Self.angry : Self.pink))
        head.fillColor = color
        // Gövde: başın arkasından, gidiş yönünün tersine kıvrılarak sarkar; uyarıda büzülür (yay gibi).
        let squeeze = 1 - raise * 0.35
        for (index, segment) in segments.enumerated() {
            let t = CGFloat(index + 1)
            let wave = sin(CGFloat(step) * 0.8 - t * 0.9)
            let center = CGPoint(x: -heading * t * 15 * squeeze + wave * 7, y: -18 - t * 11 * squeeze + cos(CGFloat(step) * 0.8 - t) * 5)
            let radius = 34 - t * 2.6
            segment.fillColor = color
            segment.path = Self.ellipse(center.x, center.y, radius * 2, radius * 1.8)
            let ring = CGMutablePath()
            ring.move(to: center + CGPoint(x: -radius * 0.5, y: radius * 0.75))
            ring.addQuadCurve(to: center + CGPoint(x: -radius * 0.5, y: -radius * 0.75), control: center + CGPoint(x: -radius * 0.15, y: 0))
            rings[index].path = ring
        }

        let look = CGPoint(x: boilJitter(step: step, index: 70, amount: 2.5), y: -4)
        let (whites, pupilPath) = Self.eyes([CGPoint(x: -19, y: 12), CGPoint(x: 19, y: 14)], size: CGSize(width: 26, height: 32),
                                            pupil: telegraph == nil ? 7 : 9, look: look)
        eyeWhites.path = whites
        pupils.path = pupilPath
        let mono = CGMutablePath()
        mono.addEllipse(in: CGRect(x: 4, y: -3, width: 30, height: 34))
        mono.move(to: CGPoint(x: 34, y: 8))
        mono.addQuadCurve(to: CGPoint(x: 46, y: -30), control: CGPoint(x: 52, y: -6))
        monocle.path = mono
        let browPath = CGMutablePath()
        let lift: CGFloat = telegraph == nil ? 0 : 5
        browPath.move(to: CGPoint(x: -32, y: 32 + lift))
        browPath.addLine(to: CGPoint(x: -8, y: 28 + (phase >= 2 ? -3 : 2)))
        browPath.move(to: CGPoint(x: 32, y: 36 + lift))
        browPath.addLine(to: CGPoint(x: 8, y: 30 + (phase >= 2 ? -3 : 2)))
        brows.path = browPath
        nose.path = Self.ellipse(0, -6, 20, 15)
        // Kıvrık bıyık, uçları her karede biraz oynar.
        let curl = boilJitter(step: step, index: 71, amount: 2)
        let stache = CGMutablePath()
        stache.move(to: CGPoint(x: 0, y: -12))
        stache.addCurve(to: CGPoint(x: -34, y: -10 + curl), control1: CGPoint(x: -12, y: -24), control2: CGPoint(x: -28, y: -24))
        stache.addQuadCurve(to: CGPoint(x: 0, y: -15), control: CGPoint(x: -18, y: -16))
        stache.addQuadCurve(to: CGPoint(x: 34, y: -10 - curl), control: CGPoint(x: 18, y: -16))
        stache.addCurve(to: CGPoint(x: 0, y: -12), control1: CGPoint(x: 28, y: -24), control2: CGPoint(x: 12, y: -24))
        mustache.path = stache
        let open: CGFloat = telegraph == nil ? 4 : 16
        mouth.path = Self.ellipse(0, -30 - open / 3, 34, 8 + open)
        let teethPath = CGMutablePath()
        if telegraph != nil {
            for index in 0..<4 {
                let x = -13 + CGFloat(index) * 7
                teethPath.addRect(CGRect(x: x, y: -26 - open / 3 + open / 2 - 5, width: 6, height: 5))
            }
        }
        teeth.path = teethPath
        let swing = boilJitter(step: step, index: 72, amount: 4) - heading * 4
        let tasselPath = CGMutablePath()
        tasselPath.move(to: CGPoint(x: 0, y: 62))
        tasselPath.addLine(to: CGPoint(x: 40, y: 58))
        tasselPath.addLine(to: CGPoint(x: 42 + swing, y: 36))
        tassel.path = tasselPath
    }
}

// MARK: - 3. Kont Kanat (yarasa)

/// Kocaman kulaklar, yüksek yakalı pelerin, sivri dişler; kanatları 12 fps'te üç pozla çırpar.
final class BatNode: BossNode {
    private let cape = BossNode.shape(SKColor(red: 0.72, green: 0.12, blue: 0.16, alpha: 1))
    private let wingLeft = BossNode.shape(BatNode.wing)
    private let wingRight = BossNode.shape(BatNode.wing)
    private let bones = BossNode.line(2.5)
    private let body = BossNode.shape(BatNode.fur, 4)
    private let ears = BossNode.shape(BatNode.fur, 3)
    private let innerEars = BossNode.shape(SKColor(red: 0.85, green: 0.50, blue: 0.62, alpha: 1), 0)
    private let muzzle = BossNode.shape(SKColor(red: 0.62, green: 0.48, blue: 0.64, alpha: 1), 2.5)
    private let eyeWhites = BossNode.shape(Palette.cream)
    private let pupils = BossNode.shape(Palette.ink, 0)
    private let brows = BossNode.line(5)
    private let mouth = BossNode.shape(SKColor(red: 0.30, green: 0.05, blue: 0.12, alpha: 1))
    private let fangs = BossNode.shape(.white, 1.5)
    private let feet = BossNode.shape(BatNode.fur, 2)

    private static let fur = SKColor(red: 0.34, green: 0.24, blue: 0.40, alpha: 1)
    private static let wing = SKColor(red: 0.26, green: 0.18, blue: 0.30, alpha: 1)
    private static let angry = SKColor(red: 0.60, green: 0.16, blue: 0.30, alpha: 1)

    init() {
        super.init(kind: .bat, warningY: 120)
        let capePath = CGMutablePath()
        capePath.addLines(between: [CGPoint(x: -46, y: 10), CGPoint(x: -60, y: 62), CGPoint(x: -20, y: 36),
                                    CGPoint(x: 20, y: 36), CGPoint(x: 60, y: 62), CGPoint(x: 46, y: 10)])
        capePath.closeSubpath()
        cape.path = capePath
        let earPath = CGMutablePath()
        earPath.addLines(between: [CGPoint(x: -40, y: 22), CGPoint(x: -34, y: 86), CGPoint(x: -10, y: 36)])
        earPath.closeSubpath()
        earPath.addLines(between: [CGPoint(x: 40, y: 22), CGPoint(x: 34, y: 86), CGPoint(x: 10, y: 36)])
        earPath.closeSubpath()
        ears.path = earPath
        let inner = CGMutablePath()
        inner.addLines(between: [CGPoint(x: -33, y: 34), CGPoint(x: -31, y: 72), CGPoint(x: -17, y: 40)])
        inner.closeSubpath()
        inner.addLines(between: [CGPoint(x: 33, y: 34), CGPoint(x: 31, y: 72), CGPoint(x: 17, y: 40)])
        inner.closeSubpath()
        innerEars.path = inner
        body.path = Self.ellipse(0, 0, 92, 100)
        muzzle.path = Self.ellipse(0, -18, 54, 36)
        let feetPath = CGMutablePath()
        for side in [CGFloat(-1), 1] {
            feetPath.addEllipse(in: CGRect(x: side * 18 - 7, y: -58, width: 14, height: 12))
        }
        feet.path = feetPath
        for node in [wingLeft, wingRight, bones, cape, feet, ears, innerEars, body, muzzle, eyeWhites, pupils, brows, mouth, fangs] {
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { SKColor(red: 0.30, green: 0.18, blue: 0.34, alpha: 1) }

    override func paintFlash(_ white: Bool) {
        body.fillColor = white ? .white : Self.angry
        ears.fillColor = body.fillColor
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        let color = flash ? SKColor(white: 0.97, alpha: 1) : (phase >= 3 ? Self.angry : Self.fur)
        body.fillColor = color
        ears.fillColor = color
        // Kanat çırpma: yukarı, orta, aşağı, orta. Uyarıda kanatlar açık ve gergin.
        let flaps: [CGFloat] = [46, 6, -36, 6]
        let tipY = telegraph != nil ? 24 : flaps[step % 4]
        let reach: CGFloat = telegraph != nil ? 150 : 128
        let bonePath = CGMutablePath()
        wingLeft.path = Self.wingPath(side: -1, tipY: tipY, reach: reach, bones: bonePath)
        wingRight.path = Self.wingPath(side: 1, tipY: tipY, reach: reach, bones: bonePath)
        bones.path = bonePath

        let eyeColor = telegraph != nil ? Palette.milestone : Palette.cream
        eyeWhites.fillColor = phase >= 3 ? SKColor(red: 1, green: 0.55, blue: 0.45, alpha: 1) : eyeColor
        let look = CGPoint(x: boilJitter(step: step, index: 80, amount: 2), y: -4)
        let (whites, pupilPath) = Self.eyes([CGPoint(x: -17, y: 14), CGPoint(x: 17, y: 14)], size: CGSize(width: 22, height: 28),
                                            pupil: telegraph == nil ? 5 : 3.5, look: look)
        eyeWhites.path = whites
        pupils.path = pupilPath
        let browPath = CGMutablePath()
        browPath.move(to: CGPoint(x: -32, y: 34))
        browPath.addLine(to: CGPoint(x: -6, y: 24))
        browPath.move(to: CGPoint(x: 32, y: 34))
        browPath.addLine(to: CGPoint(x: 6, y: 24))
        brows.path = browPath
        let open: CGFloat = telegraph == nil ? 6 : 16
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: -16, y: -20))
        mouthPath.addQuadCurve(to: CGPoint(x: 16, y: -20), control: CGPoint(x: 0, y: -20 - open * 1.8))
        mouthPath.closeSubpath()
        mouth.path = mouthPath
        let fangPath = CGMutablePath()
        for x in [CGFloat(-9), 9] {
            fangPath.addLines(between: [CGPoint(x: x - 4, y: -20), CGPoint(x: x, y: -31), CGPoint(x: x + 4, y: -20)])
            fangPath.closeSubpath()
        }
        fangs.path = fangPath
    }

    /// Yarasa kanadı: omuzdan uca kemik, alt kenar tarak gibi kavisli.
    private static func wingPath(side: CGFloat, tipY: CGFloat, reach: CGFloat, bones: CGMutablePath) -> CGPath {
        let shoulder = CGPoint(x: side * 36, y: 14)
        let tip = CGPoint(x: side * reach, y: tipY)
        let fingers = [
            CGPoint(x: side * reach * 0.82, y: tipY - 40),
            CGPoint(x: side * reach * 0.6, y: tipY * 0.6 - 52),
            CGPoint(x: side * 40, y: -34),
        ]
        let path = CGMutablePath()
        path.move(to: shoulder)
        path.addQuadCurve(to: tip, control: CGPoint(x: side * reach * 0.55, y: tipY + 34))
        var previous = tip
        for finger in fingers {
            let mid = (previous + finger) * 0.5
            path.addQuadCurve(to: finger, control: mid + CGPoint(x: -side * 6, y: 14))
            bones.move(to: CGPoint(x: side * reach * 0.5, y: tipY * 0.5 + 18))
            bones.addLine(to: finger)
            previous = finger
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - 4. Zorp (uçan dairedeki uzaylı)

/// Cam kubbede üç gözlü yeşil uzaylı; dairenin ışıkları sırayla yanar, uyarıda kırmızıya döner ve ışın kozu açılır.
final class AlienNode: BossNode {
    private let beam = BossNode.shape(SKColor(red: 1, green: 0.92, blue: 0.45, alpha: 0.28), 0)
    private let alienHead = BossNode.shape(AlienNode.green, 3)
    private let antenna = BossNode.line(2.5)
    private let antennaBall = BossNode.shape(Palette.flame, 2)
    private let eyeWhites = BossNode.shape(Palette.cream, 2)
    private let pupils = BossNode.shape(Palette.ink, 0)
    private let mouth = BossNode.line(2.5)
    private let dome = BossNode.shape(SKColor(red: 0.70, green: 0.88, blue: 0.95, alpha: 0.45), 3)
    private let domeShine = BossNode.shape(SKColor.white.withAlphaComponent(0.6), 0)
    private let saucer = BossNode.shape(AlienNode.metal, 4)
    private let rim = BossNode.shape(SKColor(red: 0.48, green: 0.50, blue: 0.56, alpha: 1), 2.5)
    private let lights = BossNode.shape(Palette.milestone, 1.5)
    private let underside = BossNode.shape(SKColor(red: 0.40, green: 0.42, blue: 0.48, alpha: 1), 2.5)

    private static let green = SKColor(red: 0.50, green: 0.82, blue: 0.40, alpha: 1)
    private static let metal = SKColor(red: 0.74, green: 0.76, blue: 0.80, alpha: 1)

    init() {
        super.init(kind: .alien, warningY: 104)
        dome.path = Self.ellipse(0, 26, 78, 70)
        domeShine.path = Self.ellipse(-18, 42, 16, 10)
        saucer.path = Self.ellipse(0, -2, 168, 44)
        rim.path = Self.ellipse(0, -6, 168, 14)
        underside.path = Self.ellipse(0, -22, 66, 18)
        for node in [beam, antenna, antennaBall, alienHead, eyeWhites, pupils, mouth, dome, domeShine, underside, saucer, rim, lights] {
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { Self.green }

    override func paintFlash(_ white: Bool) {
        saucer.fillColor = white ? .white : Palette.flame
        alienHead.fillColor = white ? .white : Self.green
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        saucer.fillColor = flash ? .white : (phase >= 3 ? SKColor(red: 0.85, green: 0.62, blue: 0.58, alpha: 1) : Self.metal)
        alienHead.fillColor = flash ? .white : Self.green
        // Işın kozu: yalnızca uyarıda, titreyerek.
        if telegraph != nil {
            let width: CGFloat = 26 + (step % 2 == 0 ? 6 : 0)
            let cone = CGMutablePath()
            cone.addLines(between: [CGPoint(x: -24, y: -24), CGPoint(x: 24, y: -24), CGPoint(x: width * 2.5, y: -420), CGPoint(x: -width * 2.5, y: -420)])
            cone.closeSubpath()
            beam.path = cone
        } else {
            beam.path = nil
        }
        let bob = CGFloat(step % 4 < 2 ? 1 : 0)
        alienHead.path = Self.ellipse(0, 22 + bob, 40, 42)
        let antennaPath = CGMutablePath()
        let sway = boilJitter(step: step, index: 90, amount: 3)
        antennaPath.move(to: CGPoint(x: 0, y: 42 + bob))
        antennaPath.addQuadCurve(to: CGPoint(x: 6 + sway, y: 70), control: CGPoint(x: -6, y: 56))
        antenna.path = antennaPath
        antennaBall.path = Self.ellipse(6 + sway, 72, 9, 9)
        antennaBall.fillColor = step % 2 == 0 ? Palette.flame : Palette.milestone
        let blink = step % 23 == 0
        let look = CGPoint(x: boilJitter(step: step, index: 91, amount: 1.5), y: -2)
        let centers = [CGPoint(x: -10, y: 28 + bob), CGPoint(x: 10, y: 28 + bob), CGPoint(x: 0, y: 38 + bob)]
        let (whites, pupilPath) = Self.eyes(centers, size: CGSize(width: 11, height: blink ? 2 : 13), pupil: blink ? 0.5 : 3.5, look: look)
        eyeWhites.path = whites
        pupils.path = pupilPath
        let grin = CGMutablePath()
        grin.move(to: CGPoint(x: -9, y: 14 + bob))
        grin.addQuadCurve(to: CGPoint(x: 9, y: 14 + bob), control: CGPoint(x: 0, y: telegraph == nil ? 8 + bob : 20 + bob))
        mouth.path = grin
        // Kenar ışıkları sırayla yanar; uyarıda hepsi kırmızı yanıp söner.
        let lightPath = CGMutablePath()
        for index in 0..<7 {
            let x = -66 + CGFloat(index) * 22
            let on = telegraph != nil ? step % 2 == 0 : (index + step) % 3 == 0
            let r: CGFloat = on ? 6 : 3.5
            lightPath.addEllipse(in: CGRect(x: x - r, y: -6 - r, width: r * 2, height: r * 2))
        }
        lights.path = lightPath
        lights.fillColor = telegraph != nil ? SKColor(red: 0.95, green: 0.25, blue: 0.20, alpha: 1) : Palette.milestone
    }
}

// MARK: - 5. Paslı Perçin (robot)

/// Perçinli paslı kazan gövde, ampul gözler, ızgara ağız, anten kıvılcımları, alttan jet alevi.
final class RobotNode: BossNode {
    private let flames = BossNode.shape(Palette.flame, 2)
    private let flameCore = BossNode.shape(Palette.flameCore, 0)
    private let arms = BossNode.line(9, color: RobotNode.dark)
    private let armOutline = BossNode.line(13)
    private let claws = BossNode.line(5)
    private let body = BossNode.shape(RobotNode.rust, 4)
    private let rustPatches = BossNode.shape(RobotNode.dark.withAlphaComponent(0.55), 0)
    private let rivets = BossNode.shape(RobotNode.dark, 0)
    private let dial = BossNode.shape(Palette.cream, 2.5)
    private let needle = BossNode.line(2.5, color: SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1))
    private let head = BossNode.shape(RobotNode.rust, 4)
    private let eyes = BossNode.shape(Palette.milestone, 3)
    private let eyeGlints = BossNode.shape(.white, 0)
    private let grill = BossNode.shape(Palette.ink, 2)
    private let grillBars = BossNode.line(2, color: RobotNode.rust)
    private let antenna = BossNode.line(3)
    private let spark = BossNode.line(2.5, color: Palette.milestone)
    private let steam = BossNode.shape(Palette.cream, 2)

    private static let rust = SKColor(red: 0.74, green: 0.46, blue: 0.28, alpha: 1)
    private static let dark = SKColor(red: 0.42, green: 0.25, blue: 0.16, alpha: 1)

    init() {
        super.init(kind: .robot, warningY: 112)
        body.path = CGPath(roundedRect: CGRect(x: -48, y: -56, width: 96, height: 70), cornerWidth: 14, cornerHeight: 14, transform: nil)
        let patches = CGMutablePath()
        patches.addEllipse(in: CGRect(x: -40, y: -46, width: 20, height: 12))
        patches.addEllipse(in: CGRect(x: 22, y: -18, width: 16, height: 18))
        patches.addEllipse(in: CGRect(x: -26, y: 30, width: 14, height: 9))
        rustPatches.path = patches
        let rivetPath = CGMutablePath()
        for x in stride(from: CGFloat(-40), through: 40, by: 16) {
            rivetPath.addEllipse(in: CGRect(x: x - 2, y: 6, width: 4, height: 4))
            rivetPath.addEllipse(in: CGRect(x: x - 2, y: -52, width: 4, height: 4))
        }
        rivets.path = rivetPath
        dial.path = Self.ellipse(0, -24, 30, 30)
        head.path = CGPath(roundedRect: CGRect(x: -38, y: 14, width: 76, height: 52), cornerWidth: 10, cornerHeight: 10, transform: nil)
        grill.path = CGPath(roundedRect: CGRect(x: -20, y: 20, width: 40, height: 12), cornerWidth: 3, cornerHeight: 3, transform: nil)
        let bars = CGMutablePath()
        for x in stride(from: CGFloat(-14), through: 14, by: 7) {
            bars.move(to: CGPoint(x: x, y: 21))
            bars.addLine(to: CGPoint(x: x, y: 31))
        }
        grillBars.path = bars
        for node in [flames, flameCore, armOutline, arms, claws, body, rustPatches, rivets, dial, needle, head, rustPatches,
                     eyes, eyeGlints, grill, grillBars, antenna, spark, steam] where node.parent == nil {
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { SKColor(red: 0.55, green: 0.55, blue: 0.58, alpha: 1) }

    override func paintFlash(_ white: Bool) {
        body.fillColor = white ? .white : Palette.flame
        head.fillColor = body.fillColor
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        let color = flash ? SKColor(white: 0.97, alpha: 1) : Self.rust
        body.fillColor = color
        head.fillColor = color
        // Jet alevleri (kesik titreme).
        let flick = boilJitter(step: step, index: 100, amount: 6)
        let flamePath = CGMutablePath()
        let corePath = CGMutablePath()
        for x in [CGFloat(-24), 24] {
            flamePath.addLines(between: [CGPoint(x: x - 11, y: -56), CGPoint(x: x + flick * 0.5, y: -96 - abs(flick) * 2), CGPoint(x: x + 11, y: -56)])
            flamePath.closeSubpath()
            corePath.addLines(between: [CGPoint(x: x - 5, y: -58), CGPoint(x: x, y: -78 - abs(flick)), CGPoint(x: x + 5, y: -58)])
            corePath.closeSubpath()
        }
        flames.path = flamePath
        flameCore.path = corePath
        // Kollar: kanca pençeler; uyarıda yukarı kalkar.
        let armPath = CGMutablePath()
        let clawPath = CGMutablePath()
        for side in [CGFloat(-1), 1] {
            let shoulder = CGPoint(x: side * 46, y: -6)
            let hand = CGPoint(x: side * 76, y: -46 + raise * 96 + boilJitter(step: step, index: 101 + Int(side), amount: 2))
            armPath.move(to: shoulder)
            armPath.addQuadCurve(to: hand, control: CGPoint(x: side * 82, y: -6 + raise * 20))
            clawPath.addArc(center: hand, radius: 9, startAngle: side > 0 ? -0.3 : .pi + 0.3,
                            endAngle: side > 0 ? -2.4 : .pi + 2.4, clockwise: side > 0)
        }
        arms.path = armPath
        armOutline.path = armPath
        claws.path = clawPath
        // Göstergenin ibresi titrer; son aşamada kırmızı bölgeye dayanır.
        let angle = (phase >= 3 ? 0.35 : 1.6) + boilJitter(step: step, index: 102, amount: 0.25)
        let needlePath = CGMutablePath()
        needlePath.move(to: CGPoint(x: 0, y: -24))
        needlePath.addLine(to: CGPoint(x: cos(angle) * 12, y: -24 + sin(angle) * 12))
        needle.path = needlePath
        // Ampul gözler: normalde sarı, uyarıda ve son aşamada kırmızı.
        let angry = telegraph != nil || phase >= 3
        eyes.fillColor = angry ? SKColor(red: 0.95, green: 0.28, blue: 0.22, alpha: 1) : Palette.milestone
        let size: CGFloat = telegraph != nil && step % 2 == 0 ? 24 : 20
        let eyePath = CGMutablePath()
        eyePath.addEllipse(in: CGRect(x: -18 - size / 2, y: 46 - size / 2, width: size, height: size))
        eyePath.addEllipse(in: CGRect(x: 18 - size / 2, y: 46 - size / 2, width: size, height: size))
        eyes.path = eyePath
        let glints = CGMutablePath()
        glints.addEllipse(in: CGRect(x: -23, y: 49, width: 5, height: 4))
        glints.addEllipse(in: CGRect(x: 13, y: 49, width: 5, height: 4))
        eyeGlints.path = glints
        let antennaPath = CGMutablePath()
        antennaPath.move(to: CGPoint(x: 0, y: 66))
        antennaPath.addLine(to: CGPoint(x: 0, y: 84))
        antennaPath.addEllipse(in: CGRect(x: -5, y: 84, width: 10, height: 10))
        antenna.path = antennaPath
        // Uyarıda kıvılcım ve buhar.
        if telegraph != nil {
            let zig = CGMutablePath()
            let s: CGFloat = step % 2 == 0 ? 1 : -1
            zig.move(to: CGPoint(x: 0, y: 94))
            zig.addLines(between: [CGPoint(x: 0, y: 94), CGPoint(x: 8 * s, y: 102), CGPoint(x: -4 * s, y: 108), CGPoint(x: 10 * s, y: 118)])
            spark.path = zig
            let puff = CGMutablePath()
            let rise = CGFloat(step % 4) * 6
            puff.addEllipse(in: CGRect(x: -58, y: 50 + rise, width: 16, height: 14))
            puff.addEllipse(in: CGRect(x: 42, y: 54 + rise, width: 14, height: 12))
            steam.path = puff
        } else {
            spark.path = nil
            steam.path = nil
        }
    }
}

// MARK: - 6. Hırlayan Bulldog (vinç kancasında)

/// Vinç kancasına patileriyle tutunmuş dev bulldog: sarkık yanaklar, alt çene öne çıkık iki diş,
/// çivili tasma, küçük melon şapka. Uyarıda hırlar: çene açılır, salya damlar.
final class BulldogNode: BossNode {
    private let cable = BossNode.line(4)
    private let hook = BossNode.line(9, color: SKColor(red: 0.45, green: 0.47, blue: 0.52, alpha: 1))
    private let hookOutline = BossNode.line(13)
    private let paws = BossNode.shape(BulldogNode.tan, 3)
    private let ears = BossNode.shape(BulldogNode.brown, 3)
    private let head = BossNode.shape(BulldogNode.tan, 4)
    private let patch = BossNode.shape(BulldogNode.brown, 0)
    private let jowls = BossNode.shape(BulldogNode.tan, 3.5)
    private let mouth = BossNode.shape(SKColor(red: 0.30, green: 0.05, blue: 0.12, alpha: 1), 3)
    private let jaw = BossNode.shape(BulldogNode.tan, 3.5)
    private let fangs = BossNode.shape(.white, 2)
    private let drool = BossNode.shape(SKColor(red: 0.80, green: 0.92, blue: 1, alpha: 0.9), 1.5)
    private let eyeWhites = BossNode.shape(Palette.cream, 2.5)
    private let pupils = BossNode.shape(Palette.ink, 0)
    private let brows = BossNode.line(7)
    private let nose = BossNode.shape(Palette.ink, 0)
    private let noseShine = BossNode.shape(.white, 0)
    private let collar = BossNode.shape(SKColor(red: 0.75, green: 0.14, blue: 0.14, alpha: 1), 3)
    private let spikes = BossNode.shape(SKColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1), 2)
    private let hatBrim = BossNode.shape(Palette.ink, 2)
    private let hatTop = BossNode.shape(Palette.ink, 2)
    private let hatBand = BossNode.shape(SKColor(red: 0.75, green: 0.14, blue: 0.14, alpha: 1), 0)

    private static let tan = SKColor(red: 0.86, green: 0.72, blue: 0.52, alpha: 1)
    private static let brown = SKColor(red: 0.50, green: 0.32, blue: 0.20, alpha: 1)
    private static let angry = SKColor(red: 0.90, green: 0.50, blue: 0.40, alpha: 1)

    init() {
        super.init(kind: .bulldog, warningY: 150)
        let cablePath = CGMutablePath()
        cablePath.move(to: CGPoint(x: 0, y: 112))
        cablePath.addLine(to: CGPoint(x: 0, y: 900))
        cable.path = cablePath
        let hookPath = CGMutablePath()
        hookPath.move(to: CGPoint(x: 0, y: 112))
        hookPath.addLine(to: CGPoint(x: 0, y: 84))
        hookPath.addArc(center: CGPoint(x: -12, y: 84), radius: 12, startAngle: 0, endAngle: -.pi, clockwise: true)
        hookPath.addLine(to: CGPoint(x: -24, y: 92))
        hook.path = hookPath
        hookOutline.path = hookPath
        let pawPath = CGMutablePath()
        pawPath.addEllipse(in: CGRect(x: -34, y: 64, width: 24, height: 20))
        pawPath.addEllipse(in: CGRect(x: 2, y: 64, width: 24, height: 20))
        paws.path = pawPath
        let earPath = CGMutablePath()
        earPath.addLines(between: [CGPoint(x: -62, y: 26), CGPoint(x: -72, y: 56), CGPoint(x: -36, y: 50)])
        earPath.closeSubpath()
        earPath.addLines(between: [CGPoint(x: 62, y: 26), CGPoint(x: 72, y: 56), CGPoint(x: 36, y: 50)])
        earPath.closeSubpath()
        ears.path = earPath
        head.path = Self.ellipse(0, 6, 136, 112)
        patch.path = Self.ellipse(26, 20, 38, 34)
        nose.path = CGPath(roundedRect: CGRect(x: -15, y: -6, width: 30, height: 18), cornerWidth: 8, cornerHeight: 8, transform: nil)
        noseShine.path = Self.ellipse(-5, 7, 9, 4)
        collar.path = CGPath(roundedRect: CGRect(x: -52, y: -66, width: 104, height: 15), cornerWidth: 7, cornerHeight: 7, transform: nil)
        let spikePath = CGMutablePath()
        for x in stride(from: CGFloat(-40), through: 40, by: 20) {
            spikePath.addLines(between: [CGPoint(x: x - 5, y: -66), CGPoint(x: x, y: -80), CGPoint(x: x + 5, y: -66)])
            spikePath.closeSubpath()
        }
        spikes.path = spikePath
        hatBrim.path = Self.ellipse(-6, 60, 58, 10)
        hatTop.path = CGPath(roundedRect: CGRect(x: -26, y: 60, width: 40, height: 24), cornerWidth: 14, cornerHeight: 14, transform: nil)
        hatBand.path = CGPath(rect: CGRect(x: -25, y: 62, width: 38, height: 5), transform: nil)
        for node in [cable, hookOutline, hook, ears, spikes, collar, head, patch, hatBrim, hatTop, hatBand, eyeWhites, pupils, brows,
                     mouth, jowls, jaw, fangs, drool, nose, noseShine, paws] {
            addChild(node)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override var splashColor: SKColor { Self.brown }

    override func paintFlash(_ white: Bool) {
        head.fillColor = white ? .white : Self.angry
        jowls.fillColor = head.fillColor
        jaw.fillColor = head.fillColor
    }

    override func draw(step: Int, telegraph: BossAttack?, phase: Int, flash: Bool) {
        let color = flash ? SKColor(white: 0.97, alpha: 1) : (phase >= 3 ? Self.angry : Self.tan)
        head.fillColor = color
        jowls.fillColor = color
        jaw.fillColor = color
        // Kablo sarkaçla birlikte hafif eğilir.
        zRotation = -heading * 0.05
        let open: CGFloat = telegraph != nil ? 18 : 4
        let shake: CGFloat = telegraph != nil && step % 2 == 0 ? 2 : 0
        let look = CGPoint(x: boilJitter(step: step, index: 110, amount: 2), y: -3)
        let (whites, pupilPath) = Self.eyes([CGPoint(x: -24 + shake, y: 22), CGPoint(x: 24 + shake, y: 22)], size: CGSize(width: 20, height: 20),
                                            pupil: telegraph == nil ? 5 : 4, look: look)
        eyeWhites.path = whites
        eyeWhites.fillColor = phase >= 3 ? SKColor(red: 1, green: 0.78, blue: 0.70, alpha: 1) : Palette.cream
        pupils.path = pupilPath
        let browPath = CGMutablePath()
        browPath.move(to: CGPoint(x: -44, y: 40))
        browPath.addLine(to: CGPoint(x: -10, y: 30 - (phase >= 2 ? 4 : 0)))
        browPath.move(to: CGPoint(x: 44, y: 40))
        browPath.addLine(to: CGPoint(x: 10, y: 30 - (phase >= 2 ? 4 : 0)))
        brows.path = browPath
        // Ağız ve sarkık yanaklar
        mouth.path = Self.ellipse(0, -30 - open / 2, 70, 14 + open)
        let jowlPath = CGMutablePath()
        jowlPath.addEllipse(in: CGRect(x: -64, y: -40 + shake, width: 60, height: 44))
        jowlPath.addEllipse(in: CGRect(x: 4, y: -40 - shake, width: 60, height: 44))
        jowls.path = jowlPath
        jaw.path = CGPath(roundedRect: CGRect(x: -38, y: -56 - open, width: 76, height: 22), cornerWidth: 10, cornerHeight: 10, transform: nil)
        let fangPath = CGMutablePath()
        for x in [CGFloat(-24), 24] {
            fangPath.addLines(between: [CGPoint(x: x - 6, y: -36 - open), CGPoint(x: x, y: -20 - open * 0.3), CGPoint(x: x + 6, y: -36 - open)])
            fangPath.closeSubpath()
        }
        fangs.path = fangPath
        if telegraph != nil {
            let drip = CGFloat(step % 6) * 5
            drool.path = Self.ellipse(30, -54 - open - drip, 7, 10)
        } else {
            drool.path = nil
        }
    }
}

// MARK: - Mermiler

/// Boss ve oyuncu mermileri. Dalga, boss'a göre renk alır (su, toprak, kıvılcım, havlama).
final class ProjectileNode: SKNode {
    let kind: ProjectileKind
    private let main = SKShapeNode()
    private let detail = SKShapeNode()

    init(kind: ProjectileKind, radius r: CGFloat, boss: BossKind?) {
        self.kind = kind
        super.init()
        addChild(main)
        addChild(detail)
        main.strokeColor = Palette.ink
        main.lineWidth = 2.5
        detail.strokeColor = .clear
        func circle(_ radius: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
        }
        switch kind {
        case .fireball:
            main.path = circle(r)
            main.fillColor = Palette.flame
            detail.path = CGPath(ellipseIn: CGRect(x: -r * 0.5, y: -r * 0.3, width: r, height: r), transform: nil)
            detail.fillColor = Palette.flameCore
        case .ink:
            main.path = circle(r)
            main.fillColor = SKColor(red: 0.26, green: 0.10, blue: 0.32, alpha: 1)
            detail.path = CGPath(ellipseIn: CGRect(x: -r * 0.55, y: r * 0.1, width: r * 0.5, height: r * 0.35), transform: nil)
            detail.fillColor = SKColor.white.withAlphaComponent(0.7)
        case .mud:
            let blob = CGMutablePath()
            blob.addEllipse(in: CGRect(x: -r, y: -r * 0.85, width: r * 2, height: r * 1.7))
            blob.addEllipse(in: CGRect(x: r * 0.3, y: r * 0.2, width: r * 0.9, height: r * 0.9))
            blob.addEllipse(in: CGRect(x: -r * 1.1, y: -r * 0.2, width: r * 0.8, height: r * 0.8))
            main.path = blob
            main.fillColor = SKColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 1)
            detail.path = CGPath(ellipseIn: CGRect(x: -r * 0.4, y: r * 0.15, width: r * 0.45, height: r * 0.3), transform: nil)
            detail.fillColor = SKColor(red: 0.70, green: 0.55, blue: 0.38, alpha: 1)
        case .sonic:
            // İç içe yaylar: ses dalgası.
            let rings = CGMutablePath()
            rings.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
            main.path = rings
            main.fillColor = boss == .alien ? SKColor(red: 0.55, green: 0.95, blue: 0.45, alpha: 0.85)
                : SKColor(red: 0.78, green: 0.55, blue: 0.95, alpha: 0.85)
            let inner = CGMutablePath()
            inner.addEllipse(in: CGRect(x: -r * 0.55, y: -r * 0.55, width: r * 1.1, height: r * 1.1))
            detail.path = inner
            detail.fillColor = .clear
            detail.strokeColor = Palette.ink
            detail.lineWidth = 1.5
        case .laser:
            main.path = CGPath(roundedRect: CGRect(x: -r * 0.7, y: -r * 1.4, width: r * 1.4, height: r * 2.8), cornerWidth: r * 0.7, cornerHeight: r * 0.7, transform: nil)
            main.fillColor = SKColor(red: 1, green: 0.45, blue: 0.20, alpha: 1)
            detail.path = CGPath(roundedRect: CGRect(x: -r * 0.3, y: -r * 1.1, width: r * 0.6, height: r * 2.2), cornerWidth: r * 0.3, cornerHeight: r * 0.3, transform: nil)
            detail.fillColor = Palette.flameCore
        case .bolt:
            // Altıgen somun.
            let hex = CGMutablePath()
            for index in 0..<6 {
                let angle = CGFloat(index) * .pi / 3
                let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                if index == 0 { hex.move(to: point) } else { hex.addLine(to: point) }
            }
            hex.closeSubpath()
            main.path = hex
            main.fillColor = SKColor(red: 0.66, green: 0.68, blue: 0.72, alpha: 1)
            detail.path = circle(r * 0.4)
            detail.fillColor = Palette.ink
        case .bone:
            let bone = CGMutablePath()
            bone.addRoundedRect(in: CGRect(x: -r, y: -r * 0.28, width: r * 2, height: r * 0.56), cornerWidth: 3, cornerHeight: 3)
            for x in [-r, r] {
                for y in [-r * 0.32, r * 0.32] {
                    bone.addEllipse(in: CGRect(x: x - r * 0.36, y: y - r * 0.36, width: r * 0.72, height: r * 0.72))
                }
            }
            main.path = bone
            main.fillColor = Palette.cream
            main.lineWidth = 2
        case .wave:
            let arch = CGMutablePath()
            arch.move(to: CGPoint(x: -r * 1.6, y: -r))
            arch.addQuadCurve(to: CGPoint(x: r * 1.6, y: -r), control: CGPoint(x: 0, y: r * 2.2))
            arch.closeSubpath()
            main.path = arch
            main.lineWidth = 3
            switch boss {
            case .worm?, .bulldog?:
                main.fillColor = SKColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
            case .robot?:
                main.fillColor = SKColor(red: 1, green: 0.62, blue: 0.20, alpha: 1)
            default:
                main.fillColor = SKColor(red: 0.36, green: 0.36, blue: 0.78, alpha: 1)
            }
            let foam = CGMutablePath()
            for dx in [CGFloat(-10), 0, 10] {
                foam.addEllipse(in: CGRect(x: dx - 5, y: r * 0.35, width: 10, height: 8))
            }
            detail.path = foam
            detail.fillColor = Palette.cream
            detail.strokeColor = Palette.ink
            detail.lineWidth = 1.5
        case .bullet:
            main.path = CGPath(roundedRect: CGRect(x: -3.5, y: -9, width: 7, height: 18), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            main.fillColor = Palette.cream
            main.lineWidth = 2
            detail.path = CGPath(ellipseIn: CGRect(x: -7, y: -14, width: 14, height: 10), transform: nil)
            detail.fillColor = Palette.flameCore.withAlphaComponent(0.6)
            detail.zPosition = -1
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    /// Kesik titreşim ve dönüş (12 fps).
    func tick(step: Int) {
        switch kind {
        case .fireball, .laser: setScale(step % 2 == 0 ? 1 : 1.12)
        case .wave: yScale = step % 2 == 0 ? 1 : 1.1
        case .sonic: setScale(step % 2 == 0 ? 1 : 1.25)
        case .mud: xScale = step % 2 == 0 ? 1 : 0.88
        case .bolt, .bone: zRotation += .pi / 4
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

/// Boss galerisi önizlemesi: boss yerinde süzülür, ara sıra uyarı pozuna geçer.
final class BossPreviewScene: SKScene {
    private let boss: BossNode
    private var lastTick: TimeInterval = 0
    private var step = 0
    private let locked: Bool

    init(kind: BossKind, locked: Bool) {
        boss = BossNode.make(kind)
        self.locked = locked
        super.init(size: CGSize(width: 340, height: 300))
        backgroundColor = .clear
        scaleMode = .aspectFit
        boss.position = CGPoint(x: 170, y: kind == .bulldog ? 110 : 140)
        boss.setScale(kind == .bulldog ? 0.95 : 1.05)
        addChild(boss)
        if locked {
            // Henüz karşılaşılmadı: kara siluet.
            let effect = SKEffectNode()
            boss.removeFromParent()
            effect.addChild(boss)
            effect.filter = CIFilter(name: "CIColorControls", parameters: ["inputBrightness": -1.0, "inputSaturation": 0.0])
            effect.shouldEnableEffects = true
            addChild(effect)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override func update(_ currentTime: TimeInterval) {
        guard currentTime - lastTick >= 1.0 / 12.0 else { return }
        lastTick = currentTime
        step &+= 1
        let warning: BossAttack? = !locked && step % 48 > 36 ? .spread : nil
        boss.tick(step: step, telegraph: warning, phase: 1, flash: false)
    }
}
