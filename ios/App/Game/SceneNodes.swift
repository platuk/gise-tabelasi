import SpriteKit
import GameCore

/// Kiriş. Orijin: üst yüzeyin ortası. Türüne göre görünür:
/// çelik (perçinli kırmızı), kayan (tekerlekli yeşil), kaygan (parlak, damlalı buz mavisi), kupa katı (sarı, kupalı).
final class PlatformNode: SKNode {
    let isSliding: Bool

    init(platform: Platform) {
        if case .sliding = platform.kind { isSliding = true } else { isSliding = false }
        super.init()
        position = CGPoint(x: platform.centerX, y: platform.y)
        let width = CGFloat(platform.width)

        let beam = SKShapeNode(rect: CGRect(x: -width / 2, y: -13, width: width, height: 13), cornerRadius: 2)
        switch platform.kind {
        case .steel:
            beam.fillColor = platform.isMilestone ? Palette.milestone : Palette.beam
        case .sliding:
            beam.fillColor = Palette.slidingBeam
        case .slippery:
            beam.fillColor = Palette.slipperyBeam
        }
        beam.strokeColor = Palette.ink
        beam.lineWidth = 2.5
        addChild(beam)

        if isSliding {
            for side in [CGFloat(-1), 1] {
                let wheel = SKShapeNode(circleOfRadius: 4.5)
                wheel.fillColor = Palette.cream
                wheel.strokeColor = Palette.ink
                wheel.lineWidth = 2
                wheel.position = CGPoint(x: side * (width / 2 - 9), y: -17)
                addChild(wheel)
            }
        }

        if platform.isSlippery {
            let shine = CGMutablePath()
            var x = -width / 2 + 10
            while x < width / 2 - 10 {
                shine.move(to: CGPoint(x: x, y: -4))
                shine.addLine(to: CGPoint(x: x + 7, y: -9))
                x += 22
            }
            let streaks = SKShapeNode(path: shine)
            streaks.strokeColor = .white
            streaks.lineWidth = 2
            streaks.lineCap = .round
            addChild(streaks)
            let drips = CGMutablePath()
            for fraction in [CGFloat(-0.3), 0.15, 0.38] {
                let dx = width * fraction
                drips.addEllipse(in: CGRect(x: dx - 2, y: -21, width: 4, height: 7))
            }
            let dripNode = SKShapeNode(path: drips)
            dripNode.fillColor = Palette.slipperyBeam
            dripNode.strokeColor = Palette.ink
            dripNode.lineWidth = 1.2
            addChild(dripNode)
        }

        if platform.isMilestone, let tier = TrophyTier(checkpointFloor: platform.floor) {
            let trophy = TrophyNode(tier: tier, size: 30)
            trophy.position = CGPoint(x: 0, y: 17)
            trophy.zPosition = 1
            addChild(trophy)
        }

        let details = CGMutablePath()
        details.move(to: CGPoint(x: -width / 2 + 3, y: -9))
        details.addLine(to: CGPoint(x: width / 2 - 3, y: -9))
        var x = -width / 2 + 9
        while x < width / 2 - 6 {
            details.addEllipse(in: CGRect(x: x - 1.6, y: -5.6, width: 3.2, height: 3.2))
            x += 17
        }
        let rivets = SKShapeNode(path: details)
        rivets.strokeColor = Palette.ink
        rivets.fillColor = Palette.ink
        rivets.lineWidth = 1
        addChild(rivets)

        if platform.floor > 0 && platform.floor % 10 == 0 {
            let plate = SKShapeNode(rect: CGRect(x: -17, y: -32, width: 34, height: 16), cornerRadius: 3)
            plate.fillColor = Palette.cream
            plate.strokeColor = Palette.ink
            plate.lineWidth = 2
            addChild(plate)
            let label = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
            label.text = "\(platform.floor)"
            label.fontSize = 11
            label.fontColor = Palette.ink
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -24)
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }
}

/// Kulenin tuğla duvarı. Kamerayla birlikte taşınır, harç çizgileri kaydırılarak sonsuz görünür.
final class WallNode: SKNode {
    private let base = SKShapeNode()
    private let mortar = SKShapeNode()
    private let brickHeight: CGFloat = 16

    override init() {
        super.init()
        base.fillColor = Palette.brick
        base.strokeColor = Palette.ink
        base.lineWidth = 2.5
        mortar.strokeColor = Palette.ink
        mortar.lineWidth = 1
        mortar.alpha = 0.45
        addChild(base)
        addChild(mortar)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func configure(width: CGFloat, height: CGFloat) {
        base.path = CGPath(rect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), transform: nil)
        let path = CGMutablePath()
        var y = -height / 2 - brickHeight * 2
        var row = 0
        while y < height / 2 {
            path.move(to: CGPoint(x: -width / 2, y: y))
            path.addLine(to: CGPoint(x: width / 2, y: y))
            let joint = row % 2 == 0 ? -width / 6 : width / 6
            path.move(to: CGPoint(x: joint, y: y))
            path.addLine(to: CGPoint(x: joint, y: min(y + brickHeight, height / 2)))
            y += brickHeight
            row += 1
        }
        mortar.path = path
    }

    func scroll(cameraY: Double) {
        let period = Double(brickHeight * 2)
        let offset = cameraY.truncatingRemainder(dividingBy: period)
        mortar.position = CGPoint(x: 0, y: CGFloat(-offset))
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

        float dark = clamp(vignette * 0.5 + max(-grain, 0.0) * 0.22 + dust * 0.7 + max(flicker, 0.0), 0.0, 0.85);
        float light = clamp(max(grain, 0.0) * 0.12 + scratch * 0.45 + max(-flicker, 0.0), 0.0, 0.5);
        float alpha = clamp(dark + light, 0.0, 0.9);
        gl_FragColor = vec4(vec3(1.0, 0.96, 0.86) * light, alpha);
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
        hideCombo()
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize, topInset: CGFloat) {
        let top = size.height / 2 - topInset - 24
        floorLabel.position = CGPoint(x: -size.width / 2 + 30, y: top)
        scoreLabel.position = CGPoint(x: size.width / 2 - 30, y: top)
        comboLabel.position = CGPoint(x: 0, y: top - 36)
        comboBarBack.position = CGPoint(x: 0, y: top - 56)
        comboBar.position = comboBarBack.position
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
        let label = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
        label.fontSize = size
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        return label
    }
}

enum ControlRole: Hashable {
    case left, right
}

/// Dokunma kontrolleri: ekranın sol yarısına basılı tutmak sola, sağ yarısına basılı tutmak sağa koşturur.
/// Alt köşelerdeki büyük silik oklar yalnızca ipucudur; basılan taraf parlar.
/// Sağ üstteki "OTO" anahtarı otomatik zıplamayı açıp kapatır (ona dokunmak koşturmaz).
final class ControlsOverlay: SKNode {
    private let left = ControlsOverlay.sideHint(pointingLeft: true)
    private let right = ControlsOverlay.sideHint(pointingLeft: false)
    private let auto = SKNode()
    private let autoCircle = SKShapeNode(circleOfRadius: 25)
    private let autoLabel = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
    private let autoRadius: CGFloat = 34

    override init() {
        super.init()
        addChild(left)
        addChild(right)
        autoCircle.strokeColor = Palette.ink
        autoCircle.lineWidth = 3
        autoLabel.text = String(localized: "controls.auto")
        autoLabel.fontSize = 13
        autoLabel.fontColor = Palette.ink
        autoLabel.verticalAlignmentMode = .center
        auto.addChild(autoCircle)
        auto.addChild(autoLabel)
        addChild(auto)
        setAuto(false)
        highlight([])
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize, topInset: CGFloat, bottomInset: CGFloat) {
        let y = -size.height / 2 + bottomInset + 70
        left.position = CGPoint(x: -size.width / 4, y: y)
        right.position = CGPoint(x: size.width / 4, y: y)
        // Puanın altında, sağ üst köşe: koşarken yanlışlıkla dokunulmaz.
        auto.position = CGPoint(x: size.width / 2 - 46, y: size.height / 2 - topInset - 84)
    }

    func setAuto(_ on: Bool) {
        autoCircle.fillColor = on ? Palette.flame : Palette.cream
        auto.alpha = on ? 0.95 : 0.5
        auto.removeAllActions()
        auto.run(.sequence([.scale(to: 1.2, duration: 0), .wait(forDuration: 1.0 / 12.0), .scale(to: 1, duration: 0)]))
    }

    func isAutoButton(_ point: CGPoint) -> Bool {
        hypot(point.x - auto.position.x, point.y - auto.position.y) <= autoRadius
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
