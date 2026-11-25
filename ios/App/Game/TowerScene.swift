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
    /// Boss yenildiğinde: arena katı.
    var onBossDefeated: ((Int) -> Void)?
    /// Açıkken karakter yere değdiği an kendiliğinden zıplar.
    private(set) var autoJump: Bool

    private var sim: TowerSimulation
    private let config: TowerConfig
    private let stepDuration = 1.0 / 120.0
    private let boilInterval = 1.0 / 12.0

    private let cameraNode = SKCameraNode()
    private let world = SKNode()
    private let characterStyle: CharacterStyle
    private let character: RubberHoseCharacter
    private let burn: BurnEdge
    private var bubbleNodes: [Int: BubbleNode] = [:]
    /// Etkin baloncukların karakter üzerindeki görünümü.
    private let shieldRing = SKShapeNode(circleOfRadius: 34)
    private let adrenalineAura = SKShapeNode(circleOfRadius: 26)
    private let boostFlame = SKShapeNode()
    private let slowTint = SKSpriteNode(color: SKColor(red: 0.35, green: 0.45, blue: 0.55, alpha: 1), size: .zero)
    /// Diriliş gösterisi sürerken oyun durur.
    private var isRespawning = false
    private let worldBackground = CartoonWorldBackground()
    private var octopus: OctopusNode?
    private var projectileNodes: [Int: ProjectileNode] = [:]
    private var bossFlashTicks = 0
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
    /// Her parmağın yukarı kaydırma ölçümünün başladığı nokta (ekran noktası).
    private var swipeOrigins: [ObjectIdentifier: CGPoint] = [:]
    private let swipeJumpDistance: CGFloat = 36
    private var pendingJump = false
    private var gameOverSent = false
    private let haptics = Haptics()

    init(seed: UInt64, startFloor: Int, bossAlreadyDefeated: Bool, autoJump: Bool, character: GameCharacter) {
        let config = TowerConfig()
        self.config = config
        self.autoJump = autoJump
        self.characterStyle = character.style
        self.character = RubberHoseCharacter(style: character.style)
        self.sim = TowerSimulation(config: config, seed: seed, startFloor: startFloor, bossAlreadyDefeated: bossAlreadyDefeated)
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

            shieldRing.strokeColor = Palette.slidingBeam
            shieldRing.lineWidth = 4
            shieldRing.fillColor = Palette.slipperyBeam.withAlphaComponent(0.25)
            shieldRing.position = CGPoint(x: 0, y: 24)
            shieldRing.zPosition = 2
            character.addChild(shieldRing)
            adrenalineAura.fillColor = Palette.flame.withAlphaComponent(0.35)
            adrenalineAura.strokeColor = .clear
            adrenalineAura.position = CGPoint(x: 0, y: 24)
            adrenalineAura.zPosition = -1
            character.addChild(adrenalineAura)
            boostFlame.fillColor = Palette.flame
            boostFlame.strokeColor = Palette.ink
            boostFlame.lineWidth = 2
            boostFlame.zPosition = -1
            character.addChild(boostFlame)
            slowTint.alpha = 0
            slowTint.zPosition = 950
            cameraNode.addChild(slowTint)
            // Canlı çizgi film dünyası: her şeyin arkasında, kamera alanında.
            worldBackground.zPosition = -1000
            cameraNode.addChild(worldBackground)
        }
        layoutScene()
        syncNodes()
        if !introShown {
            introShown = true
            if sim.boss != nil {
                showBossIntro()
            } else {
                showTitleCard(chapterTitle(forFloor: sim.startFloor), big: true)
            }
        }
    }

    private func showBossIntro() {
        let name = String(localized: "boss.name")
        showTitleCard(String(localized: "card.bossIntro \(name)"), big: true)
        hud.showBoss(true)
        haptics.notify(.warning)
        shake()
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
        slowTint.size = size
        worldBackground.layout(in: size)

        let insets = view?.safeAreaInsets ?? .zero
        hud.layout(in: size, topInset: insets.top)
        controls.layout(in: size, topInset: insets.top, bottomInset: insets.bottom)

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

        accumulator += isRespawning ? 0 : frameDt
        while accumulator >= stepDuration && !isRespawning {
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
        worldBackground.update(cameraY: cameraY, dt: frameDt, step: boilStep)
    }

    private func onBoilTick() {
        character.tick(step: boilStep)
        if sim.burnActive {
            burn.redraw(step: boilStep)
        }
        filmOverlay?.setStep(boilStep)
        for (floor, bubble) in bubbleNodes {
            bubble.bob(step: boilStep, baseY: CGFloat(Double(floor) * config.floorSpacing + config.bubbleHeight))
        }
        // Roket alevi ve adrenalin halesi de kesik kesik titrer.
        let flicker = boilJitter(step: boilStep, index: 777, amount: 4)
        let flame = CGMutablePath()
        flame.addLines(between: [CGPoint(x: -9, y: 2), CGPoint(x: flicker, y: -34 - abs(flicker) * 3), CGPoint(x: 9, y: 2)])
        flame.closeSubpath()
        boostFlame.path = flame
        adrenalineAura.setScale(boilStep % 2 == 0 ? 1 : 1.12)
        if let fight = sim.boss {
            octopus?.tick(step: boilStep, telegraph: fight.telegraph, phase: fight.phase, flash: bossFlashTicks > 0)
        }
        bossFlashTicks = max(0, bossFlashTicks - 1)
        for node in projectileNodes.values { node.tick(step: boilStep) }
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
        if let fight = sim.boss {
            // Arena: zemin altta, ahtapot üstte, ikisi de ekranda.
            target = Double(fight.arenaFloor) * config.floorSpacing + height * 0.42
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
        updateBubbles()

        // Etkin baloncukların görünümü
        let shield = sim.shieldRemaining
        shieldRing.isHidden = shield <= 0 || (shield < 2 && Int(shield * 6) % 2 == 0)
        adrenalineAura.isHidden = sim.adrenalineRemaining <= 0
        boostFlame.isHidden = sim.boost == nil
        slowTint.alpha = sim.slowRemaining > 0 ? 0.16 : 0

        let comboFraction = sim.combo.map { $0.timeLeft / config.comboWindow }
        hud.update(floor: sim.highestFloor, score: sim.score, comboFraction: comboFraction)
        hud.updatePowerUps([.slowTime: sim.slowRemaining, .adrenaline: sim.adrenalineRemaining, .shield: sim.shieldRemaining])

        // Vurulunca kısa süre yanıp sönme
        character.alpha = sim.hurtTimer > 0 && boilStep % 2 == 0 ? 0.35 : 1
        syncBoss()
    }

    /// Ahtapotu, mermileri ve boss HUD'unu simülasyonla eşitler.
    private func syncBoss() {
        guard let fight = sim.boss else {
            if !projectileNodes.isEmpty {
                for node in projectileNodes.values { node.removeFromParent() }
                projectileNodes.removeAll()
            }
            return
        }
        if octopus == nil {
            let node = OctopusNode()
            node.zPosition = 15
            world.addChild(node)
            octopus = node
        }
        octopus?.position = CGPoint(x: fight.x, y: fight.y)
        hud.updateBoss(hp: fight.hp, maxHP: fight.maxHP, playerHP: sim.playerHP)

        var alive = Set<Int>()
        for shot in sim.enemyShots + sim.playerShots {
            alive.insert(shot.id)
            let node: ProjectileNode
            if let existing = projectileNodes[shot.id] {
                node = existing
            } else {
                node = ProjectileNode(kind: shot.kind, radius: CGFloat(shot.radius))
                node.zPosition = shot.kind == .bullet ? 12 : 16
                world.addChild(node)
                projectileNodes[shot.id] = node
            }
            node.position = CGPoint(x: shot.x, y: shot.y)
            if shot.kind == .wave { node.xScale = shot.vx < 0 ? -1 : 1 }
        }
        for id in Array(projectileNodes.keys) where !alive.contains(id) {
            projectileNodes[id]?.removeFromParent()
            projectileNodes[id] = nil
        }
    }

    /// Görünen katlardaki alınmamış baloncukları gösterir.
    private func updateBubbles() {
        let height = visibleHeight
        let low = max(0, Int(((cameraY - height / 2) / config.floorSpacing).rounded(.down)) - 1)
        let high = max(low, Int(((cameraY + height / 2) / config.floorSpacing).rounded(.up)) + 1)
        for floor in Array(bubbleNodes.keys) where floor < low || floor > high {
            bubbleNodes[floor]?.removeFromParent()
            bubbleNodes[floor] = nil
        }
        let arena = sim.boss?.arenaFloor ?? Int.max
        for (floor, node) in bubbleNodes { node.isHidden = floor >= arena }
        for floor in low...high where bubbleNodes[floor] == nil && !sim.collectedBubbles.contains(floor) {
            let platform = sim.platform(floor: floor)
            guard let kind = platform.bubble else { continue }
            let node = BubbleNode(kind: kind, radius: CGFloat(config.bubbleRadius))
            let position = sim.bubblePosition(of: platform)
            node.position = CGPoint(x: position.x, y: position.y)
            node.zPosition = 8
            world.addChild(node)
            bubbleNodes[floor] = node
        }
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
        // Boss dövüşünde arenanın üstündeki kirişler gizlenir (basılamazlar).
        let arena = sim.boss?.arenaFloor ?? Int.max
        for (floor, node) in platformNodes {
            node.isHidden = floor > arena
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
            case .wallKick(let side):
                // Takla: duvardan uzaklaşan yöne doğru tam tur.
                character.playFlip(towards: -side)
                haptics.impact(.heavy)
            case .powerUp(let kind):
                for (floor, node) in bubbleNodes where sim.collectedBubbles.contains(floor) {
                    node.pop(in: world)
                    bubbleNodes[floor] = nil
                }
                showTitleCard(powerUpTitle(kind), big: kind == .boost)
                haptics.notify(.success)
                if kind == .boost { shake() }
            case .boostFinished:
                character.playLand()
                spawnDust(at: CGPoint(x: sim.x, y: sim.y))
                shake()
            case .shieldSaved:
                showTitleCard(String(localized: "card.shieldSaved"), big: false)
                spawnStars(at: CGPoint(x: sim.x, y: sim.y))
                haptics.impact(.heavy)
            case .respawned:
                break
            case .bossStarted:
                showBossIntro()
            case .bossAttackWarning:
                haptics.impact(.light)
            case .bossAttack(let attack):
                if attack == .wave || attack == .rain { shake() }
            case .bossHit:
                bossFlashTicks = 1
            case .playerHit:
                haptics.notify(.error)
                shake()
                spawnStars(at: CGPoint(x: sim.x, y: sim.y + 30))
            case .bossDefeated(_, let floor):
                if let node = octopus {
                    node.playDefeat(in: world)
                    octopus = nil
                }
                hud.showBoss(false)
                showTitleCard(String(localized: "card.bossDefeated"), big: true)
                showTitleCard(String(localized: "card.bossReward \(bossRewardCups)"), big: false)
                showTitleCard(chapterTitle(forFloor: floor + 1), big: true)
                haptics.notify(.success)
                shake()
                onBossDefeated?(floor)
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
                // Boss katında bölüm kartı zaferden sonra gelir.
                if !config.isBossFloor(floor) {
                    showTitleCard(chapterTitle(forFloor: floor), big: true)
                }
                haptics.notify(.success)
                shake()
                onCheckpoint?(floor)
            case .burnStarted:
                showTitleCard(String(localized: "card.burn"), big: true)
                haptics.notify(.warning)
            case .died:
                if sim.canRespawn {
                    playRespawn()
                } else {
                    gameOver()
                }
            }
        }
    }

    /// Boss yenilince cüzdana eklenen kupa sayısı (RootView aynı değeri kullanır).
    static let bossRewardCups = 3
    private var bossRewardCups: Int { Self.bossRewardCups }

    private func powerUpTitle(_ kind: PowerUp) -> String {
        switch kind {
        case .boost: return String(localized: "powerup.boost")
        case .slowTime: return String(localized: "powerup.slowTime")
        case .adrenaline: return String(localized: "powerup.adrenaline")
        case .shield: return String(localized: "powerup.shield")
        }
    }

    // MARK: Diriliş

    /// 1930'lar çizgi filmi gibi: hayalet yukarı süzülür, "BİR ŞANS DAHA!" kartı, iris kapanır,
    /// karakter kirişine geri döner, iris açılır.
    private func playRespawn() {
        isRespawning = true
        touchRoles.removeAll()
        controls.highlight([])
        haptics.notify(.warning)
        character.isHidden = true

        let ghost = RubberHoseCharacter(style: .ghost)
        ghost.position = character.position
        ghost.zPosition = 40
        world.addChild(ghost)
        var floatUp: [SKAction] = []
        for frame in 0..<14 {
            let sway: CGFloat = frame % 4 < 2 ? 6 : -6
            floatUp.append(.run { ghost.tick(step: frame) })
            floatUp.append(.moveBy(x: sway, y: 12, duration: 0))
            floatUp.append(.wait(forDuration: 1.0 / 12.0))
        }
        ghost.run(.sequence([.sequence(floatUp), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        showTitleCard(String(localized: "card.respawn"), big: true)

        run(.sequence([
            .wait(forDuration: 1.3),
            .run { [weak self] in
                self?.runIris(closing: true, center: self?.character.position ?? .zero) {
                    self?.finishRespawn()
                }
            },
        ]))
    }

    private func finishRespawn() {
        _ = sim.respawn()
        syncNodes()
        cameraY = max(sim.y + visibleHeight * 0.1, visibleHeight / 2 - 40)
        character.isHidden = false
        character.playLand()
        spawnStars(at: CGPoint(x: sim.x, y: sim.y + 30))
        runIris(closing: false, center: CGPoint(x: sim.x, y: sim.y + 24)) { [weak self] in
            self?.lastUpdate = 0
            self?.accumulator = 0
            self?.isRespawning = false
        }
    }

    /// İris: karakterin etrafında daralan (ya da açılan) siyah daire, 12 fps.
    private func runIris(closing: Bool, center worldPoint: CGPoint, completion: @escaping () -> Void) {
        let iris = SKShapeNode()
        iris.strokeColor = Palette.ink
        iris.fillColor = .clear
        iris.lineWidth = 4000
        iris.zPosition = 2000
        iris.position = cameraNode.convert(worldPoint + CGPoint(x: 0, y: 24), from: world)
        cameraNode.addChild(iris)
        let maxRadius = hypot(size.width, size.height)
        let frames = 8
        var actions: [SKAction] = []
        for frame in 0...frames {
            let progress = Double(frame) / Double(frames)
            let radius = maxRadius * CGFloat(closing ? 1 - progress : progress)
            let outer = radius + 2000
            actions.append(.run {
                iris.path = CGPath(ellipseIn: CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2), transform: nil)
            })
            actions.append(.wait(forDuration: 1.0 / 12.0))
        }
        actions.append(.run(completion))
        actions.append(.removeFromParent())
        iris.run(.sequence(actions))
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
            let key = ObjectIdentifier(touch)
            touchRoles[key] = controlRole(for: point)
            swipeOrigins[key] = point
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            guard touchRoles[key] != nil else { continue }
            let point = touch.location(in: cameraNode)
            // Parmak öbür yarıya kayarsa yön de değişir.
            touchRoles[key] = controlRole(for: point)
            // Yukarı kaydırma: zıpla (OTO kapalıyken zıplamanın yolu). Her yeni kaydırma yeni bir zıplama.
            if let origin = swipeOrigins[key] {
                if point.y - origin.y > swipeJumpDistance {
                    pendingJump = true
                    swipeOrigins[key] = point
                } else if point.y < origin.y {
                    swipeOrigins[key] = point
                }
            }
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let key = ObjectIdentifier(touch)
            touchRoles[key] = nil
            swipeOrigins[key] = nil
        }
        controls.highlight(Set(touchRoles.values))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    /// Ekranın sol yarısı sola, sağ yarısı sağa.
    private func controlRole(for point: CGPoint) -> ControlRole {
        point.x < 0 ? .left : .right
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
