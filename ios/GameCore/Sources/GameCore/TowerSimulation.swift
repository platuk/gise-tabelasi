import Foundation

public struct TowerInput: Equatable, Sendable {
    /// -1 sol, 0 yok, 1 sağ.
    public var direction: Int
    /// Bu adımda zıplama istendi mi (dokunma ya da otomatik zıplama).
    public var jump: Bool

    public init(direction: Int = 0, jump: Bool = false) {
        self.direction = direction
        self.jump = jump
    }
}

public struct Combo: Equatable, Sendable {
    public internal(set) var jumps: Int
    public internal(set) var floors: Int
    public internal(set) var timeLeft: Double
}

/// Roket baloncuğunun uçuşu.
public struct Boost: Equatable, Sendable {
    public let targetFloor: Int
    public let startX: Double
    public let startY: Double
    public internal(set) var progress: Double
}

public enum TowerEvent: Equatable, Sendable {
    /// `power`: 0 (duran) ile 1 (tam hız) arası.
    case jumped(power: Double)
    case landed(floor: Int, floorsClimbed: Int)
    case wallBounce(side: Int)
    /// Havada duvara hızla çarpınca takla atıp yükselme.
    case wallKick(side: Int)
    case comboExtended(jumps: Int, floors: Int)
    case comboEnded(jumps: Int, floors: Int, points: Int)
    case newMilestone(floor: Int)
    /// Her 100 katta bir kupa: bu kat aynı zamanda kayıt noktası ve yeni bölümün başı.
    case trophyEarned(floor: Int)
    case powerUp(PowerUp)
    case boostFinished(floor: Int)
    /// Kalkan, yanan filmden kurtardı.
    case shieldSaved
    case burnStarted
    case died
    case respawned(floor: Int)
    /// Bölüm sonu: ahtapot sahneye çıktı.
    case bossStarted(number: Int)
    /// Ahtapot kollarını kaldırdı: saldırı geliyor.
    case bossAttackWarning(BossAttack)
    case bossAttack(BossAttack)
    case bossHit(hp: Int)
    case playerHit(hp: Int)
    case bossDefeated(number: Int, floor: Int)
}

/// Oyunun tüm kuralları. Arayüzden bağımsız, sabit zaman adımlı, tamamen deterministik.
///
/// Kurallar:
/// - Koştukça hız kazanılır; hızlı koşan daha yükseğe zıplar.
/// - Kirişler tek yönlüdür: alttan geçilir, üstten basılır.
/// - Duvara çarpan oyuncu hızını büyük ölçüde koruyarak geri seker; havada hızla çarparsa
///   takla atıp yükselir ve ulaşabileceği en yüksek kirişe doğru yönlendirilir.
/// - Gizli yardım: inişte kirişin kenarını az farkla kaçıran oyuncu kirişe hafifçe çekilir.
/// - 2 veya daha fazla kat atlayan iniş kombo başlatır/uzatır (3 sn içinde).
///   Kombo; tek kat atlanınca, aşağı düşülünce ya da süre dolunca biter.
///   En az 2 zıplamalık kombo, (kat sayısı)² puan verir.
/// - Her 100 katta bir kupa kazanılır; o kat kayıt noktasıdır ve yeni bölüm başlar.
/// - Kayan kirişler üzerindeki oyuncuyu taşır; kaygan kirişlerde sürtünme düşüktür.
/// - Baloncuklar: roket (50 kat), ağır çekim, adrenalin, kalkan.
/// - Başlangıçtan 5 kat sonra alttan yanan film yükselir; ona yakalanan oyun biter.
///   Oyun başına bir kez bedava diriliş vardır (`respawn()`).
public struct TowerSimulation: Sendable {
    public let config: TowerConfig
    public let startFloor: Int
    let seed: UInt64
    private var generator: PlatformGenerator

    // Boss dövüşü (Boss.swift)
    public internal(set) var boss: BossFight?
    public internal(set) var enemyShots: [Projectile] = []
    public internal(set) var playerShots: [Projectile] = []
    public internal(set) var playerHP: Int
    public internal(set) var hurtTimer: Double = 0
    /// En son yenilen boss'un arena katı (0: hiç).
    public internal(set) var defeatedBossFloor: Int
    public internal(set) var bonusPoints = 0
    var fireTimer: Double = 0
    var projectileCounter = 0
    var bossRNG = SplitMix64(seed: 0)

    /// Oyuncunun yatay merkezi.
    public internal(set) var x: Double
    /// Oyuncunun ayaklarının yüksekliği.
    public internal(set) var y: Double
    public internal(set) var vx: Double = 0
    public internal(set) var vy: Double = 0
    public internal(set) var isGrounded = true
    public internal(set) var currentFloor: Int
    public internal(set) var highestFloor: Int
    public internal(set) var comboPoints = 0
    public internal(set) var combo: Combo?
    public internal(set) var facing = 1
    public internal(set) var burnActive = false
    public internal(set) var burnY: Double
    public internal(set) var burnSpeed: Double = 0
    public internal(set) var isDead = false
    /// Dünya zamanı (ağır çekimde yavaş akar).
    public internal(set) var elapsed: Double = 0

    public internal(set) var collectedBubbles: Set<Int> = []
    public internal(set) var boost: Boost?
    public internal(set) var slowRemaining: Double = 0
    public internal(set) var adrenalineRemaining: Double = 0
    public internal(set) var shieldRemaining: Double = 0
    public internal(set) var respawnsUsed = 0
    /// Duvar taklasından sonra iniş yönlendirmesi sürüyor mu.
    public internal(set) var wallKickGuiding = false
    /// Son inişten beri atılan duvar taklası sayısı (en fazla `maxWallKicks`).
    public internal(set) var wallKicksSinceLanding = 0

    private var coyoteTimer: Double = 0
    private var jumpBuffer: Double = 0
    private var burnElapsed: Double = 0

    /// `startFloor`: kayıt noktasından başlamak için (ör. 100, 1000). Kat 0'dan başlamak için 0.
    /// Bir boss katından başlanırsa dövüş hemen başlar; `bossAlreadyDefeated` ise atlanır.
    public init(config: TowerConfig = TowerConfig(), seed: UInt64, startFloor: Int = 0, bossAlreadyDefeated: Bool = false) {
        self.config = config
        self.seed = seed
        var generator = PlatformGenerator(config: config, seed: seed)
        let start = generator.platform(floor: max(0, startFloor))
        self.generator = generator
        self.startFloor = start.floor
        self.x = start.centerX
        self.y = start.y
        self.currentFloor = start.floor
        self.highestFloor = start.floor
        self.burnY = start.y - config.burnStartDistance
        self.playerHP = config.playerMaxHP
        self.defeatedBossFloor = bossAlreadyDefeated ? start.floor : 0
        if config.isBossFloor(start.floor) && !bossAlreadyDefeated {
            _ = startBoss(arenaFloor: start.floor)
        }
    }

    public var score: Int { highestFloor * 10 + comboPoints + bonusPoints }

    /// Şu ana kadar kazanılan en yüksek kupanın katı (kayıt noktası). Hiç yoksa 0.
    public var checkpointFloor: Int {
        highestFloor / config.milestoneInterval * config.milestoneInterval
    }

    public var canRespawn: Bool { isDead && respawnsUsed < config.freeRespawns }

    private var maxSpeed: Double {
        adrenalineRemaining > 0 ? config.maxRunSpeed * config.adrenalineSpeedFactor : config.maxRunSpeed
    }

    public mutating func platform(floor: Int) -> Platform {
        generator.platform(floor: floor)
    }

    /// Kirişin şu anki konumu (kayan kirişler zamanla yer değiştirir).
    public mutating func bounds(floor: Int) -> (minX: Double, maxX: Double) {
        platform(floor: floor).bounds(at: elapsed)
    }

    /// Kattaki baloncuğun konumu (kirişin taban merkezinin üstünde).
    public func bubblePosition(of platform: Platform) -> (x: Double, y: Double) {
        (platform.centerX, platform.y + config.bubbleHeight)
    }

    public mutating func step(dt realDt: Double, input: TowerInput) -> [TowerEvent] {
        guard !isDead, realDt > 0 else { return [] }
        var events: [TowerEvent] = []

        // Tempo: oyun sakin başlar, katlar ilerledikçe hızlanır.
        // Ağır çekim yalnızca dünyayı yavaşlatır; baloncuk süreleri gerçek zamanla akar.
        let pace = config.pace(forFloor: highestFloor)
        let dt = realDt * pace * (slowRemaining > 0 ? config.slowFactor : 1)
        slowRemaining = max(0, slowRemaining - realDt)
        adrenalineRemaining = max(0, adrenalineRemaining - realDt)
        shieldRemaining = max(0, shieldRemaining - realDt)

        let previousTime = elapsed
        elapsed += dt

        if boost != nil {
            events += stepBoost(dt: dt)
            events += stepBurn(dt: dt)
            return events
        }

        let direction = input.direction.signum()
        jumpBuffer = input.jump ? config.jumpBufferTime : max(0, jumpBuffer - dt)
        coyoteTimer = isGrounded ? config.coyoteTime : max(0, coyoteTimer - dt)

        let standing: Platform? = isGrounded ? platform(floor: currentFloor) : nil
        let onSlippery = standing?.isSlippery ?? false
        let adrenaline = adrenalineRemaining > 0 ? config.adrenalineSpeedFactor : 1

        // Yatay hareket
        if direction != 0 {
            facing = direction
            let acceleration: Double
            if isGrounded {
                acceleration = (onSlippery ? config.slipperyAcceleration : config.groundAcceleration) * adrenaline
            } else {
                acceleration = config.airAcceleration * adrenaline
            }
            vx += Double(direction) * acceleration * dt
        } else if isGrounded {
            let friction = (onSlippery ? config.slipperyFriction : config.groundFriction) * dt
            vx = abs(vx) <= friction ? 0 : vx - friction * (vx > 0 ? 1 : -1)
        }

        // Duvar taklası yönlendirmesi: ulaşılabilecek en yüksek kirişin ortasına doğru.
        if wallKickGuiding && !isGrounded {
            let peak = y + max(0, vy) * max(0, vy) / (2 * config.gravity)
            let targetFloor = Int((peak / config.floorSpacing).rounded(.down))
            if targetFloor > currentFloor {
                let target = bounds(floor: targetFloor)
                let dx = (target.minX + target.maxX) / 2 - x
                if abs(dx) > 8 {
                    vx += (dx > 0 ? 1 : -1) * config.wallKickSteer * dt
                }
            }
        }
        vx = min(max(vx, -maxSpeed), maxSpeed)

        // Zıplama
        if jumpBuffer > 0 && coyoteTimer > 0 {
            vy = (config.baseJumpVelocity + config.jumpSpeedBonus * abs(vx)) * (adrenalineRemaining > 0 ? 1.08 : 1)
            isGrounded = false
            coyoteTimer = 0
            jumpBuffer = 0
            events.append(.jumped(power: min(1, abs(vx) / config.maxRunSpeed)))
        }

        let previousY = y
        if !isGrounded {
            vy -= config.gravity * dt
        }
        x += vx * dt
        y += vy * dt

        // Kayan kiriş üzerindeki oyuncuyu taşır.
        if isGrounded, let standing {
            x += standing.offset(at: elapsed) - standing.offset(at: previousTime)
        }

        // Gizli yardım: düşerken bir alttaki kirişin kenarını az farkla kaçırıyorsan kirişe çekil.
        if !isGrounded && vy < 0 {
            let below = platform(floor: Int((y / config.floorSpacing).rounded(.down)))
            let gap = y - below.y
            if gap >= 0 && gap < 70 {
                let (minX, maxX) = below.bounds(at: elapsed)
                let foot = config.playerWidth * 0.3
                let pull = config.landingAssistSpeed * dt
                if x + foot < minX && minX - (x + foot) <= config.landingAssistMargin {
                    x += min(pull, minX - (x + foot))
                } else if x - foot > maxX && (x - foot) - maxX <= config.landingAssistMargin {
                    x -= min(pull, (x - foot) - maxX)
                }
            }
        }

        // Duvarlardan sekme (havada hızlıysa takla)
        let half = config.playerWidth / 2
        var hitWall = 0
        if x - half < config.playMinX {
            x = config.playMinX + half
            if vx < 0 { hitWall = -1 }
        } else if x + half > config.playMaxX {
            x = config.playMaxX - half
            if vx > 0 { hitWall = 1 }
        }
        if hitWall != 0 {
            let impact = abs(vx)
            vx = -vx * config.wallBounceDamping
            events.append(.wallBounce(side: hitWall))
            if !isGrounded && impact >= config.wallKickMinSpeed && wallKicksSinceLanding < config.maxWallKicks {
                vy = max(vy, config.wallKickVelocity)
                wallKickGuiding = true
                wallKicksSinceLanding += 1
                events.append(.wallKick(side: hitWall))
            }
        }

        // Kirişin ucundan düşme
        if isGrounded, let standing, !supports(standing) {
            isGrounded = false
            vy = 0
        }

        // İniş: düşerken geçilen kirişlerden en üsttekine basılır.
        // Boss dövüşünde arenanın üstündeki kirişlere basılamaz (boss atlanamaz).
        if !isGrounded && vy <= 0 {
            let ceiling = boss?.arenaFloor ?? Int.max
            let top = min(ceiling, Int((previousY / config.floorSpacing).rounded(.down)))
            let bottom = max(0, Int((y / config.floorSpacing).rounded(.up)))
            if top >= bottom {
                for floor in stride(from: top, through: bottom, by: -1) {
                    let candidate = platform(floor: floor)
                    if candidate.y <= previousY && candidate.y >= y && supports(candidate) {
                        events += land(onFloor: floor)
                        break
                    }
                }
            }
        }

        if boss != nil {
            events += stepBoss(dt: dt)
            return events
        }

        events += collectBubbles()

        // Kombo süresi
        if var running = combo {
            running.timeLeft -= dt
            if running.timeLeft <= 0 {
                events += endCombo()
            } else {
                combo = running
            }
        }

        events += stepBurn(dt: dt)
        return events
    }

    /// Bedava diriliş: en son basılan kirişe geri döner, film geri çekilir, kısa bir kalkan verilir.
    public mutating func respawn() -> [TowerEvent] {
        guard canRespawn else { return [] }
        respawnsUsed += 1
        isDead = false
        boost = nil
        combo = nil
        wallKickGuiding = false
        wallKicksSinceLanding = 0
        if let fight = boss {
            // Boss dövüşünde: arenaya geri dön, can dolar, havadaki mermiler temizlenir; boss'un canı aynı kalır.
            let arena = platform(floor: fight.arenaFloor)
            currentFloor = fight.arenaFloor
            x = arena.centerX
            y = arena.y
            vx = 0
            vy = 0
            isGrounded = true
            playerHP = config.playerMaxHP
            hurtTimer = 0
            enemyShots = []
            shieldRemaining = config.respawnShield
            return [.respawned(floor: fight.arenaFloor)]
        }
        let floor = max(startFloor, currentFloor)
        let (minX, maxX) = bounds(floor: floor)
        x = (minX + maxX) / 2
        y = platform(floor: floor).y
        vx = 0
        vy = 0
        isGrounded = true
        burnY = y - config.burnStartDistance
        burnElapsed = max(0, burnElapsed - 15)
        shieldRemaining = config.respawnShield
        return [.respawned(floor: floor)]
    }

    @discardableResult
    mutating func land(onFloor floor: Int) -> [TowerEvent] {
        var events: [TowerEvent] = []
        let target = platform(floor: floor)
        y = target.y
        vy = 0
        isGrounded = true
        wallKickGuiding = false
        wallKicksSinceLanding = 0
        let climbed = floor - currentFloor
        currentFloor = floor
        events.append(.landed(floor: floor, floorsClimbed: climbed))

        if climbed >= 2 {
            var running = combo ?? Combo(jumps: 0, floors: 0, timeLeft: 0)
            running.jumps += 1
            running.floors += climbed
            running.timeLeft = config.comboWindow
            combo = running
            events.append(.comboExtended(jumps: running.jumps, floors: running.floors))
        } else if climbed != 0 {
            events += endCombo()
        }

        if floor > highestFloor {
            let previous = highestFloor
            highestFloor = floor

            // Bir yüzlük sınır geçildiyse kupa (üzerine basılmasa bile, atlanarak geçilse de).
            let chapterLength = max(1, config.milestoneInterval)
            let trophyEarned = floor / chapterLength > previous / chapterLength
            if trophyEarned {
                events.append(.trophyEarned(floor: floor / chapterLength * chapterLength))
            }

            let cardInterval = max(1, config.cardInterval)
            let card = floor / cardInterval * cardInterval
            if floor / cardInterval > previous / cardInterval && !(trophyEarned && card % chapterLength == 0) {
                events.append(.newMilestone(floor: card))
            }

            // Bölüm sınırı (1000, 2000, ...) geçildiyse boss dövüşü; atlanarak geçilse bile arenaya inilir.
            let bossFloor = floor / max(1, config.chapterLength) * max(1, config.chapterLength)
            if boss == nil && config.isBossFloor(bossFloor) && bossFloor > previous && bossFloor > defeatedBossFloor {
                events += startBoss(arenaFloor: bossFloor)
            }
        }
        return events
    }

    /// Baloncuğu al ve etkisini başlat.
    @discardableResult
    mutating func apply(_ powerUp: PowerUp) -> [TowerEvent] {
        switch powerUp {
        case .boost:
            let base = max(currentFloor, Int((y / config.floorSpacing).rounded(.down)))
            boost = Boost(targetFloor: base + config.boostFloors, startX: x, startY: y, progress: 0)
            isGrounded = false
            vx = 0
            vy = 0
            wallKickGuiding = false
        case .slowTime:
            slowRemaining = config.slowDuration
        case .adrenaline:
            adrenalineRemaining = config.adrenalineDuration
        case .shield:
            shieldRemaining = config.shieldDuration
        }
        return [.powerUp(powerUp)]
    }

    private mutating func collectBubbles() -> [TowerEvent] {
        let bodyCenterY = y + config.playerHeight / 2
        let reach = config.bubbleRadius + config.playerWidth / 2
        let lowest = max(0, Int(((y - config.bubbleHeight) / config.floorSpacing).rounded(.down)))
        var events: [TowerEvent] = []
        for floor in lowest...(lowest + 2) where !collectedBubbles.contains(floor) {
            let candidate = platform(floor: floor)
            guard let bubble = candidate.bubble else { continue }
            let position = bubblePosition(of: candidate)
            if hypot(position.x - x, position.y - bodyCenterY) <= reach {
                collectedBubbles.insert(floor)
                events += apply(bubble)
                if bubble == .boost { break }
            }
        }
        return events
    }

    private mutating func stepBoost(dt: Double) -> [TowerEvent] {
        guard var flight = boost else { return [] }
        flight.progress = min(1, flight.progress + dt / config.boostDuration)
        let target = platform(floor: flight.targetFloor)
        let (minX, maxX) = target.bounds(at: elapsed)
        let eased = 1 - (1 - flight.progress) * (1 - flight.progress)
        x = flight.startX + ((minX + maxX) / 2 - flight.startX) * eased
        y = flight.startY + (target.y - flight.startY) * eased
        vx = 0
        vy = config.floorSpacing * Double(config.boostFloors) / config.boostDuration
        if flight.progress >= 1 {
            boost = nil
            var events = land(onFloor: flight.targetFloor)
            events.append(.boostFinished(floor: flight.targetFloor))
            return events
        }
        boost = flight
        return []
    }

    private mutating func stepBurn(dt: Double) -> [TowerEvent] {
        guard boss == nil else { return [] }
        var events: [TowerEvent] = []
        if !burnActive && highestFloor - startFloor >= config.burnStartFloor {
            burnActive = true
            burnY = y - config.burnStartDistance
            events.append(.burnStarted)
        }
        guard burnActive else { return events }
        burnElapsed += dt
        burnSpeed = min(config.burnSpeedLimit(forFloor: highestFloor), config.burnBaseSpeed + config.burnAcceleration * burnElapsed)
        burnY = max(burnY + burnSpeed * dt, y - config.burnMaxLag)
        if y < burnY && boost == nil {
            if shieldRemaining > 0 {
                // Kalkan: alevden yukarı sek, film biraz geri çekilsin.
                vy = config.jumpVelocity(forSpeed: config.maxRunSpeed)
                isGrounded = false
                burnY = y - 120
                events.append(.shieldSaved)
            } else {
                isDead = true
                events += endCombo()
                events.append(.died)
            }
        }
        return events
    }

    private mutating func endCombo() -> [TowerEvent] {
        guard let finished = combo else { return [] }
        combo = nil
        let points = finished.jumps >= 2 ? finished.floors * finished.floors : 0
        comboPoints += points
        return [.comboEnded(jumps: finished.jumps, floors: finished.floors, points: points)]
    }

    /// Oyuncunun ayakları kirişin (şu anki konumunun) üzerinde mi; kenarlarda biraz tolerans var.
    private func supports(_ candidate: Platform) -> Bool {
        let foot = config.playerWidth * 0.3
        let (minX, maxX) = candidate.bounds(at: elapsed)
        return x + foot >= minX && x - foot <= maxX
    }
}
