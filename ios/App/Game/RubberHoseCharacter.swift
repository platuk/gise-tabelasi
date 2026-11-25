import SpriteKit

/// 1930'lar "lastik hortum" tarzı özgün karakter: eklemsiz, eğri uzuvlar, manşetli iri eldivenler, iri ayakkabılar.
///
/// Animasyon ilkeleri (elle çizilmiş his):
/// - Saniyede 12 çizim ("on twos"); her çizimde küçük titreme ("kaynayan çizgi").
/// - Koşu: 8 anahtar çizimli döngü (değme, çökme, geçiş, yükselme), gövde iner kalkar, hızlanınca öne eğilir.
/// - Hazırlık ve takip: iniş ezilmesi, zıplama uzaması, kulak ve kuyruk hareketin gerisinden gelir.
/// - Havada: yükselirken toplanır, tepede açılır, düşerken kollarını yel değirmeni gibi çevirir.
/// - Yüz: göz kırpma, bakış yönü, korku, sevinç, acı ifadeleri.
/// Orijin: ayakların ortası.
final class RubberHoseCharacter: SKNode {
    private let style: CharacterStyle
    private let facingNode = SKNode()
    /// Takla için: gövdenin ortasında döner.
    private let spinNode = SKNode()
    private let squashNode = SKNode()

    private let speedLines = RubberHoseCharacter.limb(width: 1.6)
    private let tail = RubberHoseCharacter.limb(width: 3.4)
    private let tailTip: SKShapeNode
    private let legBack = RubberHoseCharacter.limb()
    private let legFront = RubberHoseCharacter.limb()
    private let armBack = RubberHoseCharacter.limb()
    private let armFront = RubberHoseCharacter.limb()
    private let shoeBack: SKShapeNode
    private let shoeFront: SKShapeNode
    private let shineBack = RubberHoseCharacter.filled(.white, stroke: false)
    private let shineFront = RubberHoseCharacter.filled(.white, stroke: false)
    private let gloveBack: SKShapeNode
    private let gloveFront: SKShapeNode
    private let cuffBack: SKShapeNode
    private let cuffFront: SKShapeNode
    private let body: SKShapeNode
    private let buttons = RubberHoseCharacter.filled(Palette.milestone, stroke: true, width: 0.8)
    private let bowTie: SKShapeNode
    private let head: SKShapeNode
    private let face: SKShapeNode
    private let eyeWhites = RubberHoseCharacter.filled(.white, stroke: true, width: 1.4)
    private let pupils = RubberHoseCharacter.filled(Palette.ink, stroke: false)
    private let brows = RubberHoseCharacter.limb(width: 1.6)
    private let nose = RubberHoseCharacter.filled(Palette.ink, stroke: false)
    private let mouth = RubberHoseCharacter.filled(SKColor(red: 0.35, green: 0.08, blue: 0.08, alpha: 1), stroke: true, width: 1.4)
    private let accessoryBack: SKShapeNode
    private let accessoryFront: SKShapeNode
    private let accessoryDetail: SKShapeNode

    private var vx = 0.0
    private var vy = 0.0
    private var grounded = true
    private var runPhase = 0.0
    private var step = 0
    /// Takip için yumuşatılmış hız (kulak, kuyruk).
    private var lagVX = 0.0
    private var lagVY = 0.0
    private var celebrateTicks = 0
    private var hurtTicks = 0
    /// Yanan film çok yakın: korku ifadesi.
    var isScared = false

    private enum Expression { case normal, determined, scared, happy, hurt }

    init(style: CharacterStyle) {
        self.style = style
        shoeBack = RubberHoseCharacter.filled(style.shoes, width: 2)
        shoeFront = RubberHoseCharacter.filled(style.shoes, width: 2)
        gloveBack = RubberHoseCharacter.filled(style.gloves, width: 1.8)
        gloveFront = RubberHoseCharacter.filled(style.gloves, width: 1.8)
        cuffBack = RubberHoseCharacter.filled(style.gloves, width: 1.4)
        cuffFront = RubberHoseCharacter.filled(style.gloves, width: 1.4)
        body = RubberHoseCharacter.filled(style.body, width: 2.2)
        head = RubberHoseCharacter.filled(style.head, width: 2.2)
        face = RubberHoseCharacter.filled(style.face, stroke: false)
        tailTip = RubberHoseCharacter.filled(style.body, width: 1.4)
        bowTie = RubberHoseCharacter.filled(style.accent, width: 1.2)
        accessoryBack = RubberHoseCharacter.filled(style.accent, width: 1.8)
        accessoryFront = RubberHoseCharacter.filled(style.accent, width: 1.8)
        accessoryDetail = RubberHoseCharacter.filled(Palette.ink, width: 1.2)
        super.init()
        alpha = style.alpha
        tail.strokeColor = Palette.ink
        speedLines.alpha = 0.55
        addChild(facingNode)
        facingNode.addChild(spinNode)
        spinNode.position = CGPoint(x: 0, y: 24)
        spinNode.addChild(squashNode)
        squashNode.position = CGPoint(x: 0, y: -24)
        // Çizim sırası: arkadakiler önce.
        for node in [speedLines, accessoryBack, tail, tailTip, legBack, shoeBack, shineBack, armBack, cuffBack, gloveBack,
                     body, buttons, bowTie, head, face, eyeWhites, pupils, brows, nose, mouth,
                     accessoryFront, accessoryDetail, legFront, shoeFront, shineFront, armFront, cuffFront, gloveFront] {
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
            // Hızla orantılı esneme: hızlı yükselişte ince uzun, tepede yuvarlak.
            let stretch = CGFloat(max(-0.1, min(0.22, abs(vy) / 4200)))
            squashNode.yScale = 1 + stretch
            squashNode.xScale = 1 - stretch * 0.55
        }
    }

    /// Saniyede 12 kez çağrılır.
    func tick(step: Int) {
        self.step = step
        if grounded {
            // 8 çizimlik adım döngüsü; hız arttıkça çizimler daha sık değişir.
            runPhase += min(2, abs(vx) / 540 * 1.6)
        }
        lagVX += (vx - lagVX) * 0.35
        lagVY += (vy - lagVY) * 0.35
        celebrateTicks = max(0, celebrateTicks - 1)
        hurtTicks = max(0, hurtTicks - 1)
        redraw()
    }

    func playJump(power: Double) {
        squashNode.removeAction(forKey: "land")
        let stretch = CGFloat(0.2 + 0.16 * power)
        // Çıkış: ince uzun "smear" karesi, sonra normale dönüş.
        squashNode.run(steppedScales([(1 - stretch * 0.6, 1 + stretch), (0.92, 1.1)]), withKey: "jump")
    }

    func playLand() {
        squashNode.removeAction(forKey: "jump")
        squashNode.run(steppedScales([(1.38, 0.66), (1.14, 0.86), (0.96, 1.05), (1, 1)]), withKey: "land")
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

    /// Kupa, kombo, zafer: kollar havada, sevinçli yüz.
    func playCelebrate() {
        celebrateTicks = 14
    }

    /// Vurulunca: yüz buruşur, baş sallanır.
    func playHurt() {
        hurtTicks = 8
    }

    // MARK: Pozlar

    private struct Pose {
        var footBack: CGPoint
        var footFront: CGPoint
        var handBack: CGPoint
        var handFront: CGPoint
        var legBend: CGFloat
        var armBend: CGFloat
        var bob: CGFloat
        var lean: CGFloat
        var expression: Expression
    }

    /// Koşu döngüsünün 8 çizimi (ön ayak). Arka ayak yarım döngü geride.
    private static let runFeet: [(CGFloat, CGFloat)] = [
        (11, 1), (6, 0), (0, 0), (-6, 0), (-11, 2), (-6, 8), (2, 10), (9, 5),
    ]
    private static let runBob: [CGFloat] = [0, -1.8, 0, 1.6, 0, -1.8, 0, 1.6]

    private func currentPose() -> Pose {
        let speed = abs(vx)
        if hurtTicks > 0 {
            let shake: CGFloat = step % 2 == 0 ? 2 : -2
            return Pose(footBack: CGPoint(x: -7, y: 0), footFront: CGPoint(x: 7, y: 0),
                        handBack: CGPoint(x: -15 + shake, y: 34), handFront: CGPoint(x: 15 + shake, y: 36),
                        legBend: 3, armBend: 5, bob: 0, lean: shake, expression: .hurt)
        }
        if celebrateTicks > 0 {
            let hop: CGFloat = grounded && celebrateTicks % 4 < 2 ? 3 : 0
            return Pose(footBack: CGPoint(x: -7, y: hop), footFront: CGPoint(x: 8, y: hop + 2),
                        handBack: CGPoint(x: -15, y: 54 + hop), handFront: CGPoint(x: 16, y: 55 + hop),
                        legBend: 3, armBend: -6, bob: hop, lean: 0, expression: .happy)
        }
        if !grounded {
            let scared = isScared || vy < -1100
            if vy > 300 {
                // Yükseliş: toplanmış bacaklar, kollar yukarı.
                return Pose(footBack: CGPoint(x: -6, y: 9), footFront: CGPoint(x: 8, y: 12),
                            handBack: CGPoint(x: -13, y: 50), handFront: CGPoint(x: 13, y: 53),
                            legBend: 6, armBend: -6, bob: 0, lean: 1, expression: scared ? .scared : .determined)
            }
            if vy > -300 {
                // Tepe: açılır, bir an asılı kalır.
                return Pose(footBack: CGPoint(x: -10, y: 3), footFront: CGPoint(x: 11, y: 5),
                            handBack: CGPoint(x: -19, y: 40), handFront: CGPoint(x: 19, y: 43),
                            legBend: -4, armBend: 6, bob: 0, lean: 0, expression: scared ? .scared : .normal)
            }
            // Düşüş: yel değirmeni kollar, bisiklet bacaklar.
            let flip = step % 2 == 0
            return Pose(footBack: CGPoint(x: flip ? -9 : -4, y: flip ? 0 : 6), footFront: CGPoint(x: flip ? 5 : 10, y: flip ? 6 : 0),
                        handBack: CGPoint(x: flip ? -19 : -14, y: flip ? 46 : 30), handFront: CGPoint(x: flip ? 15 : 19, y: flip ? 30 : 46),
                        legBend: -3, armBend: 7, bob: 0, lean: 0, expression: scared ? .scared : .normal)
        }
        if speed > 30 {
            let frame = Int(runPhase) % 8
            let back = (frame + 4) % 8
            let f = Self.runFeet[frame]
            let b = Self.runFeet[back]
            let lean = CGFloat(min(1, speed / 540)) * 3
            return Pose(footBack: CGPoint(x: b.0, y: b.1), footFront: CGPoint(x: f.0, y: f.1),
                        // Kollar bacakların tersine sallanır.
                        handBack: CGPoint(x: f.0 * 0.9 - 2 + lean, y: 21 + f.1 * 0.4),
                        handFront: CGPoint(x: b.0 * 0.9 + 3 + lean, y: 21 + b.1 * 0.4),
                        legBend: 4, armBend: -5, bob: Self.runBob[frame], lean: lean,
                        expression: isScared ? .scared : (speed > 380 ? .determined : .normal))
        }
        // Boşta: eller belde, müzikle hafifçe sallanır, ön ayak tempo tutar.
        let beat = step % 6
        let tap: CGFloat = beat < 2 ? 2.5 : 0
        return Pose(footBack: CGPoint(x: -6, y: 0), footFront: CGPoint(x: 7 + tap * 0.4, y: tap),
                    handBack: CGPoint(x: -13, y: 19), handFront: CGPoint(x: 13, y: 19),
                    legBend: 2, armBend: 9, bob: beat < 3 ? 1.2 : 0, lean: 0,
                    expression: isScared ? .scared : .normal)
    }

    // MARK: Çizim

    private func redraw() {
        let pose = currentPose()
        let j = { (index: Int) -> CGFloat in boilJitter(step: self.step, index: index, amount: 0.6) }
        let bob = pose.bob
        let hs = style.headScale
        let bw = style.bodyWidth
        let bh = style.bodyHeight
        let lean = pose.lean
        let bodyCenter = CGPoint(x: lean * 0.4 + j(13), y: 13 + bh / 2 + bob)
        let headCenter = CGPoint(x: lean + j(15), y: bodyCenter.y + bh / 2 + 9 * hs)

        let hipBack = CGPoint(x: -bw * 0.2 + j(1), y: 15 + bob)
        let hipFront = CGPoint(x: bw * 0.2 + j(2), y: 15 + bob)
        let shoulderY = bodyCenter.y + bh * 0.22
        let shoulderBack = CGPoint(x: -bw * 0.32 + lean * 0.6 + j(3), y: shoulderY)
        let shoulderFront = CGPoint(x: bw * 0.32 + lean * 0.6 + j(4), y: shoulderY)

        legBack.path = hose(from: hipBack, to: pose.footBack + CGPoint(x: 0, y: 3), bend: pose.legBend + j(5))
        legFront.path = hose(from: hipFront, to: pose.footFront + CGPoint(x: 0, y: 3), bend: pose.legBend + j(6))
        armBack.path = hose(from: shoulderBack, to: pose.handBack, bend: pose.armBend + j(7))
        armFront.path = hose(from: shoulderFront, to: pose.handFront, bend: pose.armBend + j(8))

        // İri ayakkabılar: burnu kalkık, parlak.
        shoeBack.path = shoe(at: pose.footBack, jitter: j(9))
        shoeFront.path = shoe(at: pose.footFront, jitter: j(10))
        shineBack.path = ellipse(center: pose.footBack + CGPoint(x: 6, y: 4.5), width: 3.5, height: 2)
        shineFront.path = ellipse(center: pose.footFront + CGPoint(x: 6, y: 4.5), width: 3.5, height: 2)

        // Manşetli eldivenler, bileğe doğru dönük.
        let back = glove(hand: pose.handBack, from: shoulderBack, jitter: j(11))
        gloveBack.path = back.0
        cuffBack.path = back.1
        let front = glove(hand: pose.handFront, from: shoulderFront, jitter: j(12))
        gloveFront.path = front.0
        cuffFront.path = front.1

        body.path = ellipse(center: bodyCenter, width: bw + j(14), height: bh)
        if style.buttons {
            let path = CGMutablePath()
            for dy in [CGFloat(3), -3.5] {
                path.addEllipse(in: CGRect(x: bodyCenter.x + bw * 0.22 - 1.6, y: bodyCenter.y + dy - 1.6, width: 3.2, height: 3.2))
            }
            buttons.path = path
        }
        if style.bowTie {
            let knot = CGPoint(x: headCenter.x + 2, y: bodyCenter.y + bh / 2 - 1)
            let path = CGMutablePath()
            path.addLines(between: [knot, knot + CGPoint(x: -6, y: 3.5), knot + CGPoint(x: -6, y: -3.5)])
            path.closeSubpath()
            path.addLines(between: [knot, knot + CGPoint(x: 6, y: 3.5), knot + CGPoint(x: 6, y: -3.5)])
            path.closeSubpath()
            bowTie.path = path
        }

        head.path = ellipse(center: headCenter, width: (25 + j(16)) * hs, height: 23 * hs)
        face.path = ellipse(center: headCenter + CGPoint(x: 3.5 * hs + j(17), y: -1.5 * hs), width: 16 * hs, height: 15 * hs)
        drawFace(center: headCenter, expression: pose.expression)
        drawTail(bodyCenter: bodyCenter)
        drawSpeedLines()
        drawAccessory(head: headCenter + CGPoint(x: 0, y: j(21) * 0.5))
    }

    /// Gözler (beyaz, turta kesikli göz bebeği), kaşlar, burun, ağız. Baş 3/4 görünümde: yüz öne dönük.
    private func drawFace(center: CGPoint, expression: Expression) {
        let hs = style.headScale
        let eyeY = center.y + 3.5 * hs
        let eyeXs = [center.x + 0.5 * hs, center.x + 7.5 * hs]
        let blink = step % 41 == 0 || step % 41 == 1 && step % 82 < 41
        let whites = CGMutablePath()
        let pupilPath = CGMutablePath()
        let browPath = CGMutablePath()
        // Bakış: gidilen yöne, düşerken aşağı, yükselirken yukarı.
        let lookX = CGFloat(max(-1, min(1, abs(vx) / 300))) * 1.3 + 0.4
        let lookY = CGFloat(max(-1, min(1, vy / 900))) * 1.4
        let eyeHeight: CGFloat = expression == .scared ? 10.5 : 9
        for (index, x) in eyeXs.enumerated() {
            let rect = CGRect(x: x - 3.3 * hs, y: eyeY - eyeHeight / 2 * hs, width: 6.6 * hs, height: eyeHeight * hs)
            if blink || expression == .hurt || expression == .happy {
                // Kapalı göz: kavis (mutlu ∩, acı ×).
                let line = CGMutablePath()
                if expression == .hurt {
                    line.move(to: CGPoint(x: rect.minX + 1, y: rect.midY + 2))
                    line.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.midY - 2))
                    line.move(to: CGPoint(x: rect.minX + 1, y: rect.midY - 2))
                    line.addLine(to: CGPoint(x: rect.maxX - 1, y: rect.midY + 2))
                } else if expression == .happy {
                    line.move(to: CGPoint(x: rect.minX, y: rect.midY - 1))
                    line.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY - 1), control: CGPoint(x: rect.midX, y: rect.midY + 4))
                } else {
                    line.move(to: CGPoint(x: rect.minX, y: rect.midY))
                    line.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                }
                browPath.addPath(line)
            } else {
                whites.addEllipse(in: rect)
                let size: CGFloat = expression == .scared ? 2.2 : 3
                let pupilCenter = CGPoint(x: rect.midX + lookX, y: rect.midY + lookY - 0.5)
                let transform = CGAffineTransform(translationX: pupilCenter.x, y: pupilCenter.y).scaledBy(x: size * 0.55 * hs, y: size * hs)
                pupilPath.move(to: .zero, transform: transform)
                pupilPath.addArc(center: .zero, radius: 1, startAngle: .pi * 0.2, endAngle: .pi * 1.8, clockwise: false, transform: transform)
                pupilPath.closeSubpath()
            }
            // Kaşlar ifadeyi taşır.
            let top = rect.maxY + 1.6
            let inner = index == 0 ? rect.maxX : rect.minX
            let outer = index == 0 ? rect.minX : rect.maxX
            switch expression {
            case .determined:
                browPath.move(to: CGPoint(x: outer, y: top + 1.5))
                browPath.addLine(to: CGPoint(x: inner, y: top - 1))
            case .scared:
                browPath.move(to: CGPoint(x: outer, y: top + 0.5))
                browPath.addLine(to: CGPoint(x: inner, y: top + 3))
            case .happy:
                browPath.move(to: CGPoint(x: outer, y: top + 1))
                browPath.addQuadCurve(to: CGPoint(x: inner, y: top + 1), control: CGPoint(x: (inner + outer) / 2, y: top + 3))
            default:
                break
            }
        }
        eyeWhites.path = whites
        pupils.path = pupilPath
        brows.path = browPath
        nose.path = ellipse(center: CGPoint(x: center.x + 11 * hs, y: center.y - 1 * hs), width: 5.5 * hs, height: 4.2 * hs)

        let m = CGPoint(x: center.x + 6 * hs, y: center.y - 5.5 * hs)
        let mouthPath = CGMutablePath()
        switch expression {
        case .scared:
            mouthPath.addEllipse(in: CGRect(x: m.x - 2.2, y: m.y - 3.6, width: 4.4, height: 6))
        case .happy:
            // Kocaman açık gülüş (D).
            mouthPath.move(to: CGPoint(x: m.x - 5, y: m.y + 1.5))
            mouthPath.addQuadCurve(to: CGPoint(x: m.x + 5, y: m.y + 1.5), control: CGPoint(x: m.x, y: m.y - 7))
            mouthPath.closeSubpath()
        case .determined:
            mouthPath.move(to: CGPoint(x: m.x - 4, y: m.y + 0.5))
            mouthPath.addQuadCurve(to: CGPoint(x: m.x + 4, y: m.y + 1.5), control: CGPoint(x: m.x, y: m.y - 2.5))
            mouthPath.closeSubpath()
        case .hurt:
            mouthPath.move(to: CGPoint(x: m.x - 4, y: m.y))
            mouthPath.addLine(to: CGPoint(x: m.x - 1.5, y: m.y + 1.5))
            mouthPath.addLine(to: CGPoint(x: m.x + 1, y: m.y - 1))
            mouthPath.addLine(to: CGPoint(x: m.x + 4, y: m.y + 1))
            mouthPath.addLine(to: CGPoint(x: m.x + 4, y: m.y))
            mouthPath.addLine(to: CGPoint(x: m.x + 1, y: m.y - 2))
            mouthPath.addLine(to: CGPoint(x: m.x - 1.5, y: m.y + 0.5))
            mouthPath.closeSubpath()
        case .normal:
            mouthPath.move(to: CGPoint(x: m.x - 3.5, y: m.y + 1.5))
            mouthPath.addQuadCurve(to: CGPoint(x: m.x + 3.5, y: m.y + 1.5), control: CGPoint(x: m.x, y: m.y - 3.5))
            mouthPath.closeSubpath()
        }
        mouth.path = mouthPath
    }

    /// Kuyruk: gövdenin arkasından çıkar, hızın gerisinden gelir; köpeğinki boşta sallanır.
    private func drawTail(bodyCenter: CGPoint) {
        guard style.tail != .none else { return }
        let base = CGPoint(x: bodyCenter.x - style.bodyWidth * 0.45, y: bodyCenter.y - 4)
        let drag = CGPoint(x: CGFloat(max(-8, min(8, -lagVX / 60))), y: CGFloat(max(-10, min(10, -lagVY / 120))))
        let tip: CGPoint
        let bend: CGFloat
        switch style.tail {
        case .cat:
            tip = base + CGPoint(x: -13, y: 12) + drag
            bend = 9 + boilJitter(step: step, index: 60, amount: 1.5)
        default:
            let wag: CGFloat = grounded && abs(vx) < 30 ? (step % 2 == 0 ? 4 : -4) : 0
            tip = base + CGPoint(x: -9, y: 7 + wag) + drag * 0.6
            bend = 3
        }
        tail.path = hose(from: base, to: tip, bend: bend)
        tailTip.path = ellipse(center: tip, width: style.tail == .cat ? 4 : 5, height: style.tail == .cat ? 4 : 5)
    }

    /// Hız çizgileri: hızlı koşuda arkada, hızlı yükselişte altta.
    private func drawSpeedLines() {
        let path = CGMutablePath()
        if grounded && abs(vx) > 430 {
            for (index, y) in [CGFloat(12), 22, 32].enumerated() {
                let length: CGFloat = 10 + CGFloat((step + index) % 3) * 4
                path.move(to: CGPoint(x: -16, y: y))
                path.addLine(to: CGPoint(x: -16 - length, y: y))
            }
        } else if !grounded && vy > 800 {
            for (index, x) in [CGFloat(-8), 0, 8].enumerated() {
                let length: CGFloat = 10 + CGFloat((step + index) % 3) * 5
                path.move(to: CGPoint(x: x, y: -4))
                path.addLine(to: CGPoint(x: x, y: -4 - length))
            }
        }
        speedLines.path = path
    }

    /// Baş süsleri: komi şapkası, köpek kulağı, kedi kulağı, silindir şapka, pervaneli kasket.
    private func drawAccessory(head c: CGPoint) {
        let hs = style.headScale
        let top = c.y + 11.5 * hs
        let back = CGMutablePath()
        let front = CGMutablePath()
        let detail = CGMutablePath()
        // Kulaklar ve şapka hareketin gerisinden gelir.
        let flap = CGFloat(max(-4, min(4, -lagVY / 250)))
        switch style.accessory {
        case .none:
            break
        case .bellhop:
            // Yan yatık yuvarlak şapka ve çene kayışı.
            let cap = CGRect(x: c.x - 5 * hs, y: top - 2, width: 13 * hs, height: 7.5 * hs)
            let transform = CGAffineTransform(translationX: cap.midX, y: cap.midY).rotated(by: -0.18).translatedBy(x: -cap.midX, y: -cap.midY)
            front.addRoundedRect(in: cap, cornerWidth: 2.5, cornerHeight: 2.5, transform: transform)
            detail.addRect(CGRect(x: cap.minX, y: cap.minY + 1, width: cap.width, height: 1.8), transform: transform)
            back.move(to: CGPoint(x: c.x - 4 * hs, y: top - 1))
            back.addQuadCurve(to: CGPoint(x: c.x + 9 * hs, y: c.y - 8 * hs), control: CGPoint(x: c.x - 6 * hs, y: c.y - 10 * hs))
        case .dogEars:
            back.addEllipse(in: CGRect(x: c.x - 15 * hs, y: c.y - 10 * hs + flap, width: 9 * hs, height: 18 * hs))
            front.addEllipse(in: CGRect(x: c.x + 8 * hs, y: c.y - 10 * hs - flap, width: 9 * hs, height: 18 * hs))
        case .catEars:
            back.addLines(between: [CGPoint(x: c.x - 12 * hs, y: top - 6), CGPoint(x: c.x - 9 * hs, y: top + 7 + flap * 0.3),
                                    CGPoint(x: c.x - 3 * hs, y: top - 1)])
            back.closeSubpath()
            front.addLines(between: [CGPoint(x: c.x + 3 * hs, y: top - 1), CGPoint(x: c.x + 8 * hs, y: top + 7 + flap * 0.3),
                                     CGPoint(x: c.x + 12 * hs, y: top - 6)])
            front.closeSubpath()
            // Bıyıklar
            for dy in [CGFloat(-1), -3.5] {
                detail.addRect(CGRect(x: c.x + 12 * hs, y: c.y + dy * hs - 0.4, width: 6, height: 0.8))
            }
        case .topHat:
            let tilt = flap * 0.4
            detail.addRect(CGRect(x: c.x - 12 * hs, y: top - 1 + tilt, width: 24 * hs, height: 3.5))
            detail.addRect(CGRect(x: c.x - 7.5 * hs, y: top + tilt, width: 15 * hs, height: 15))
            front.addRect(CGRect(x: c.x - 7.5 * hs, y: top + 2.5 + tilt, width: 15 * hs, height: 3.5))
            // Tek gözlük
            back.addEllipse(in: CGRect(x: c.x + 4.3 * hs, y: c.y + 0 * hs, width: 7 * hs, height: 7 * hs))
        case .propeller:
            back.addArc(center: CGPoint(x: c.x, y: top - 2), radius: 10 * hs, startAngle: 0, endAngle: .pi, clockwise: false)
            back.closeSubpath()
            detail.addRect(CGRect(x: c.x - 0.8, y: top + 7 * hs, width: 1.6, height: 5))
            // Pervane: havadayken daha hızlı döner (her karede farklı genişlik).
            let spreads: [CGFloat] = grounded ? [9, 6, 9, 3] : [9, 2, 7, 4]
            let spread = spreads[step % 4]
            front.addEllipse(in: CGRect(x: c.x - spread, y: top + 11 * hs, width: spread * 2, height: 3))
        }
        accessoryBack.path = back
        accessoryFront.path = front
        accessoryDetail.path = detail
        if style.accessory == .topHat {
            accessoryBack.fillColor = .clear
            accessoryBack.strokeColor = Palette.milestone
        }
        if style.accessory == .bellhop {
            accessoryBack.fillColor = .clear
            accessoryDetail.fillColor = Palette.milestone
        }
    }

    // MARK: Yardımcılar

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

    /// Burnu kalkık, iri ayakkabı.
    private func shoe(at foot: CGPoint, jitter: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: foot + CGPoint(x: -5, y: 0))
        path.addLine(to: foot + CGPoint(x: 9 + jitter, y: 0))
        path.addQuadCurve(to: foot + CGPoint(x: 10 + jitter, y: 6), control: foot + CGPoint(x: 13 + jitter, y: 2))
        path.addQuadCurve(to: foot + CGPoint(x: -2, y: 7), control: foot + CGPoint(x: 4, y: 10))
        path.addQuadCurve(to: foot + CGPoint(x: -5, y: 0), control: foot + CGPoint(x: -7, y: 4))
        path.closeSubpath()
        return path
    }

    /// Dört parmaklı izlenimi veren yuvarlak eldiven ve bileğe dönük manşet.
    private func glove(hand: CGPoint, from shoulder: CGPoint, jitter: CGFloat) -> (CGPath, CGPath) {
        let delta = hand - shoulder
        let length = max(0.001, hypot(delta.x, delta.y))
        let dir = CGPoint(x: delta.x / length, y: delta.y / length)
        let normal = CGPoint(x: -dir.y, y: dir.x)
        let palm = hand + dir * 2
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: palm.x - 5.6 - jitter * 0.3, y: palm.y - 5.2, width: 11.2 + jitter * 0.6, height: 10.4))
        let thumb = palm + normal * 5 - dir * 1
        path.addEllipse(in: CGRect(x: thumb.x - 2.4, y: thumb.y - 2.4, width: 4.8, height: 4.8))
        let cuffCenter = hand - dir * 3.5
        let angle = atan2(dir.y, dir.x)
        let transform = CGAffineTransform(translationX: cuffCenter.x, y: cuffCenter.y).rotated(by: angle)
        let cuff = CGMutablePath()
        cuff.addRoundedRect(in: CGRect(x: -2.2, y: -4.4, width: 4.4, height: 8.8), cornerWidth: 1.5, cornerHeight: 1.5, transform: transform)
        return (path, cuff)
    }

    private func steppedScales(_ scales: [(CGFloat, CGFloat)]) -> SKAction {
        var actions: [SKAction] = []
        for (x, y) in scales {
            actions.append(.group([.scaleX(to: x, duration: 0), .scaleY(to: y, duration: 0)]))
            actions.append(.wait(forDuration: 1.0 / 12.0))
        }
        return .sequence(actions)
    }

    private static func limb(width: CGFloat = 3.8) -> SKShapeNode {
        let node = SKShapeNode()
        node.strokeColor = Palette.ink
        node.fillColor = .clear
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.isAntialiased = true
        return node
    }

    private static func filled(_ color: SKColor, stroke: Bool = true, width: CGFloat = 1.5) -> SKShapeNode {
        let node = SKShapeNode()
        node.fillColor = color
        node.strokeColor = stroke ? Palette.ink : .clear
        node.lineWidth = stroke ? width : 0
        node.lineJoin = .round
        return node
    }
}

/// Karakter ekranındaki önizleme: tek bir karakter, boşta sallanır; ara sıra sevinç dansı yapar.
final class CharacterPreviewScene: SKScene {
    private let character: RubberHoseCharacter
    private var lastTick: TimeInterval = 0
    private var step = 0
    private let dances: Bool

    init(character: GameCharacter, dances: Bool = false) {
        self.character = RubberHoseCharacter(style: character.style)
        self.dances = dances
        super.init(size: CGSize(width: 90, height: 100))
        backgroundColor = .clear
        scaleMode = .aspectFit
        self.character.position = CGPoint(x: 45, y: 12)
        self.character.setScale(1.2)
        addChild(self.character)
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - lastTick >= 1.0 / 12.0 {
            lastTick = currentTime
            step &+= 1
            if dances && step % 60 == 30 { character.playCelebrate() }
            character.tick(step: step)
        }
    }
}
