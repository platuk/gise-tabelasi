import SpriteKit
import UIKit
import GameCore

/// Oyunun sahnesi. Kurallar `TowerSimulation`'da; burası yalnızca çizer, dinler ve hissettirir.
///
/// Zaman katmanları:
/// - Fizik: saniyede 120 sabit adım (tutarlı zıplama).
/// - Konum ve kamera: her ekran karesinde akıcı.
/// - Çizim titreşimi, film greni, alev: saniyede 12 kare ("on twos"), elle çizilmiş his için kasıtlı olarak kesik.
final class TowerScene: SKScene {
    /// (puan, ulaşılan kat)
    var onGameOver: ((Int, Int) -> Void)?
    /// Kupa kazanıldığında hemen çağrılır (kayıt noktası kaydı için): kupanın katı.
    var onCheckpoint: ((Int) -> Void)?
    var onAutoJumpChanged: ((Bool) -> Void)?
    /// Açıkken karakter yere değdiği an kendiliğinden zıplar.
    private(set) var autoJump: Bool

    private var sim: TowerSimulation
    private let config: TowerConfig
    private let stepDuration = 1.0 / 120.0
    private let boilInterval = 1.0 / 12.0

    private let cameraNode = SKCameraNode()
    private let world = SKNode()
    private let character = RubberHoseCharacter()
    private let burn: BurnEdge
    private let leftWall = WallNode()
    private let rightWall = WallNode()
    private let hud = HUD()
    private let controls = ControlsOverlay()
    private var filmOverlay: FilmOverlay?
    private var activeCard: SKNode?
    private var cardQueue: [(text: String, big: Bool)] = []
    private var introShown = false
    private var platformNodes: [Int: PlatformNode] = [:]

    private var lastUpdate: TimeInterval = 0
    private var accumulator = 0.0
    private var boilAccumulator = 0.0
    private var boilStep = 0
    private var cameraY: Double = 0
    private var cameraReady = false
    private var weave = CGPoint.zero
    private var shakeOffsets: [CGPoint] = []
    private var touchRoles: [ObjectIdentifier: ControlRole] = [:]
    private var pendingJump = false
    private var gameOverSent = false
    private let haptics = Haptics()

    init(seed: UInt64, startFloor: Int, autoJump: Bool) {
        let config = TowerConfig()
        self.config = config
        self.autoJump = autoJump
        self.sim = TowerSimulation(config: config, seed: seed, startFloor: startFloor)
        self.burn = BurnEdge(width: CGFloat(config.worldWidth))
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        backgroundColor = Palette.paper
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    // MARK: Kurulum

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        if world.parent == nil {
            addChild(world)
            addChild(cameraNode)
            camera = cameraNode
            world.addChild(leftWall)
            world.addChild(rightWall)
            world.addChild(character)
            world.addChild(burn)
            leftWall.zPosition = 5
            rightWall.zPosition = 5
            character.zPosition = 10
            burn.zPosition = 20
            burn.isHidden = true
            cameraNode.addChild(controls)
            cameraNode.addChild(hud)
            controls.zPosition = 600
            hud.zPosition = 700
            controls.setAuto(autoJump)
        }
        layoutScene()
        syncNodes()
        if !introShown {
            introShown = true
            showTitleCard(chapterTitle(forFloor: sim.startFloor), big: true)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutScene()
    }

    /// Görünen dünya yüksekliği (dünya birimi). Genişlik her zaman `worldWidth`.
    private var visibleHeight: Double {
        guard size.width > 0 else { return 800 }
        return config.worldWidth * Double(size.height / size.width)
    }

    private func layoutScene() {
        guard size.width > 0, size.height > 0 else { return }
        // Kamera ölçeği: ekran ne olursa olsun dünya genişliği tam sığar.
        cameraNode.setScale(CGFloat(config.worldWidth) / size.width)

        filmOverlay?.removeFromParent()
        let film = FilmOverlay(size: size)
        film.zPosition = 1000
        cameraNode.addChild(film)
        filmOverlay = film

        let insets = view?.safeAreaInsets ?? .zero
        hud.layout(in: size, topInset: insets.top)
        controls.layout(in: size, bottomInset: insets.bottom)

        let wallHeight = CGFloat(visibleHeight) + 200
        leftWall.configure(width: CGFloat(config.wallThickness), height: wallHeight)
        rightWall.configure(width: CGFloat(config.wallThickness), height: wallHeight)

        if !cameraReady {
            cameraY = visibleHeight / 2 - 40
            cameraReady = true
        }
    }

    // MARK: Döngü

    override func update(_ currentTime: TimeInterval) {
        let frameDt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime

        let roles = Set(touchRoles.values)
        let direction = (roles.contains(.right) ? 1 : 0) - (roles.contains(.left) ? 1 : 0)

        accumulator += frameDt
        while accumulator >= stepDuration {
            let jump = pendingJump || (autoJump && sim.isGrounded)
            let events = sim.step(dt: stepDuration, input: TowerInput(direction: direction, jump: jump))
            pendingJump = false
            handle(events)
            accumulator -= stepDuration
        }

        boilAccumulator += frameDt
        if boilAccumulator >= boilInterval {
            boilAccumulator = boilAccumulator.truncatingRemainder(dividingBy: boilInterval)
            boilStep &+= 1
            onBoilTick()
        }

        updateCamera(frameDt)
        syncNodes()
    }

    private func onBoilTick() {
        character.tick(step: boilStep)
        if sim.burnActive {
            burn.redraw(step: boilStep)
        }
        filmOverlay?.setStep(boilStep)
        // Film makinesindeki hafif kare kayması ("gate weave") ve varsa sarsıntı.
        weave = CGPoint(x: boilJitter(step: boilStep, index: 900, amount: 0.9),
                        y: boilJitter(step: boilStep, index: 901, amount: 0.9))
        if !shakeOffsets.isEmpty {
            weave = weave + shakeOffsets.removeFirst()
        }
    }

    private func updateCamera(_ dt: Double) {
        let height = visibleHeight
        var target = max(sim.y + height * 0.1, height / 2 - 40)
        if sim.burnActive {
            target = max(target, sim.burnY + height / 2 - 140)
        }
        cameraY += (target - cameraY) * min(1, dt * 5)
        cameraNode.position = CGPoint(x: CGFloat(config.worldWidth / 2) + weave.x, y: CGFloat(cameraY) + weave.y)
    }

    private func syncNodes() {
        character.position = CGPoint(x: sim.x, y: sim.y)
        character.update(vx: sim.vx, vy: sim.vy, grounded: sim.isGrounded, facing: sim.facing)

        burn.isHidden = !sim.burnActive
        burn.position = CGPoint(x: 0, y: sim.burnY)

        leftWall.position = CGPoint(x: config.wallThickness / 2, y: cameraY)
        rightWall.position = CGPoint(x: config.worldWidth - config.wallThickness / 2, y: cameraY)
        leftWall.scroll(cameraY: cameraY)
        rightWall.scroll(cameraY: cameraY)

        updatePlatforms()

        let comboFraction = sim.combo.map { $0.timeLeft / config.comboWindow }
        hud.update(floor: sim.highestFloor, score: sim.score, comboFraction: comboFraction)
        backgroundColor = Palette.sky(forHeight: sim.y)
    }

    private func updatePlatforms() {
        let height = visibleHeight
        let low = max(0, Int(((cameraY - height / 2) / config.floorSpacing).rounded(.down)) - 1)
        let high = max(low, Int(((cameraY + height / 2) / config.floorSpacing).rounded(.up)) + 1)
        for floor in Array(platformNodes.keys) where floor < low || floor > high {
            platformNodes[floor]?.removeFromParent()
            platformNodes[floor] = nil
        }
        for floor in low...high where platformNodes[floor] == nil {
            let node = PlatformNode(platform: sim.platform(floor: floor))
            node.zPosition = 2
            world.addChild(node)
            platformNodes[floor] = node
        }
        // Kayan kirişler her karede anlık konumlarına taşınır.
        for (floor, node) in platformNodes where node.isSliding {
            let bounds = sim.bounds(floor: floor)
            node.position.x = CGFloat((bounds.minX + bounds.maxX) / 2)
        }
    }

    private func chapterTitle(forFloor floor: Int) -> String {
        let chapter = config.chapter(forFloor: floor)
        let name: String
        switch chapter {
        case 0: name = String(localized: "chapter.steel")
        case 1: name = String(localized: "chapter.sliding")
        case 2: name = String(localized: "chapter.slippery")
        default: name = String(localized: "chapter.mixed")
        }
        return String(localized: "card.chapter \(chapter + 1) \(name)")
    }

    // MARK: Olaylar

    private func handle(_ events: [TowerEvent]) {
        for event in events {
            switch event {
            case .jumped(let power):
                character.playJump(power: power)
                haptics.impact(.light)
            case .landed(_, let climbed):
                character.playLand()
                spawnDust(at: CGPoint(x: sim.x, y: sim.y))
                haptics.impact(climbed >= 2 ? .medium : .soft)
            case .wallBounce(let side):
                let x = side > 0 ? config.playMaxX : config.playMinX
                spawnStars(at: CGPoint(x: x, y: sim.y + 24))
                haptics.impact(.rigid)
            case .comboExtended(let jumps, let floors):
                hud.showCombo(jumps: jumps, floors: floors)
            case .comboEnded(_, let floors, let points):
                hud.hideCombo()
                if points > 0 {
                    showTitleCard(String(localized: "card.combo \(floors)"), big: floors >= 10)
                    haptics.notify(.success)
                    if floors >= 10 { shake() }
                }
            case .newMilestone(let floor):
                showTitleCard(String(localized: "card.milestone \(floor)"), big: false)
            case .trophyEarned(let floor):
                if let tier = TrophyTier(checkpointFloor: floor) {
                    showTitleCard(String(localized: "card.trophy \(tier.name)"), big: true)
                    spawnTrophy(tier)
                }
                showTitleCard(chapterTitle(forFloor: floor), big: true)
                haptics.notify(.success)
                shake()
                onCheckpoint?(floor)
            case .burnStarted:
                showTitleCard(String(localized: "card.burn"), big: true)
                haptics.notify(.warning)
            case .died:
                gameOver()
            }
        }
    }

    // MARK: Efektler

    /// 1930'lar ara yazı kartı: kesik (12 fps) büyüme, kısa bekleme, solma.
    /// Kartlar sıraya girer; biri bitmeden diğeri gösterilmez.
    private func showTitleCard(_ text: String, big: Bool) {
        if cardQueue.count >= 4 { cardQueue.removeFirst() }
        cardQueue.append((text: text, big: big))
        if activeCard == nil { presentNextCard() }
    }

    private func presentNextCard() {
        guard !cardQueue.isEmpty else {
            activeCard = nil
            return
        }
        let (text, big) = cardQueue.removeFirst()
        let card = SKNode()
        let label = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
        label.text = text
        label.fontSize = big ? 28 : 22
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        let width = label.frame.width + 44
        let height = label.frame.height + 30
        let plate = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 10)
        plate.fillColor = Palette.cream
        plate.strokeColor = Palette.ink
        plate.lineWidth = 4
        let inner = SKShapeNode(rectOf: CGSize(width: width - 12, height: height - 12), cornerRadius: 6)
        inner.fillColor = .clear
        inner.strokeColor = Palette.ink
        inner.lineWidth = 1.5
        card.addChild(plate)
        card.addChild(inner)
        card.addChild(label)
        card.position = CGPoint(x: 0, y: size.height * 0.16)
        card.zPosition = 800
        card.setScale(0.3)
        cameraNode.addChild(card)
        activeCard = card

        let tick = 1.0 / 12.0
        card.run(.sequence([
            .wait(forDuration: tick), .scale(to: 0.7, duration: 0),
            .wait(forDuration: tick), .scale(to: 1.15, duration: 0),
            .wait(forDuration: tick), .scale(to: 0.95, duration: 0),
            .wait(forDuration: tick), .scale(to: 1.0, duration: 0),
            .wait(forDuration: big ? 1.3 : 0.9),
            .fadeOut(withDuration: 0.25),
            .run { [weak self] in
                self?.activeCard = nil
                self?.presentNextCard()
            },
            .removeFromParent(),
        ]))
    }

    /// Kazanılan kupa karakterin üstünde belirir, yükselir ve kaybolur.
    private func spawnTrophy(_ tier: TrophyTier) {
        let trophy = TrophyNode(tier: tier, size: 36)
        trophy.position = CGPoint(x: sim.x, y: sim.y + 70)
        trophy.zPosition = 30
        trophy.setScale(0.3)
        world.addChild(trophy)
        let tick = 1.0 / 12.0
        trophy.run(.sequence([
            .scale(to: 0.8, duration: 0), .wait(forDuration: tick),
            .scale(to: 1.3, duration: 0), .wait(forDuration: tick),
            .scale(to: 1.1, duration: 0), .wait(forDuration: tick),
            .group([.moveBy(x: 0, y: 60, duration: 1.0), .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }

    private func spawnDust(at point: CGPoint) {
        for index in 0..<4 {
            let puff = SKShapeNode(circleOfRadius: 4)
            puff.fillColor = Palette.cream
            puff.strokeColor = Palette.ink
            puff.lineWidth = 1.5
            let side: CGFloat = index < 2 ? -1 : 1
            puff.position = CGPoint(x: point.x + side * CGFloat(6 + (index % 2) * 6), y: point.y + 3)
            puff.zPosition = 9
            world.addChild(puff)
            puff.run(.sequence([
                .group([.moveBy(x: side * 12, y: 5, duration: 0.25), .scale(to: 1.9, duration: 0.25)]),
                .fadeOut(withDuration: 0.12),
                .removeFromParent(),
            ]))
        }
    }

    private func spawnStars(at point: CGPoint) {
        for index in 0..<3 {
            let star = SKShapeNode(path: Self.starPath(radius: 6))
            star.fillColor = Palette.flameCore
            star.strokeColor = Palette.ink
            star.lineWidth = 1.5
            star.position = point
            star.zPosition = 11
            world.addChild(star)
            let angle = CGFloat(index - 1) * 0.6 + (point.x < CGFloat(config.worldWidth / 2) ? 0 : .pi)
            star.run(.sequence([
                .group([.moveBy(x: cos(angle) * 22, y: sin(angle) * 22 + 6, duration: 0.3), .rotate(byAngle: 2, duration: 0.3)]),
                .fadeOut(withDuration: 0.1),
                .removeFromParent(),
            ]))
        }
    }

    private func shake() {
        shakeOffsets = [CGPoint(x: 6, y: -4), CGPoint(x: -5, y: 3), CGPoint(x: 3, y: -2), CGPoint(x: -1, y: 1)]
    }

    private static func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let r = index % 2 == 0 ? radius : radius * 0.4
            let point = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: Oyun sonu

    /// Klasik "iris" kapanışı: karakterin etrafında daralan siyah daire, sonra sonuç ekranı.
    private func gameOver() {
        guard !gameOverSent else { return }
        gameOverSent = true
        touchRoles.removeAll()
        controls.highlight([])
        haptics.notify(.error)

        let iris = SKShapeNode()
        iris.strokeColor = Palette.ink
        iris.fillColor = .clear
        iris.lineWidth = 4000
        iris.zPosition = 2000
        iris.position = cameraNode.convert(character.position + CGPoint(x: 0, y: 24), from: world)
        cameraNode.addChild(iris)

        let maxRadius = hypot(size.width, size.height)
        var actions: [SKAction] = []
        let frames = 9
        for frame in 0...frames {
            let radius = maxRadius * CGFloat(1 - Double(frame) / Double(frames))
            let outer = radius + 2000
            actions.append(.run {
                iris.path = CGPath(ellipseIn: CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2), transform: nil)
            })
            actions.append(.wait(forDuration: 1.0 / 12.0))
        }
        let score = sim.score
        let floor = sim.highestFloor
        actions.append(.run { [weak self] in self?.onGameOver?(score, floor) })
        iris.run(.sequence(actions))
    }

    // MARK: Dokunma

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !sim.isDead else { return }
        for touch in touches {
            let point = touch.location(in: cameraNode)
            if controls.isAutoButton(point) {
                autoJump.toggle()
                controls.setAuto(autoJump)
                haptics.impact(.light)
                onAutoJumpChanged?(autoJump)
                continue
            }
            let role = controlRole(for: point)
            touchRoles[ObjectIdentifier(touch)] = role
            if role == .jump {
                pendingJump = true
            }
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard let current = touchRoles[key], current != .jump else { continue }
            let point = touch.location(in: cameraNode)
            // Yön parmağı sol yarıda kaydıkça sol/sağ arasında geçebilir; zıplamaya dönüşmez.
            touchRoles[key] = point.x < -size.width / 4 ? .left : .right
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            touchRoles[ObjectIdentifier(touch)] = nil
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func controlRole(for point: CGPoint) -> ControlRole {
        if point.x >= 0 { return .jump }
        return point.x < -size.width / 4 ? .left : .right
    }
}

/// Dokunsal geri bildirim.
@MainActor
final class Haptics {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
