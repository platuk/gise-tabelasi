import SpriteKit

/// 1930'lar "lastik hortum" tarzı özgün karakter: eklemsiz, eğri uzuvlar, beyaz eldivenler, iri ayakkabılar.
/// Konum her karede akıcı ilerler; çizim ise saniyede 12 kez, küçük titremelerle yenilenir
/// (elle çizilmiş animasyonun "kaynayan çizgi" hissi). Orijin: ayakların ortası.
final class RubberHoseCharacter: SKNode {
    private let style: CharacterStyle
    private let facingNode = SKNode()
    /// Takla için: gövdenin ortasında döner.
    private let spinNode = SKNode()
    private let squashNode = SKNode()

    private let legBack = RubberHoseCharacter.limb()
    private let legFront = RubberHoseCharacter.limb()
    private let armBack = RubberHoseCharacter.limb()
    private let armFront = RubberHoseCharacter.limb()
    private let shoeBack: SKShapeNode
    private let shoeFront: SKShapeNode
    private let gloveBack: SKShapeNode
    private let gloveFront: SKShapeNode
    private let body: SKShapeNode
    private let head: SKShapeNode
    private let face: SKShapeNode
    private let eyes = RubberHoseCharacter.filled(Palette.ink, stroke: false)
    private let nose = RubberHoseCharacter.filled(Palette.ink, stroke: false)
    private let mouth = RubberHoseCharacter.limb(width: 1.5)
    private let accessoryBack: SKShapeNode
    private let accessoryFront: SKShapeNode
    private let accessoryDetail: SKShapeNode

    private var vx = 0.0
    private var vy = 0.0
    private var grounded = true
    private var runPhase = 0.0
    private var step = 0

    private static let bodyCenter: CGFloat = 24

    init(style: CharacterStyle) {
        self.style = style
        shoeBack = RubberHoseCharacter.filled(style.shoes)
        shoeFront = RubberHoseCharacter.filled(style.shoes)
        gloveBack = RubberHoseCharacter.glove(style.gloves)
        gloveFront = RubberHoseCharacter.glove(style.gloves)
        body = RubberHoseCharacter.filled(style.body)
        head = RubberHoseCharacter.filled(style.body)
        face = RubberHoseCharacter.filled(style.face, stroke: false)
        accessoryBack = RubberHoseCharacter.filled(style.accent)
        accessoryFront = RubberHoseCharacter.filled(style.accent)
        accessoryDetail = RubberHoseCharacter.filled(Palette.ink)
        super.init()
        alpha = style.alpha
        addChild(facingNode)
        facingNode.addChild(spinNode)
        spinNode.position = CGPoint(x: 0, y: Self.bodyCenter)
        spinNode.addChild(squashNode)
        squashNode.position = CGPoint(x: 0, y: -Self.bodyCenter)
        // Çizim sırası: arka süs, arkadaki uzuvlar, gövde, baş, yüz, ön süs, öndeki uzuvlar.
        for node in [accessoryBack, legBack, shoeBack, armBack, gloveBack, body, head, face, eyes, nose, mouth,
                     accessoryFront, accessoryDetail, legFront, shoeFront, armFront, gloveFront] {
            squashNode.addChild(node)
        }
        redraw()
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    // MARK: Dışarıdan sürülen durum

    func update(vx: Double, vy: Double, grounded: Bool, facing: Int) {
        self.vx = vx
        self.vy = vy
        self.grounded = grounded
        facingNode.xScale = facing >= 0 ? 1 : -1
        guard squashNode.action(forKey: "land") == nil, squashNode.action(forKey: "jump") == nil else { return }
        if grounded {
            squashNode.xScale = 1
            squashNode.yScale = 1
        } else {
            let stretch = CGFloat(max(-0.12, min(0.18, vy / 3200)))
            squashNode.yScale = 1 + stretch
            squashNode.xScale = 1 - stretch * 0.6
        }
    }

    /// Saniyede 12 kez çağrılır.
    func tick(step: Int) {
        self.step = step
        if grounded {
            runPhase += abs(vx) / 540 * 1.7
        }
        redraw()
    }

    func playJump(power: Double) {
        squashNode.removeAction(forKey: "land")
        let stretch = CGFloat(0.18 + 0.12 * power)
        squashNode.run(steppedScales([(1 - stretch * 0.7, 1 + stretch), (0.95, 1.08)]), withKey: "jump")
    }

    func playLand() {
        squashNode.removeAction(forKey: "jump")
        squashNode.run(steppedScales([(1.35, 0.68), (1.12, 0.88), (1, 1)]), withKey: "land")
    }

    /// Duvar taklası: gövde ortası etrafında, kesik (12 fps) tam tur.
    func playFlip(towards direction: Int) {
        spinNode.removeAction(forKey: "flip")
        spinNode.zRotation = 0
        let turn = CGFloat(direction >= 0 ? -1 : 1) * .pi / 3
        var actions: [SKAction] = []
        for _ in 0..<6 {
            actions.append(.rotate(byAngle: turn, duration: 0))
            actions.append(.wait(forDuration: 1.0 / 12.0))
        }
        actions.append(.rotate(toAngle: 0, duration: 0))
        spinNode.run(.sequence(actions), withKey: "flip")
    }

    // MARK: Çizim

    private struct Pose {
        var footBack: CGPoint
        var footFront: CGPoint
        var handBack: CGPoint
        var handFront: CGPoint
        var legBend: CGFloat
        var armBend: CGFloat
        var bob: CGFloat
        var mouthOpen: Bool
    }

    private func currentPose() -> Pose {
        if !grounded {
            if vy > 120 {
                return Pose(footBack: CGPoint(x: -8, y: 7), footFront: CGPoint(x: 7, y: 10),
                            handBack: CGPoint(x: -15, y: 44), handFront: CGPoint(x: 14, y: 46),
                            legBend: 5, armBend: -5, bob: 0, mouthOpen: true)
            }
            let flail: CGFloat = step % 2 == 0 ? 3 : -3
            return Pose(footBack: CGPoint(x: -9, y: -1), footFront: CGPoint(x: 9, y: -3),
                        handBack: CGPoint(x: -17, y: 38 + flail), handFront: CGPoint(x: 17, y: 38 - flail),
                        legBend: -3, armBend: 6, bob: 0, mouthOpen: true)
        }
        if abs(vx) > 30 {
            let s = CGFloat(sin(runPhase))
            let c = CGFloat(cos(runPhase))
            return Pose(footBack: CGPoint(x: s * 9, y: max(0, c) * 7),
                        footFront: CGPoint(x: -s * 9, y: max(0, -c) * 7),
                        handBack: CGPoint(x: -4 - s * 9, y: 20 + abs(s) * 3),
                        handFront: CGPoint(x: 4 + s * 9, y: 20 + abs(s) * 3),
                        legBend: 4, armBend: -4, bob: abs(c) * 1.8, mouthOpen: false)
        }
        // Boşta: 1930'lar çizgi filmlerindeki gibi müzikle hafifçe sallanır.
        let sway: CGFloat = step % 4 < 2 ? 1 : -1
        return Pose(footBack: CGPoint(x: -6, y: 0), footFront: CGPoint(x: 6, y: 0),
                    handBack: CGPoint(x: -14 + sway, y: 17), handFront: CGPoint(x: 14 + sway, y: 17),
                    legBend: 2, armBend: 3, bob: step % 4 < 2 ? 1.2 : 0, mouthOpen: false)
    }

    private func redraw() {
        let pose = currentPose()
        let j = { (index: Int) -> CGFloat in boilJitter(step: self.step, index: index, amount: 0.6) }
        let bob = pose.bob

        let hipBack = CGPoint(x: -4 + j(1), y: 15 + bob)
        let hipFront = CGPoint(x: 4 + j(2), y: 15 + bob)
        let shoulderBack = CGPoint(x: -7 + j(3), y: 27 + bob)
        let shoulderFront = CGPoint(x: 7 + j(4), y: 27 + bob)

        legBack.path = hose(from: hipBack, to: pose.footBack, bend: pose.legBend + j(5))
        legFront.path = hose(from: hipFront, to: pose.footFront, bend: pose.legBend + j(6))
        armBack.path = hose(from: shoulderBack, to: pose.handBack, bend: pose.armBend + j(7))
        armFront.path = hose(from: shoulderFront, to: pose.handFront, bend: pose.armBend + j(8))

        shoeBack.path = ellipse(center: pose.footBack + CGPoint(x: 2.5, y: 0.5), width: 12 + j(9), height: 6.5)
        shoeFront.path = ellipse(center: pose.footFront + CGPoint(x: 2.5, y: 0.5), width: 12 + j(10), height: 6.5)
        gloveBack.path = ellipse(center: pose.handBack, width: 8.5 + j(11), height: 8.5)
        gloveFront.path = ellipse(center: pose.handFront, width: 8.5 + j(12), height: 8.5)

        body.path = ellipse(center: CGPoint(x: j(13), y: 23 + bob), width: 22 + j(14), height: 21)
        head.path = ellipse(center: CGPoint(x: j(15), y: 42 + bob), width: 25 + j(16), height: 23)
        face.path = ellipse(center: CGPoint(x: 3.5 + j(17), y: 40.5 + bob), width: 15, height: 15)
        eyes.path = pieEyes(center: CGPoint(x: 3.5 + j(18), y: 44 + bob))
        nose.path = ellipse(center: CGPoint(x: 9.5 + j(19), y: 40 + bob), width: 5.5, height: 4)

        let mouthPath = CGMutablePath()
        let mouthCenter = CGPoint(x: 5 + j(20), y: 36.5 + bob)
        if pose.mouthOpen {
            mouthPath.addEllipse(in: CGRect(x: mouthCenter.x - 1.8, y: mouthCenter.y - 2.2, width: 3.6, height: 4.4))
        } else {
            mouthPath.addArc(center: mouthCenter + CGPoint(x: 0, y: 2), radius: 3.5,
                             startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
        }
        mouth.path = mouthPath

        drawAccessory(bob: bob + j(21) * 0.5)
    }

    /// Baş süsleri: köpek kulağı, kedi kulağı, silindir şapka, pervaneli kasket.
    private func drawAccessory(bob: CGFloat) {
        let back = CGMutablePath()
        let front = CGMutablePath()
        let detail = CGMutablePath()
        switch style.accessory {
        case .none:
            break
        case .dogEars:
            // Sarkık kulaklar: başın iki yanında.
            let flap: CGFloat = grounded ? 0 : (vy > 0 ? -3 : 3)
            back.addEllipse(in: CGRect(x: -16, y: 31 + bob + flap, width: 9, height: 17))
            front.addEllipse(in: CGRect(x: 9, y: 31 + bob - flap, width: 9, height: 17))
        case .catEars:
            back.addLines(between: [CGPoint(x: -12, y: 47 + bob), CGPoint(x: -9, y: 60 + bob), CGPoint(x: -3, y: 52 + bob)])
            back.closeSubpath()
            front.addLines(between: [CGPoint(x: 3, y: 52 + bob), CGPoint(x: 8, y: 60 + bob), CGPoint(x: 12, y: 47 + bob)])
            front.closeSubpath()
        case .topHat:
            detail.addRect(CGRect(x: -12, y: 51 + bob, width: 24, height: 3.5))
            detail.addRect(CGRect(x: -7.5, y: 53 + bob, width: 15, height: 15))
            front.addRect(CGRect(x: -7.5, y: 55 + bob, width: 15, height: 3.5))
        case .propeller:
            back.addArc(center: CGPoint(x: 0, y: 51 + bob), radius: 9.5, startAngle: 0, endAngle: .pi, clockwise: false)
            back.closeSubpath()
            detail.addRect(CGRect(x: -0.8, y: 59 + bob, width: 1.6, height: 5))
            // Pervane kanatları: her karede farklı genişlik, dönüyormuş gibi.
            let spread: CGFloat = [9, 4, 9, 2][step % 4]
            front.addEllipse(in: CGRect(x: -spread, y: 63 + bob, width: spread * 2, height: 3))
        }
        accessoryBack.path = back
        accessoryFront.path = front
        accessoryDetail.path = detail
    }

    /// Eklemsiz "lastik hortum" uzuv: iki uç arasında tek bir yumuşak eğri.
    private func hose(from start: CGPoint, to end: CGPoint, bend: CGFloat) -> CGPath {
        let delta = end - start
        let length = max(0.001, hypot(delta.x, delta.y))
        let normal = CGPoint(x: -delta.y / length, y: delta.x / length)
        let control = (start + end) * 0.5 + normal * bend
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }

    private func ellipse(center: CGPoint, width: CGFloat, height: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height), transform: nil)
    }

    /// 1930'ların "turta göz"ü: dilim çıkarılmış siyah oval.
    private func pieEyes(center: CGPoint) -> CGPath {
        let path = CGMutablePath()
        for offset in [CGFloat(-3.2), 3.2] {
            let transform = CGAffineTransform(translationX: center.x + offset, y: center.y).scaledBy(x: 2.1, y: 3.6)
            path.move(to: .zero, transform: transform)
            path.addArc(center: .zero, radius: 1, startAngle: .pi * 0.15, endAngle: .pi * 1.85, clockwise: false, transform: transform)
            path.closeSubpath()
        }
        return path
    }

    private func steppedScales(_ scales: [(CGFloat, CGFloat)]) -> SKAction {
        var actions: [SKAction] = []
        for (x, y) in scales {
            actions.append(.group([.scaleX(to: x, duration: 0), .scaleY(to: y, duration: 0)]))
            actions.append(.wait(forDuration: 1.0 / 12.0))
        }
        return .sequence(actions)
    }

    private static func limb(width: CGFloat = 3.6) -> SKShapeNode {
        let node = SKShapeNode()
        node.strokeColor = Palette.ink
        node.fillColor = .clear
        node.lineWidth = width
        node.lineCap = .round
        node.isAntialiased = true
        return node
    }

    private static func filled(_ color: SKColor, stroke: Bool = true) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = color
        node.strokeColor = stroke ? Palette.ink : .clear
        node.lineWidth = stroke ? 1.5 : 0
        return node
    }

    private static func glove(_ color: SKColor) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = color
        node.strokeColor = Palette.ink
        node.lineWidth = 1.6
        return node
    }
}

/// Karakter ekranındaki önizleme: tek bir karakter, boşta sallanır.
final class CharacterPreviewScene: SKScene {
    private let character: RubberHoseCharacter
    private var lastTick: TimeInterval = 0
    private var step = 0

    init(character: GameCharacter) {
        self.character = RubberHoseCharacter(style: character.style)
        super.init(size: CGSize(width: 90, height: 100))
        backgroundColor = .clear
        scaleMode = .aspectFit
        self.character.position = CGPoint(x: 45, y: 12)
        self.character.setScale(1.3)
        addChild(self.character)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - lastTick >= 1.0 / 12.0 {
            lastTick = currentTime
            step &+= 1
            character.tick(step: step)
        }
    }
}
