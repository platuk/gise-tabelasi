import SpriteKit
import GameCore

/// Kulenin duvarı: dünyaya göre tuğla, ahşap, yosunlu taş, şato taşı, uzay paneli ya da perçinli sac.
/// Kamerayla birlikte taşınır, desen kaydırılarak sonsuz görünür.
final class WallNode: SKNode {
    private let base = SKShapeNode()
    private let pattern = SKShapeNode()
    private let accents = SKShapeNode()
    private var rowHeight: CGFloat = 16
    private var size = CGSize(width: 18, height: 800)
    private(set) var theme = WorldTheme.harbor

    override init() {
        super.init()
        base.strokeColor = Palette.ink
        base.lineWidth = 2.5
        pattern.strokeColor = Palette.ink
        pattern.lineWidth = 1
        accents.lineWidth = 1.4
        addChild(base)
        addChild(pattern)
        addChild(accents)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func configure(width: CGFloat, height: CGFloat) {
        size = CGSize(width: width, height: height)
        redraw()
    }

    func setTheme(_ newTheme: WorldTheme) {
        guard newTheme != theme else { return }
        theme = newTheme
        redraw()
    }

    private func redraw() {
        let width = size.width
        let height = size.height
        base.path = CGPath(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), transform: nil)
        let path = CGMutablePath()
        let accent = CGMutablePath()
        let left = -width / 2
        let right = width / 2
        func rows(_ h: CGFloat, joints: Bool) {
            rowHeight = h
            var y = -height / 2 - h * 2
            var row = 0
            while y < height / 2 + h {
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
                if joints {
                    let joint = row % 2 == 0 ? -width / 6 : width / 6
                    path.move(to: CGPoint(x: joint, y: y))
                    path.addLine(to: CGPoint(x: joint, y: y + h))
                }
                y += h
                row += 1
            }
        }
        switch theme {
        case .harbor:
            base.fillColor = SKColor(red: 0.55, green: 0.40, blue: 0.27, alpha: 1)
            rows(12, joints: false)
            var y = -height / 2 - 24
            while y < height / 2 + 24 {
                accent.addEllipse(in: CGRect(x: -1.2, y: y + 5, width: 2.4, height: 2.4))
                y += 24
            }
            accents.fillColor = Palette.ink
        case .garden:
            base.fillColor = SKColor(red: 0.62, green: 0.60, blue: 0.54, alpha: 1)
            rows(22, joints: true)
            var y = -height / 2 - 44
            while y < height / 2 + 44 {
                accent.move(to: CGPoint(x: right - 1, y: y))
                accent.addQuadCurve(to: CGPoint(x: right - 1, y: y + 44), control: CGPoint(x: left + 2, y: y + 22))
                accent.addEllipse(in: CGRect(x: -3, y: y + 20, width: 6, height: 4))
                y += 44
            }
            accents.strokeColor = SKColor(red: 0.30, green: 0.55, blue: 0.25, alpha: 1)
            accents.fillColor = SKColor(red: 0.42, green: 0.70, blue: 0.32, alpha: 1)
        case .haunted:
            base.fillColor = SKColor(red: 0.30, green: 0.28, blue: 0.36, alpha: 1)
            rows(26, joints: true)
            accents.fillColor = .clear
            accents.strokeColor = .clear
        case .space:
            base.fillColor = SKColor(red: 0.62, green: 0.68, blue: 0.78, alpha: 1)
            rows(30, joints: false)
            var y = -height / 2 - 60
            while y < height / 2 + 60 {
                accent.addEllipse(in: CGRect(x: -2, y: y + 13, width: 4, height: 4))
                y += 30
            }
            accents.fillColor = SKColor(red: 0.40, green: 0.95, blue: 0.55, alpha: 1)
            accents.strokeColor = Palette.ink
        case .factory:
            base.fillColor = SKColor(red: 0.40, green: 0.44, blue: 0.40, alpha: 1)
            rows(28, joints: false)
            var y = -height / 2 - 56
            while y < height / 2 + 56 {
                for x in [left + 3.5, right - 3.5] {
                    accent.addEllipse(in: CGRect(x: x - 1.3, y: y + 4, width: 2.6, height: 2.6))
                    accent.addEllipse(in: CGRect(x: x - 1.3, y: y + 22, width: 2.6, height: 2.6))
                }
                y += 28
            }
            accents.fillColor = Palette.ink
            accents.strokeColor = .clear
        case .city:
            base.fillColor = Palette.brick
            rows(16, joints: true)
            accents.fillColor = .clear
            accents.strokeColor = .clear
        }
        pattern.path = path
        pattern.alpha = theme == .haunted ? 0.7 : 0.45
        accents.path = accent
    }

    func scroll(cameraY: Double) {
        // Desenler satır yüksekliğinin iki katıyla tekrar eder (süsler de bu aralıkta).
        let period = Double(rowHeight * 2)
        let offset = CGFloat(cameraY.truncatingRemainder(dividingBy: period))
        pattern.position = CGPoint(x: 0, y: -offset)
        accents.position = pattern.position
    }
}

/// Alttan yükselen yanan film: kömürleşmiş koyu alan, üstünde titreyen alev kenarı.
final class BurnEdge: SKNode {
    private let charredArea = SKShapeNode()
    private let glow = SKShapeNode()
    private let core = SKShapeNode()
    private let width: CGFloat

    init(width: CGFloat) {
        self.width = width
        super.init()
        charredArea.fillColor = Palette.charred
        charredArea.strokeColor = .clear
        glow.strokeColor = Palette.flame
        glow.lineWidth = 10
        glow.alpha = 0.85
        glow.lineCap = .round
        core.strokeColor = Palette.flameCore
        core.lineWidth = 3
        core.lineCap = .round
        addChild(charredArea)
        addChild(glow)
        addChild(core)
        redraw(step: 0)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func redraw(step: Int) {
        let segments = 28
        var points: [CGPoint] = []
        for index in 0...segments {
            let x = -20 + (width + 40) * CGFloat(index) / CGFloat(segments)
            let wave = sin(x * 0.045 + CGFloat(step) * 0.9) * 5 + boilJitter(step: step, index: 300 + index, amount: 4)
            points.append(CGPoint(x: x, y: wave))
        }
        let edge = CGMutablePath()
        edge.addLines(between: points)
        glow.path = edge
        core.path = edge

        let fill = CGMutablePath()
        fill.addLines(between: points)
        fill.addLine(to: CGPoint(x: width + 20, y: -3000))
        fill.addLine(to: CGPoint(x: -20, y: -3000))
        fill.closeSubpath()
        charredArea.path = fill
    }
}

/// Eski film görüntüsü: gren, toz, çizik, titreme ve kenar kararması.
/// Tamamen kodla (Metal'e çevrilen SpriteKit shader'ı) üretilir; saniyede 12 kez yeni kare.
final class FilmOverlay: SKSpriteNode {
    private let stepUniform = SKUniform(name: "u_step", float: 0)

    init(size: CGSize) {
        super.init(texture: nil, color: .clear, size: size)
        let shader = SKShader(source: FilmOverlay.source, uniforms: [
            stepUniform,
            SKUniform(name: "u_res", vectorFloat2: SIMD2<Float>(Float(size.width / 1.5), Float(size.height / 1.5))),
            SKUniform(name: "u_aspect", float: Float(size.width / max(size.height, 1))),
        ])
        self.shader = shader
        blendMode = .alpha
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func setStep(_ step: Int) {
        stepUniform.floatValue = Float(step % 997)
    }

    private static let source = """
    float filmHash(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
    }

    void main() {
        vec2 uv = v_tex_coord;
        float t = u_step;

        float grain = filmHash(floor(uv * u_res) + vec2(t * 3.17, t * 1.93)) - 0.5;

        vec2 d = uv - vec2(0.5, 0.5);
        d.x *= u_aspect;
        float vignette = smoothstep(0.30, 0.95, length(d) * 1.25);

        float scratchX = filmHash(vec2(t, 1.7));
        float scratchOn = step(0.6, filmHash(vec2(t, 4.2)));
        float scratch = scratchOn * (1.0 - smoothstep(0.0, 0.0018, abs(uv.x - scratchX)));

        vec2 cellUV = uv * vec2(14.0, 28.0);
        vec2 cell = floor(cellUV);
        float speck = step(0.992, filmHash(cell + vec2(t * 0.71, t * 0.37)));
        float dust = speck * (1.0 - smoothstep(0.08, 0.2, length(fract(cellUV) - vec2(0.5, 0.5))));

        float flicker = (filmHash(vec2(t, 9.3)) - 0.5) * 0.08;

        // Hafif tutulur: film hissi versin ama renkleri griye boğmasın.
        float dark = clamp(vignette * 0.26 + max(-grain, 0.0) * 0.08 + dust * 0.55 + max(flicker, 0.0) * 0.5, 0.0, 0.6);
        float light = clamp(max(grain, 0.0) * 0.05 + scratch * 0.35 + max(-flicker, 0.0) * 0.4, 0.0, 0.4);
        float alpha = clamp(dark + light, 0.0, 0.7);
        // Koyu kısım sıcak kahve (sepya), gri değil.
        vec3 tint = mix(vec3(0.20, 0.11, 0.05), vec3(1.0, 0.96, 0.86), light / max(alpha, 0.001));
        gl_FragColor = vec4(tint * alpha, alpha);
    }
    """
}

/// Üst bilgi: kat, puan ve kombo göstergesi. Kamera alanında, ekran noktası cinsinden.
final class HUD: SKNode {
    private let floorLabel = HUD.label(size: 20)
    private let scoreLabel = HUD.label(size: 20)
    private let comboLabel = HUD.label(size: 18)
    private let comboBarBack = SKShapeNode()
    private let comboBar = SKShapeNode()
    /// Etkin baloncukların göstergesi: ikon + kalan saniye.
    private var powerUpSlots: [PowerUp: (node: SKNode, label: SKLabelNode)] = [:]
    private var powerUpRowY: CGFloat = 0
    // Boss dövüşü: can çubuğu ve oyuncunun kalpleri
    private let bossPanel = SKNode()
    private let bossName = HUD.label(size: 15)
    private let bossBarBack = SKShapeNode()
    private let bossBar = SKShapeNode()
    private let bossBarWidth: CGFloat = 230
    private var hearts: [SKShapeNode] = []
    private var shownFloor = -1
    private var shownScore = -1
    private let barWidth: CGFloat = 150

    override init() {
        super.init()
        floorLabel.horizontalAlignmentMode = .left
        scoreLabel.horizontalAlignmentMode = .right
        comboBarBack.path = CGPath(roundedRect: CGRect(x: -barWidth / 2, y: -4, width: barWidth, height: 8),
                                   cornerWidth: 4, cornerHeight: 4, transform: nil)
        comboBarBack.fillColor = Palette.cream
        comboBarBack.strokeColor = Palette.ink
        comboBarBack.lineWidth = 2
        comboBar.fillColor = Palette.flame
        comboBar.strokeColor = .clear
        for node in [floorLabel, scoreLabel, comboLabel, comboBarBack, comboBar] {
            addChild(node)
        }
        for kind in [PowerUp.slowTime, .adrenaline, .shield] {
            let slot = SKNode()
            let icon = PowerUpIcon.node(kind, size: 22)
            icon.position = CGPoint(x: -12, y: 0)
            slot.addChild(icon)
            let label = HUD.label(size: 16)
            label.horizontalAlignmentMode = .left
            label.position = CGPoint(x: 2, y: 0)
            slot.addChild(label)
            slot.isHidden = true
            addChild(slot)
            powerUpSlots[kind] = (slot, label)
        }
        bossBarBack.path = CGPath(roundedRect: CGRect(x: -bossBarWidth / 2, y: -7, width: bossBarWidth, height: 14),
                                  cornerWidth: 6, cornerHeight: 6, transform: nil)
        bossBarBack.fillColor = Palette.cream
        bossBarBack.strokeColor = Palette.ink
        bossBarBack.lineWidth = 3
        bossBar.fillColor = SKColor(red: 0.58, green: 0.26, blue: 0.64, alpha: 1)
        bossBar.strokeColor = .clear
        bossName.position = CGPoint(x: 0, y: 18)
        bossPanel.addChild(bossName)
        bossPanel.addChild(bossBarBack)
        bossPanel.addChild(bossBar)
        bossPanel.isHidden = true
        addChild(bossPanel)
        for _ in 0..<3 {
            let heart = SKShapeNode(path: HeartShape.path(size: 22))
            heart.fillColor = SKColor(red: 0.86, green: 0.18, blue: 0.22, alpha: 1)
            heart.strokeColor = Palette.ink
            heart.lineWidth = 2.5
            heart.isHidden = true
            hearts.append(heart)
            addChild(heart)
        }
        hideCombo()
    }

    func showBoss(_ visible: Bool, name: String, color: SKColor) {
        if visible {
            bossName.text = name
            bossBar.fillColor = color
        }
        bossPanel.isHidden = !visible
        for heart in hearts { heart.isHidden = !visible }
    }

    func updateBoss(hp: Int, maxHP: Int, playerHP: Int) {
        let fraction = CGFloat(max(0, hp)) / CGFloat(max(1, maxHP))
        bossBar.path = CGPath(roundedRect: CGRect(x: -bossBarWidth / 2 + 2, y: -5, width: max(0.5, (bossBarWidth - 4) * fraction), height: 10),
                              cornerWidth: 4, cornerHeight: 4, transform: nil)
        for (index, heart) in hearts.enumerated() {
            heart.alpha = index < playerHP ? 1 : 0.2
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize, topInset: CGFloat) {
        let top = size.height / 2 - topInset - 24
        floorLabel.position = CGPoint(x: -size.width / 2 + 30, y: top)
        scoreLabel.position = CGPoint(x: size.width / 2 - 30, y: top)
        comboLabel.position = CGPoint(x: 0, y: top - 36)
        comboBarBack.position = CGPoint(x: 0, y: top - 56)
        comboBar.position = comboBarBack.position
        powerUpRowY = top - 84
        bossPanel.position = CGPoint(x: 0, y: top - 44)
        for (index, heart) in hearts.enumerated() {
            heart.position = CGPoint(x: -size.width / 2 + 34 + CGFloat(index) * 28, y: top - 34)
        }
    }

    /// Etkin baloncuk sürelerini gösterir; süresi bitenler gizlenir.
    func updatePowerUps(_ remaining: [PowerUp: Double]) {
        let active = [PowerUp.slowTime, .adrenaline, .shield].filter { (remaining[$0] ?? 0) > 0 }
        let spacing: CGFloat = 62
        var x = -spacing * CGFloat(active.count - 1) / 2
        for kind in [PowerUp.slowTime, .adrenaline, .shield] {
            guard let slot = powerUpSlots[kind] else { continue }
            let seconds = remaining[kind] ?? 0
            slot.node.isHidden = seconds <= 0
            guard seconds > 0 else { continue }
            slot.node.position = CGPoint(x: x, y: powerUpRowY)
            slot.label.text = "\(Int(seconds.rounded(.up)))"
            // Son iki saniyede yanıp söner.
            slot.node.alpha = seconds < 2 && Int(seconds * 6) % 2 == 0 ? 0.35 : 1
            x += spacing
        }
    }

    func update(floor: Int, score: Int, comboFraction: Double?) {
        if floor != shownFloor {
            shownFloor = floor
            floorLabel.text = String(localized: "hud.floor \(floor)")
        }
        if score != shownScore {
            shownScore = score
            scoreLabel.text = String(localized: "hud.score \(score)")
        }
        if let fraction = comboFraction {
            let width = barWidth * CGFloat(max(0, min(1, fraction)))
            comboBar.path = CGPath(roundedRect: CGRect(x: -barWidth / 2, y: -4, width: max(width, 0.1), height: 8),
                                   cornerWidth: 4, cornerHeight: 4, transform: nil)
        }
    }

    func showCombo(jumps: Int, floors: Int) {
        comboLabel.text = String(localized: "hud.combo \(jumps) \(floors)")
        comboLabel.isHidden = false
        comboBar.isHidden = false
        comboBarBack.isHidden = false
        comboLabel.removeAllActions()
        comboLabel.run(.sequence([
            .scale(to: 1.35, duration: 0), .wait(forDuration: 1.0 / 12.0),
            .scale(to: 1.1, duration: 0), .wait(forDuration: 1.0 / 12.0),
            .scale(to: 1.0, duration: 0),
        ]))
    }

    func hideCombo() {
        comboLabel.isHidden = true
        comboBar.isHidden = true
        comboBarBack.isHidden = true
    }

    private static func label(size: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: Palette.fontName)
        label.fontSize = size
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        return label
    }
}

/// Baloncukların içindeki çizimler (emoji değil, 1930'lar tarzı kalın çizgili şekiller).
enum PowerUpIcon {
    static func node(_ kind: PowerUp, size: CGFloat) -> SKNode {
        let node = SKNode()
        let s = size / 24
        func shape(_ path: CGPath, fill: SKColor, line: CGFloat = 2) -> SKShapeNode {
            let shape = SKShapeNode(path: path)
            shape.fillColor = fill
            shape.strokeColor = Palette.ink
            shape.lineWidth = line * s
            shape.lineJoin = .round
            return shape
        }
        switch kind {
        case .boost:
            let body = CGMutablePath()
            body.addEllipse(in: CGRect(x: -5 * s, y: -9 * s, width: 10 * s, height: 20 * s))
            let fins = CGMutablePath()
            fins.addLines(between: [CGPoint(x: -5 * s, y: -6 * s), CGPoint(x: -10 * s, y: -11 * s), CGPoint(x: -4 * s, y: -9 * s)])
            fins.addLines(between: [CGPoint(x: 5 * s, y: -6 * s), CGPoint(x: 10 * s, y: -11 * s), CGPoint(x: 4 * s, y: -9 * s)])
            let flame = CGMutablePath()
            flame.addLines(between: [CGPoint(x: -3 * s, y: -10 * s), CGPoint(x: 0, y: -17 * s), CGPoint(x: 3 * s, y: -10 * s)])
            flame.closeSubpath()
            node.addChild(shape(flame, fill: Palette.flame))
            node.addChild(shape(fins, fill: Palette.beam))
            node.addChild(shape(body, fill: Palette.cream))
            let window = CGMutablePath()
            window.addEllipse(in: CGRect(x: -2.5 * s, y: 1 * s, width: 5 * s, height: 5 * s))
            node.addChild(shape(window, fill: Palette.slipperyBeam, line: 1.5))
        case .slowTime:
            let glass = CGMutablePath()
            glass.addLines(between: [CGPoint(x: -7 * s, y: 10 * s), CGPoint(x: 7 * s, y: 10 * s), CGPoint(x: 0, y: 0),
                                     CGPoint(x: 7 * s, y: -10 * s), CGPoint(x: -7 * s, y: -10 * s), CGPoint(x: 0, y: 0)])
            glass.closeSubpath()
            node.addChild(shape(glass, fill: Palette.cream))
            let sand = CGMutablePath()
            sand.addLines(between: [CGPoint(x: -4 * s, y: -8 * s), CGPoint(x: 4 * s, y: -8 * s), CGPoint(x: 0, y: -3 * s)])
            sand.closeSubpath()
            node.addChild(shape(sand, fill: Palette.milestone, line: 1))
        case .adrenaline:
            let bolt = CGMutablePath()
            bolt.addLines(between: [CGPoint(x: 3 * s, y: 12 * s), CGPoint(x: -6 * s, y: 0), CGPoint(x: -0.5 * s, y: 0),
                                    CGPoint(x: -3 * s, y: -12 * s), CGPoint(x: 6 * s, y: 2 * s), CGPoint(x: 0.5 * s, y: 2 * s)])
            bolt.closeSubpath()
            node.addChild(shape(bolt, fill: Palette.flameCore))
        case .shield:
            let crest = CGMutablePath()
            crest.move(to: CGPoint(x: -8 * s, y: 9 * s))
            crest.addLine(to: CGPoint(x: 8 * s, y: 9 * s))
            crest.addLine(to: CGPoint(x: 8 * s, y: 0))
            crest.addQuadCurve(to: CGPoint(x: 0, y: -11 * s), control: CGPoint(x: 8 * s, y: -7 * s))
            crest.addQuadCurve(to: CGPoint(x: -8 * s, y: 0), control: CGPoint(x: -8 * s, y: -7 * s))
            crest.closeSubpath()
            node.addChild(shape(crest, fill: Palette.slidingBeam))
            let band = CGMutablePath()
            band.addRect(CGRect(x: -1.5 * s, y: -9 * s, width: 3 * s, height: 17 * s))
            node.addChild(shape(band, fill: Palette.cream, line: 1))
        }
        return node
    }
}

/// Kirişin üstünde süzülen sürpriz baloncuk: yarı saydam köpük, parlak yansıma, içinde etkisinin çizimi.
final class BubbleNode: SKNode {
    let kind: PowerUp

    init(kind: PowerUp, radius: CGFloat) {
        self.kind = kind
        super.init()
        let foam = SKShapeNode(circleOfRadius: radius)
        foam.fillColor = Palette.cream.withAlphaComponent(0.45)
        foam.strokeColor = Palette.ink
        foam.lineWidth = 2.5
        addChild(foam)
        addChild(PowerUpIcon.node(kind, size: radius * 1.1))
        let shine = SKShapeNode()
        let arc = CGMutablePath()
        arc.addArc(center: .zero, radius: radius * 0.72, startAngle: .pi * 0.55, endAngle: .pi * 0.9, clockwise: false)
        shine.path = arc
        shine.strokeColor = .white
        shine.lineWidth = 3
        shine.lineCap = .round
        addChild(shine)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    /// Saniyede 12 kez: hafif, kesik süzülme.
    func bob(step: Int, baseY: CGFloat) {
        let offsets: [CGFloat] = [0, 1.5, 3, 1.5, 0, -1.5, -3, -1.5]
        position.y = baseY + offsets[(step + Int(baseY) % 8) % offsets.count]
    }

    /// Alındığında patlama: halkalar ve damlacıklar.
    func pop(in parent: SKNode) {
        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 10)
            ring.strokeColor = Palette.ink
            ring.lineWidth = 2
            ring.fillColor = .clear
            ring.position = position
            ring.zPosition = zPosition + 1
            parent.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(index) / 12.0),
                .group([.scale(to: 3.5, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .removeFromParent(),
            ]))
        }
        removeFromParent()
    }
}

enum ControlRole: Hashable {
    case left, right
}

/// Dokunma kontrolleri: ekranın sol yarısına basılı tutmak sola, sağ yarısına basılı tutmak sağa koşturur.
/// Alt köşelerdeki büyük silik oklar yalnızca ipucudur; basılan taraf parlar.
/// Tırmanışta zıplama otomatiktir. Boss dövüşünde ortada "yukarı kaydır" ipucu görünür.
final class ControlsOverlay: SKNode {
    private let left = ControlsOverlay.sideHint(pointingLeft: true)
    private let right = ControlsOverlay.sideHint(pointingLeft: false)
    private let swipeHint = SKNode()
    private var swipeHintBaseY: CGFloat = 0

    override init() {
        super.init()
        addChild(left)
        addChild(right)

        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 0, y: 22))
        arrow.addLine(to: CGPoint(x: 16, y: 2))
        arrow.addLine(to: CGPoint(x: 6, y: 2))
        arrow.addLine(to: CGPoint(x: 6, y: -18))
        arrow.addLine(to: CGPoint(x: -6, y: -18))
        arrow.addLine(to: CGPoint(x: -6, y: 2))
        arrow.addLine(to: CGPoint(x: -16, y: 2))
        arrow.closeSubpath()
        let shape = SKShapeNode(path: arrow)
        shape.fillColor = Palette.cream
        shape.strokeColor = Palette.ink
        shape.lineWidth = 3
        shape.lineJoin = .round
        swipeHint.addChild(shape)
        let label = SKLabelNode(fontNamed: Palette.fontName)
        label.text = String(localized: "controls.swipeJump")
        label.fontSize = 13
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 0, y: -26)
        swipeHint.addChild(label)
        swipeHint.isHidden = true
        addChild(swipeHint)
        highlight([])
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize, topInset: CGFloat, bottomInset: CGFloat) {
        let y = -size.height / 2 + bottomInset + 70
        left.position = CGPoint(x: -size.width / 4, y: y)
        right.position = CGPoint(x: size.width / 4, y: y)
        swipeHintBaseY = y + 6
        swipeHint.removeAllActions()
        swipeHint.position = CGPoint(x: 0, y: swipeHintBaseY)
        if !swipeHint.isHidden {
            swipeHint.isHidden = true
            showSwipeHint(true)
        }
    }

    /// Boss dövüşünde "yukarı kaydır: zıpla" ipucunu gösterir; 12 fps kesik bir zıplama hareketiyle.
    func showSwipeHint(_ on: Bool) {
        guard swipeHint.isHidden == on else { return }
        swipeHint.isHidden = !on
        swipeHint.removeAllActions()
        swipeHint.position.y = swipeHintBaseY
        guard on else { return }
        let frame = 1.0 / 12.0
        swipeHint.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 6, duration: 0), .wait(forDuration: frame * 2),
            .moveBy(x: 0, y: 6, duration: 0), .wait(forDuration: frame * 2),
            .moveBy(x: 0, y: -12, duration: 0), .wait(forDuration: frame * 4),
        ])))
    }

    func highlight(_ roles: Set<ControlRole>) {
        left.alpha = roles.contains(.left) ? 0.75 : 0.18
        right.alpha = roles.contains(.right) ? 0.75 : 0.18
    }

    /// Büyük, silik yön oku (ipucu). Asıl dokunma alanı ekranın o yarısının tamamıdır.
    private static func sideHint(pointingLeft: Bool) -> SKNode {
        let node = SKNode()
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 26, y: 0))
        arrow.addLine(to: CGPoint(x: -16, y: 28))
        arrow.addLine(to: CGPoint(x: -16, y: -28))
        arrow.closeSubpath()
        let triangle = SKShapeNode(path: arrow)
        triangle.fillColor = Palette.cream
        triangle.strokeColor = Palette.ink
        triangle.lineWidth = 4
        triangle.lineJoin = .round
        triangle.zRotation = pointingLeft ? .pi : 0
        node.addChild(triangle)
        return node
    }
}
