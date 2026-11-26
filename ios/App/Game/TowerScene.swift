import SpriteKit
import UIKit
import GameCore

/// Oyunun sahnesi. Kurallar `TowerSimulation`'da; burası yalnızca çizer, dinler ve hissettirir.
///
/// Zaman katmanları:
/// - Fizik: saniyede 120 sabit adım (tutarlı zıplama).
/// - Konum ve kamera: her ekran karesinde akıcı.
/// - Çizim titreşimi, film greni, alev: saniyede 12 kare ("on twos"), elle çizilmiş his için kasıtlı olarak kesik.
/// Oyun modu: tırmanış, tek boss dövüşü ya da bütün boss'lar sırayla.
enum PlayMode: Equatable {
    case climb
    case singleBoss
    case bossRush
}

/// Oyuncunun seçtiği hız. Tempoyu bütünüyle çarpar; tırmanış botu her hızda testlerden geçer.
enum GameSpeed: Int, CaseIterable {
    case normal = 0
    case medium = 1
    case fast = 2

    var multiplier: Double {
        switch self {
        case .normal: return 1
        case .medium: return 1.15
        case .fast: return 1.3
        }
    }
}

/// Oyun sonu özeti.
struct GameSummary {
    let score: Int
    let floor: Int
    let bossesBeaten: Int
    let victory: Bool
}

final class TowerScene: SKScene {
    var onGameOver: ((GameSummary) -> Void)?
    /// Kupa kazanıldığında hemen çağrılır (kayıt noktası kaydı için): kupanın katı.
    var onCheckpoint: ((Int) -> Void)?
    /// Boss yenildiğinde: arena katı.
    var onBossDefeated: ((Int) -> Void)?
    /// Tırmanışta karakter yere değdiği an kendiliğinden zıplar.
    /// Boss dövüşü ayrı bir moddur: orada otomatik zıplama yoktur, parmak yukarı kaydırılarak zıplanır.
    private var autoJump: Bool { sim.boss == nil }
    /// Kendi kendine oynama (yalnızca ekran görüntüsü modunda açılır).
    var demoPilot = false

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
    private var bossNode: BossNode?
    /// Işın ve fışkırma uyarısında hedef işareti (arenada).
    private let targetMarker = SKShapeNode()
    /// Yandan gelen dalga uyarısı: ekranın o kenarı yanıp söner, içeri bakan ok ve "!" görünür.
    private let sideFlash = SKShapeNode()
    private let sideArrow = SKLabelNode(fontNamed: Palette.fontName)
    private let sound = SoundEngine.shared
    /// Boss modlarında ödül ve kayıt yok; tek boss modunda dövüş bitince, sıralı modda altıncı boss'tan sonra oyun biter.
    let mode: PlayMode
    private var practice: Bool { mode != .climb }
    private let seed: UInt64
    /// Boss modlarında yenilen boss sayısı ve toplam boss puanı.
    private var bossesBeaten = 0
    private var bossScore = 0
    private(set) var gamePaused = false
    var isOver: Bool { gameOverSent }
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

    init(seed: UInt64, startFloor: Int, bossAlreadyDefeated: Bool, character: GameCharacter,
         mode: PlayMode = .climb, speed: GameSpeed = .normal) {
        var config = TowerConfig()
        config.speedMultiplier = speed.multiplier
        self.config = config
        self.mode = mode
        self.seed = seed
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
            targetMarker.zPosition = 3
            targetMarker.lineWidth = 3
            world.addChild(targetMarker)
            sideFlash.strokeColor = .clear
            sideFlash.zPosition = 900
            sideFlash.isHidden = true
            cameraNode.addChild(sideFlash)
            sideArrow.fontSize = 40
            sideArrow.fontColor = Palette.flame
            sideArrow.verticalAlignmentMode = .center
            sideArrow.zPosition = 901
            sideArrow.isHidden = true
            cameraNode.addChild(sideArrow)
        }
        layoutScene()
        syncNodes()
        if !introShown {
            introShown = true
            sound.start()
            sound.setPaused(false)
            sound.setTempo(config.pace(forFloor: sim.highestFloor))
            sound.setIntensity(2)
            if sim.boss != nil {
                showBossIntro()
            } else {
                sound.setMood(.climb)
                showTitleCard(chapterTitle(forFloor: sim.startFloor), big: true)
            }
        }
    }

    private func showBossIntro() {
        let kind = sim.boss?.kind ?? .octopus
        let name = BossNode.displayName(kind)
        showTitleCard(String(localized: "card.bossIntro \(name)"), big: true)
        showTitleCard(String(localized: "card.bossJump"), big: false)
        hud.showBoss(true, name: name, color: BossNode.barColor(kind))
        controls.showSwipeHint(true)
        haptics.notify(.warning)
        sound.setMood(.boss)
        sound.play(.bossIntro)
        shake()
    }

    /// Sıralı boss modunda bir sonraki boss'un arenasını kurar.
    private func loadBoss(number: Int) {
        sim = TowerSimulation(config: config, seed: seed &+ UInt64(number), startFloor: number * config.chapterLength)
        for node in platformNodes.values { node.removeFromParent() }
        platformNodes.removeAll()
        for node in bubbleNodes.values { node.removeFromParent() }
        bubbleNodes.removeAll()
        for node in projectileNodes.values { node.removeFromParent() }
        projectileNodes.removeAll()
        bossNode?.removeFromParent()
        bossNode = nil
        targetMarker.path = nil
        if let fight = sim.boss {
            cameraY = Double(fight.arenaFloor) * config.floorSpacing + visibleHeight * 0.42
        }
        syncNodes()
        character.isHidden = false
        showBossIntro()
        runIris(closing: false, center: CGPoint(x: sim.x, y: sim.y + 24)) { [weak self] in
            self?.lastUpdate = 0
            self?.accumulator = 0
            self?.isRespawning = false
        }
    }

    // MARK: Duraklatma

    /// Duraklatınca dünya donar, müzik kısılır; devam edince zaman kaldığı yerden akar.
    func setPaused(_ paused: Bool) {
        guard paused != gamePaused, !gameOverSent else { return }
        gamePaused = paused
        isPaused = paused
        touchRoles.removeAll()
        swipeOrigins.removeAll()
        controls.highlight([])
        lastUpdate = 0
        accumulator = 0
        sound.setPaused(paused)
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
        film.isHidden = !GameSettings.filmEffects
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
        guard !gamePaused else { return }
        let frameDt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 0.1)
        lastUpdate = currentTime

        let roles = Set(touchRoles.values)
        let direction = (roles.contains(.right) ? 1 : 0) - (roles.contains(.left) ? 1 : 0)

        accumulator += isRespawning ? 0 : frameDt
        while accumulator >= stepDuration && !isRespawning {
            var input = TowerInput(direction: direction, jump: pendingJump || (autoJump && sim.isGrounded))
            if demoPilot {
                input = DemoPilot.input(for: &sim)
                input.jump = input.jump || (autoJump && sim.isGrounded)
            }
            let events = sim.step(dt: stepDuration, input: input)
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
        character.isScared = sim.burnActive && sim.boss == nil && sim.y - sim.burnY < 170
        character.tick(step: boilStep)
        drawTargetMarker()
        drawSideFlash()
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
            bossNode?.tick(step: boilStep, telegraph: fight.telegraph, phase: fight.phase, flash: bossFlashTicks > 0)
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
        let wallTheme = WorldTheme.forFloor(Int(cameraY / config.floorSpacing), config: config)
        leftWall.setTheme(wallTheme)
        rightWall.setTheme(wallTheme)
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
        if bossNode == nil {
            let node = BossNode.make(fight.kind)
            node.zPosition = 15
            node.position = CGPoint(x: fight.x, y: fight.y)
            world.addChild(node)
            bossNode = node
        }
        bossNode?.position = CGPoint(x: fight.x, y: fight.y)
        hud.updateBoss(hp: fight.hp, maxHP: fight.maxHP, playerHP: sim.playerHP)

        var alive = Set<Int>()
        for shot in sim.enemyShots + sim.playerShots {
            alive.insert(shot.id)
            let node: ProjectileNode
            if let existing = projectileNodes[shot.id] {
                node = existing
            } else {
                node = ProjectileNode(kind: shot.kind, radius: CGFloat(shot.radius), boss: fight.kind)
                node.zPosition = shot.kind == .bullet ? 12 : 16
                world.addChild(node)
                projectileNodes[shot.id] = node
                if shot.kind == .bullet { sound.play(.playerShot) }
            }
            node.position = CGPoint(x: shot.x, y: shot.y)
            if shot.kind == .wave { node.xScale = shot.vx < 0 ? -1 : 1 }
        }
        for id in Array(projectileNodes.keys) where !alive.contains(id) {
            projectileNodes[id]?.removeFromParent()
            projectileNodes[id] = nil
        }
    }

    /// Dalga uyarısı: dalganın geleceği kenar 12 fps'te yanıp söner; zemin hizasında içeri bakan ok.
    private func drawSideFlash() {
        guard let fight = sim.boss, fight.telegraph == .wave else {
            sideFlash.isHidden = true
            sideArrow.isHidden = true
            return
        }
        // HUD gibi kamera alanında, ekran noktası cinsinden (bkz. `hud.layout`).
        let w = size.width
        let h = size.height
        let width: CGFloat = 54
        let left = fight.waveFromLeft
        let x = left ? -w / 2 : w / 2 - width
        sideFlash.path = CGPath(rect: CGRect(x: x, y: -h / 2, width: width, height: h), transform: nil)
        sideFlash.fillColor = Palette.flame.withAlphaComponent(boilStep % 2 == 0 ? 0.55 : 0.2)
        sideFlash.isHidden = false
        // Ok, arena zemininin hemen üstünde: dalga buradan gelecek.
        let floorY = CGFloat(Double(fight.arenaFloor) * config.floorSpacing)
        let arrowY = cameraNode.convert(CGPoint(x: 0, y: floorY + 34), from: world).y
        sideArrow.text = left ? "!▶" : "◀!"
        sideArrow.position = CGPoint(x: left ? -w / 2 + 46 : w / 2 - 46, y: arrowY)
        sideArrow.setScale(boilStep % 2 == 0 ? 1.15 : 0.95)
        sideArrow.isHidden = false
    }

    /// Işın: işaretli sütunda kesikli, yanıp sönen çizgiler. Fışkırma: zeminde çatlak ve kabarcıklar.
    private func drawTargetMarker() {
        guard let fight = sim.boss, let attack = fight.telegraph, attack == .laser || attack == .geyser else {
            targetMarker.path = nil
            return
        }
        let x = CGFloat(fight.targetX)
        let floorY = CGFloat(Double(fight.arenaFloor) * config.floorSpacing)
        let path = CGMutablePath()
        if attack == .laser {
            let top = CGFloat(fight.y) - 30
            var y = floorY
            while y < top {
                for side in [CGFloat(-15), 15] {
                    path.move(to: CGPoint(x: x + side, y: y))
                    path.addLine(to: CGPoint(x: x + side, y: min(top, y + 16)))
                }
                y += 30
            }
            targetMarker.strokeColor = boilStep % 2 == 0 ? Palette.flame : Palette.flameCore
            targetMarker.fillColor = .clear
        } else {
            path.addEllipse(in: CGRect(x: x - 26, y: floorY - 5, width: 52, height: 10))
            let rise = CGFloat(boilStep % 4) * 7
            for dx in [CGFloat(-12), 4, 14] {
                path.addEllipse(in: CGRect(x: x + dx - 4, y: floorY + 8 + rise + dx * 0.3, width: 8, height: 8))
            }
            targetMarker.strokeColor = Palette.ink
            targetMarker.fillColor = SKColor(red: 0.48, green: 0.32, blue: 0.18, alpha: 1)
        }
        targetMarker.path = path
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
            let platform = sim.platform(floor: floor)
            let node = PlatformNode(platform: platform, theme: WorldTheme.forFloor(floor, config: config),
                                    materialIndex: config.chapter(forFloor: max(0, floor - 1)) / WorldTheme.allCases.count)
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
                sound.play(.jump(power: power))
            case .landed(_, let climbed):
                character.playLand()
                spawnDust(at: CGPoint(x: sim.x, y: sim.y))
                haptics.impact(climbed >= 2 ? .medium : .soft)
                sound.play(.land(big: climbed >= 2))
            case .wallBounce(let side):
                let x = side > 0 ? config.playMaxX : config.playMinX
                spawnStars(at: CGPoint(x: x, y: sim.y + 24))
                haptics.impact(.rigid)
                sound.play(.wallBounce)
            case .wallKick(let side):
                // Takla: duvardan uzaklaşan yöne doğru tam tur.
                character.playFlip(towards: -side)
                haptics.impact(.heavy)
                sound.play(.wallKick)
            case .powerUp(let kind):
                for (floor, node) in bubbleNodes where sim.collectedBubbles.contains(floor) {
                    node.pop(in: world)
                    bubbleNodes[floor] = nil
                }
                showTitleCard(powerUpTitle(kind), big: kind == .boost)
                haptics.notify(.success)
                sound.play(.bubble)
                sound.play(kind == .boost ? .boost : .powerUp)
                if kind == .boost { shake() }
            case .boostFinished:
                character.playLand()
                spawnDust(at: CGPoint(x: sim.x, y: sim.y))
                sound.play(.land(big: true))
                sound.setTempo(config.pace(forFloor: sim.highestFloor))
                shake()
            case .shieldSaved:
                showTitleCard(String(localized: "card.shieldSaved"), big: false)
                spawnStars(at: CGPoint(x: sim.x, y: sim.y))
                haptics.impact(.heavy)
                sound.play(.shieldSaved)
            case .respawned:
                break
            case .bossStarted:
                showBossIntro()
            case .bossAttackWarning:
                haptics.impact(.light)
                sound.play(.bossWarning)
            case .bossAttack(let attack):
                sound.play(.bossAttack)
                if attack == .wave || attack == .rain || attack == .laser { shake() }
            case .bossHit:
                bossFlashTicks = 1
                sound.play(.bossHit)
            case .playerHit:
                haptics.notify(.error)
                shake()
                spawnStars(at: CGPoint(x: sim.x, y: sim.y + 30))
                character.playHurt()
                sound.play(.playerHit)
            case .bossDefeated(let number, let floor):
                if let node = bossNode {
                    node.playDefeat(in: world)
                    bossNode = nil
                }
                targetMarker.path = nil
                hud.showBoss(false, name: "", color: Palette.ink)
                controls.showSwipeHint(false)
                character.playCelebrate()
                sound.play(.bossDefeated)
                showTitleCard(String(localized: "card.bossDefeated"), big: true)
                haptics.notify(.success)
                shake()
                if practice {
                    bossesBeaten += 1
                    bossScore += config.bossDefeatBonus * number
                    // Zafer gösterisi sürerken oyun durur (karakter üstteki kirişlere zıplamasın).
                    isRespawning = true
                    if mode == .bossRush && number < BossKind.allCases.count {
                        // Sıradaki boss: iris kapanır, yeni arena, iris açılır.
                        run(.sequence([.wait(forDuration: 2.4), .run { [weak self] in
                            guard let self else { return }
                            self.runIris(closing: true, center: self.character.position) {
                                self.loadBoss(number: number + 1)
                            }
                        }]))
                    } else {
                        sound.setMood(.off)
                        run(.sequence([.wait(forDuration: 2.6), .run { [weak self] in self?.gameOver(victory: true) }]))
                    }
                } else {
                    sound.setMood(.climb)
                    showTitleCard(String(localized: "card.bossReward \(bossRewardCups)"), big: false)
                    showTitleCard(chapterTitle(forFloor: floor + 1), big: true)
                    onBossDefeated?(floor)
                }
            case .comboExtended(let jumps, let floors):
                hud.showCombo(jumps: jumps, floors: floors)
                sound.play(.comboUp(level: jumps))
                // Büyük kombo: müziğe banjo ve trompet katılır.
                sound.setIntensity(jumps >= 3 || floors >= 10 ? 3 : 2)
            case .comboEnded(_, let floors, let points):
                hud.hideCombo()
                sound.setIntensity(2)
                if points > 0 {
                    showTitleCard(String(localized: "card.combo \(floors)"), big: floors >= 10)
                    haptics.notify(.success)
                    sound.play(.comboCash)
                    if floors >= 10 {
                        shake()
                        character.playCelebrate()
                    }
                }
            case .newMilestone(let floor):
                showTitleCard(String(localized: "card.milestone \(floor)"), big: false)
                sound.play(.milestone)
                sound.setTempo(config.pace(forFloor: sim.highestFloor))
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
                character.playCelebrate()
                sound.play(.trophy)
                shake()
                if !practice { onCheckpoint?(floor) }
            case .burnStarted:
                showTitleCard(String(localized: "card.burn"), big: true)
                haptics.notify(.warning)
                sound.play(.burnStart)
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

    /// Film geri sarılır: ekranda "◀◀" işareti ve kayan tarama çizgileri, karakter titreyerek geri çekilir;
    /// "BİR ŞANS DAHA!" kartı, iris kapanır, karakter kirişine geri döner, iris açılır.
    /// (Oyunun "yanan film" temasına özgü; hayalet süzülmesi gibi başka oyunlarda görülen bir ölüm gösterisi kullanılmaz.)
    private func playRespawn() {
        isRespawning = true
        touchRoles.removeAll()
        controls.highlight([])
        haptics.notify(.warning)
        sound.play(.respawn)

        let rewind = SKNode()
        rewind.zPosition = 950
        cameraNode.addChild(rewind)
        let scan = SKShapeNode()
        let lines = CGMutablePath()
        var y = -size.height / 2
        while y < size.height / 2 + 16 {
            lines.move(to: CGPoint(x: -size.width / 2, y: y))
            lines.addLine(to: CGPoint(x: size.width / 2, y: y))
            y += 16
        }
        scan.path = lines
        scan.strokeColor = Palette.cream.withAlphaComponent(0.35)
        scan.lineWidth = 2
        rewind.addChild(scan)
        let symbol = SKLabelNode(fontNamed: Palette.fontName)
        symbol.text = "◀◀"
        symbol.fontSize = 60
        symbol.fontColor = Palette.cream
        symbol.verticalAlignmentMode = .center
        symbol.position = CGPoint(x: 0, y: -size.height * 0.05)
        rewind.addChild(symbol)
        var frames: [SKAction] = []
        for frame in 0..<14 {
            frames.append(.run { [weak self] in
                scan.position.y = frame % 2 == 0 ? 0 : 8
                symbol.alpha = frame % 2 == 0 ? 1 : 0.55
                // Kare kare yanıp söner (konum ve saydamlık her karede sahneyle eşitlendiği için görünürlükle).
                self?.character.isHidden = frame % 2 == 1 || frame >= 12
            })
            frames.append(.wait(forDuration: 1.0 / 12.0))
        }
        rewind.run(.sequence([.sequence(frames), .fadeOut(withDuration: 0.2), .removeFromParent()]))
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
        let label = SKLabelNode(fontNamed: Palette.fontName)
        label.text = text
        label.fontSize = big ? 26 : 20
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        // Uzun çeviriler kartın dışına taşmasın: dünya genişliğine sığacak şekilde satırlara bölünür.
        let maxWidth = CGFloat(config.worldWidth) - 80
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.preferredMaxLayoutWidth = maxWidth
        if label.frame.width > maxWidth { label.setScale(maxWidth / label.frame.width) }
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
        guard GameSettings.screenShake else { return }
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
    private func gameOver(victory: Bool = false) {
        guard !gameOverSent else { return }
        gameOverSent = true
        touchRoles.removeAll()
        controls.highlight([])
        haptics.notify(victory ? .success : .error)
        sound.setMood(.off)
        if !victory { sound.play(.died) }

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
        let summary = GameSummary(score: practice ? bossScore : sim.score, floor: sim.highestFloor,
                                  bossesBeaten: bossesBeaten, victory: victory)
        actions.append(.run { [weak self] in self?.onGameOver?(summary) })
        iris.run(.sequence(actions))
    }

    // MARK: Dokunma

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !sim.isDead, !gamePaused else { return }
        for touch in touches {
            let point = touch.location(in: cameraNode)
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
            // Yukarı kaydırma: zıpla (boss dövüşünde zıplamanın yolu). Her yeni kaydırma yeni bir zıplama.
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
        guard GameSettings.haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard GameSettings.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
