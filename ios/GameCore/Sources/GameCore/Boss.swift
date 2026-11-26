import Foundation

/// Bölüm sonu boss'ları sırayla gelir; altıncıdan sonra döngü başa döner (canları artarak).
public enum BossKind: Int, Equatable, Sendable, CaseIterable {
    /// Kaptan Mürekkep: ahtapot.
    case octopus = 0
    /// Profesör Kıvrım: solucan.
    case worm
    /// Kont Kanat: yarasa.
    case bat
    /// Zorp: uçan dairedeki uzaylı.
    case alien
    /// Paslı Perçin: robot.
    case robot
    /// Hırlayan Bulldog: vinç kancasına asılı.
    case bulldog

    /// 1'den başlayan boss sırasına göre tür.
    public static func forNumber(_ number: Int) -> BossKind {
        BossKind(rawValue: (max(1, number) - 1) % allCases.count) ?? .octopus
    }

    /// Aşamaya göre saldırı sırası. Her saldırıdan önce uyarı gelir.
    func attacks(phase: Int) -> [BossAttack] {
        switch (self, phase) {
        case (.octopus, 1): return [.spread, .wave]
        case (.octopus, 2): return [.spread, .aimed, .wave]
        case (.octopus, _): return [.rain, .aimed, .spread, .wave]
        case (.worm, 1): return [.geyser, .spread]
        case (.worm, 2): return [.geyser, .wave, .spread]
        case (.worm, _): return [.geyser, .rain, .wave, .aimed]
        case (.bat, 1): return [.ring, .aimed]
        case (.bat, 2): return [.ring, .rain, .aimed]
        case (.bat, _): return [.ring, .aimed, .rain, .spread]
        case (.alien, 1): return [.laser, .ring]
        case (.alien, 2): return [.laser, .aimed, .ring]
        case (.alien, _): return [.laser, .rain, .ring, .aimed]
        case (.robot, 1): return [.bounce, .laser]
        case (.robot, 2): return [.bounce, .spread, .laser]
        case (.robot, _): return [.bounce, .laser, .rain, .wave]
        case (.bulldog, 1): return [.bounce, .wave]
        case (.bulldog, 2): return [.bounce, .geyser, .wave]
        case (.bulldog, _): return [.bounce, .geyser, .wave, .aimed]
        }
    }

    /// Bu boss'un bu saldırıda attığı merminin türü (görünüş için).
    func projectile(for attack: BossAttack) -> ProjectileKind {
        switch attack {
        case .wave: return .wave
        case .laser: return .laser
        case .geyser: return .mud
        case .ring: return .sonic
        case .bounce: return self == .bulldog ? .bone : .bolt
        case .spread, .aimed, .rain:
            switch self {
            case .octopus: return attack == .spread ? .fireball : .ink
            case .worm: return .mud
            case .bat, .alien: return .sonic
            case .robot: return .bolt
            case .bulldog: return .bone
            }
        }
    }
}

/// Boss saldırıları. Her saldırıdan önce bir uyarı (telegraph) gelir.
public enum BossAttack: String, Equatable, Sendable, CaseIterable {
    /// Yelpaze şeklinde 5 mermi.
    case spread
    /// Oyuncuya nişanlı 3 mermi.
    case aimed
    /// Zeminde yandan gelen dalga: üstünden zıplanır.
    case wave
    /// Yukarıdan rastgele yerlere düşen yağmur.
    case rain
    /// Zeminden fışkıran çamur: uyarıda işaretlenen yerden uzak dur.
    case geyser
    /// Boss'un çevresine yayılan yavaş halka.
    case ring
    /// İşaretlenen sütuna düşen ışın: kenara kaç.
    case laser
    /// Kavisle atılan, zeminde seken mermiler.
    case bounce
}

public enum ProjectileKind: String, Equatable, Sendable {
    case fireball
    case ink
    case wave
    case mud
    case sonic
    case laser
    case bolt
    case bone
    /// Oyuncunun mermisi.
    case bullet
}

public struct Projectile: Equatable, Sendable, Identifiable {
    public let id: Int
    public let kind: ProjectileKind
    public internal(set) var x: Double
    public internal(set) var y: Double
    public internal(set) var vx: Double
    public internal(set) var vy: Double
    public let radius: Double
    /// Yerçekimi (aşağı doğru negatif). 0: düz gider.
    public internal(set) var ay: Double = 0
    /// Zemine değince seker mi.
    public internal(set) var bounces = false
    public internal(set) var age: Double = 0
}

/// Bölüm sonundaki boss. Can azaldıkça aşama değişir ve yeni saldırılar eklenir.
public struct BossFight: Equatable, Sendable {
    /// 1'den başlayan boss sırası (kat 1000 → 1).
    public let number: Int
    public let kind: BossKind
    public let arenaFloor: Int
    public let maxHP: Int
    public internal(set) var hp: Int
    public internal(set) var x: Double
    public internal(set) var y: Double
    public internal(set) var time: Double = 0
    public internal(set) var attackTimer: Double = 1.6
    /// Uyarısı sürmekte olan saldırı (boss kollarını kaldırmış, parlıyor).
    public internal(set) var telegraph: BossAttack?
    public internal(set) var telegraphLeft: Double = 0
    /// Işın ve fışkırma saldırılarının hedeflediği x (uyarıda işaretlenir).
    public internal(set) var targetX: Double = 0
    /// Dalga hangi duvardan gelecek (uyarıda belirlenir; ekranın o kenarı yanıp söner).
    public internal(set) var waveFromLeft = true
    var attackIndex = 0

    /// 1: tam can, 2: üçte iki altı, 3: üçte bir altı.
    public var phase: Int {
        if hp * 3 > maxHP * 2 { return 1 }
        if hp * 3 > maxHP { return 2 }
        return 3
    }

    var attacks: [BossAttack] { kind.attacks(phase: phase) }
}

extension TowerSimulation {
    /// Arena katına varıldı: dövüş başlar, oyuncu arenanın ortasına konur, film beklemeye alınır.
    mutating func startBoss(arenaFloor: Int) -> [TowerEvent] {
        let number = max(1, arenaFloor / max(1, config.chapterLength))
        let hp = config.bossBaseHP + config.bossHPPerChapter * (number - 1)
        let arena = platform(floor: arenaFloor)
        boss = BossFight(number: number, kind: BossKind.forNumber(number), arenaFloor: arenaFloor, maxHP: hp, hp: hp,
                         x: config.worldWidth / 2, y: arena.y + config.bossHeight)
        bossRNG = SplitMix64(seed: seed ^ UInt64(arenaFloor &* 7_919))
        currentFloor = arenaFloor
        if highestFloor < arenaFloor { highestFloor = arenaFloor }
        y = arena.y
        x = arena.centerX
        vx = 0
        vy = 0
        isGrounded = true
        boost = nil
        playerHP = config.playerMaxHP
        hurtTimer = 0
        fireTimer = config.fireInterval
        enemyShots = []
        playerShots = []
        burnY = arena.y - 2000
        return [.bossStarted(number: number)]
    }

    /// Boss'un türüne göre hareketi: her biri kendine özgü bir yol izler.
    static func bossPosition(kind: BossKind, time t: Double, centerX: Double, sway: Double, baseY: Double) -> (Double, Double) {
        switch kind {
        case .octopus:
            return (centerX + sway * sin(t * 0.7), baseY + 18 * sin(t * 1.3))
        case .worm:
            // Kıvrılarak: geniş yatay dalga, hızlı dikey kıvrım.
            return (centerX + sway * 1.05 * sin(t * 0.9), baseY - 10 + 30 * sin(t * 2.1))
        case .bat:
            // Sekiz çizerek uçar.
            return (centerX + sway * 1.1 * sin(t * 1.1), baseY + 45 * sin(t * 2.2))
        case .alien:
            // Uçan daire: yavaş süzülür, üstüne küçük titreşim.
            return (centerX + sway * sin(t * 0.55) + 16 * sin(t * 3.1), baseY + 12 * sin(t * 1.7))
        case .robot:
            // Ağır: yavaş gider, adım atar gibi iner kalkar.
            return (centerX + sway * 0.85 * sin(t * 0.45), baseY - 6 + 14 * abs(sin(t * 2.0)))
        case .bulldog:
            // Vinç kancasında sarkaç.
            let swing = sin(t * 0.8)
            return (centerX + sway * 1.15 * swing, baseY + 10 - 26 * swing * swing)
        }
    }

    /// Dövüşün bir adımı: boss hareketi, saldırılar, mermiler, çarpışmalar.
    mutating func stepBoss(dt: Double) -> [TowerEvent] {
        guard var fight = boss else { return [] }
        var events: [TowerEvent] = []
        let arenaY = Double(fight.arenaFloor) * config.floorSpacing

        fight.time += dt
        let position = Self.bossPosition(kind: fight.kind, time: fight.time, centerX: config.worldWidth / 2,
                                         sway: config.bossSway, baseY: arenaY + config.bossHeight)
        fight.x = position.0
        fight.y = position.1

        // Saldırı: önce uyarı, sonra atış.
        if let attack = fight.telegraph {
            fight.telegraphLeft -= dt
            if fight.telegraphLeft <= 0 {
                fight.telegraph = nil
                spawn(attack, from: fight, arenaY: arenaY)
                events.append(.bossAttack(attack))
                let speedUp = fight.phase == 3 ? 0.7 : (fight.phase == 2 ? 0.85 : 1)
                fight.attackTimer = config.attackInterval * speedUp
            }
        } else {
            fight.attackTimer -= dt
            if fight.attackTimer <= 0 {
                let options = fight.attacks
                let attack = options[fight.attackIndex % options.count]
                fight.attackIndex += 1
                fight.telegraph = attack
                // Işın ve fışkırma oyuncunun şu anki yerini hedefler; uyarı süresince kaçılır.
                fight.targetX = min(max(x, config.playMinX + 30), config.playMaxX - 30)
                // Oyuncudan uzak duvar; uyarı süresince değişmez ki oyuncu hangi yandan geleceğini bilsin.
                fight.waveFromLeft = x > config.worldWidth / 2
                let longer: Double
                switch attack {
                case .wave: longer = config.waveWarningFactor
                case .laser, .geyser: longer = 1.25
                default: longer = 1
                }
                fight.telegraphLeft = (fight.phase == 3 ? config.telegraphTime * 0.7 : config.telegraphTime) * longer
                events.append(.bossAttackWarning(attack))
            }
        }

        // Oyuncunun otomatik ateşi
        fireTimer -= dt
        if fireTimer <= 0 {
            fireTimer = config.fireInterval
            playerShots.append(Projectile(id: nextProjectileID(), kind: .bullet, x: x, y: y + config.playerHeight,
                                          vx: 0, vy: config.bulletSpeed, radius: 7))
        }

        // Mermileri ilerlet
        for index in playerShots.indices {
            playerShots[index].x += playerShots[index].vx * dt
            playerShots[index].y += playerShots[index].vy * dt
        }
        for index in enemyShots.indices {
            var shot = enemyShots[index]
            shot.age += dt
            shot.vy += shot.ay * dt
            shot.x += shot.vx * dt
            shot.y += shot.vy * dt
            if shot.bounces && shot.y - shot.radius < arenaY && shot.vy < 0 {
                shot.y = arenaY + shot.radius
                shot.vy = -shot.vy * 0.78
            }
            enemyShots[index] = shot
        }

        // Oyuncu mermisi → boss
        var remainingShots: [Projectile] = []
        for shot in playerShots {
            if hypot(shot.x - fight.x, shot.y - fight.y) <= config.bossHitRadius + shot.radius {
                fight.hp -= 1
                events.append(.bossHit(hp: fight.hp))
            } else if shot.y < fight.y + 200 {
                remainingShots.append(shot)
            }
        }
        playerShots = remainingShots

        // Boss mermisi → oyuncu
        hurtTimer = max(0, hurtTimer - dt)
        let bodyX = x
        let bodyY = y + config.playerHeight / 2
        var remainingEnemy: [Projectile] = []
        for shot in enemyShots {
            let hits = hypot(shot.x - bodyX, shot.y - bodyY) <= shot.radius + 13
            if hits && hurtTimer <= 0 && shieldRemaining <= 0 && !isDead {
                playerHP -= 1
                hurtTimer = config.hurtInvulnerability
                events.append(.playerHit(hp: playerHP))
                if playerHP <= 0 {
                    isDead = true
                    events.append(.died)
                }
                continue
            }
            let inside = shot.y > arenaY - 60 && shot.y < arenaY + 1000
                && shot.x > config.playMinX - 40 && shot.x < config.playMaxX + 40
                && shot.age < 8
            if inside { remainingEnemy.append(shot) }
        }
        enemyShots = remainingEnemy

        // Zafer
        if fight.hp <= 0 {
            boss = nil
            enemyShots = []
            playerShots = []
            defeatedBossFloor = max(defeatedBossFloor, fight.arenaFloor)
            bonusPoints += config.bossDefeatBonus * fight.number
            burnY = y - config.burnStartDistance
            events.append(.bossDefeated(number: fight.number, floor: fight.arenaFloor))
            return events
        }
        boss = fight
        return events
    }

    private mutating func spawn(_ attack: BossAttack, from fight: BossFight, arenaY: Double) {
        let mouthX = fight.x
        let mouthY = fight.y - 40
        let kind = fight.kind.projectile(for: attack)
        func add(x: Double, y: Double, vx: Double, vy: Double, radius: Double, ay: Double = 0, bounces: Bool = false) {
            enemyShots.append(Projectile(id: nextProjectileID(), kind: kind, x: x, y: y, vx: vx, vy: vy,
                                         radius: radius, ay: ay, bounces: bounces))
        }
        switch attack {
        case .spread:
            for index in 0..<5 {
                let angle = -Double.pi / 2 + (Double(index) - 2) * (25 * .pi / 180)
                add(x: mouthX, y: mouthY, vx: cos(angle) * 230, vy: sin(angle) * 230, radius: 12)
            }
        case .aimed:
            let base = atan2((y + config.playerHeight / 2) - mouthY, x - mouthX)
            for offset in [-0.18, 0, 0.18] {
                add(x: mouthX, y: mouthY, vx: cos(base + offset) * 300, vy: sin(base + offset) * 300, radius: 11)
            }
        case .wave:
            // Oyuncudan uzak duvardan çıkar ki tepki süresi olsun.
            let fromLeft = fight.waveFromLeft
            let startX = fromLeft ? config.playMinX : config.playMaxX
            add(x: startX, y: arenaY + 16, vx: fromLeft ? config.waveSpeed : -config.waveSpeed, vy: 0, radius: 18)
        case .rain:
            let lanes = 6
            let laneWidth = (config.playMaxX - config.playMinX) / Double(lanes)
            for lane in 0..<lanes {
                let jitter = (bossRNG.nextUnit() - 0.5) * laneWidth * 0.6
                let laneX = config.playMinX + laneWidth * (Double(lane) + 0.5) + jitter
                add(x: laneX, y: fight.y + 60 + bossRNG.nextUnit() * 120, vx: 0, vy: -260, radius: 11)
            }
        case .geyser:
            // İşaretli yerden yukarı fışkırıp geri düşen çamur topakları.
            for index in 0..<4 {
                let spreadX = (Double(index) - 1.5) * 9
                add(x: fight.targetX + spreadX, y: arenaY + 6, vx: spreadX * 2.2,
                    vy: 520 + Double(index % 2) * 120, radius: 12, ay: -900)
            }
        case .ring:
            let count = fight.phase == 3 ? 12 : 10
            let turn = bossRNG.nextUnit() * .pi
            for index in 0..<count {
                let angle = turn + Double(index) / Double(count) * 2 * .pi
                add(x: fight.x, y: fight.y, vx: cos(angle) * 170, vy: sin(angle) * 170, radius: 10)
            }
        case .laser:
            // İşaretli sütun boyunca hızla inen ışın parçaları.
            for index in 0..<9 {
                add(x: fight.targetX, y: fight.y - 30 + Double(index) * 34, vx: 0, vy: -720, radius: 13)
            }
        case .bounce:
            // Oyuncuya doğru kavisle atılan, zeminde seken üç parça.
            let toward = x < fight.x ? -1.0 : 1.0
            for index in 0..<3 {
                add(x: mouthX, y: mouthY, vx: toward * (70 + Double(index) * 60), vy: 160,
                    radius: 12, ay: -900, bounces: true)
            }
        }
    }

    private mutating func nextProjectileID() -> Int {
        projectileCounter += 1
        return projectileCounter
    }
}
