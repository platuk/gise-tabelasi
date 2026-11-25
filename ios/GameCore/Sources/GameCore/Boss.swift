import Foundation

/// Ahtapotun saldırıları. Her saldırıdan önce bir uyarı (telegraph) gelir.
public enum BossAttack: String, Equatable, Sendable, CaseIterable {
    /// Yelpaze şeklinde 5 ateş topu.
    case spread
    /// Oyuncuya nişanlı 3 mürekkep topu.
    case aimed
    /// Zeminde yandan gelen dalga: üstünden zıplanır.
    case wave
    /// Yukarıdan rastgele yerlere düşen mürekkep yağmuru.
    case rain
}

public enum ProjectileKind: String, Equatable, Sendable {
    case fireball
    case ink
    case wave
    /// Oyuncunun mermisi.
    case bullet
}

public struct Projectile: Equatable, Sendable, Identifiable {
    public let id: Int
    public let kind: ProjectileKind
    public internal(set) var x: Double
    public internal(set) var y: Double
    public let vx: Double
    public let vy: Double
    public let radius: Double
}

/// Bölüm sonundaki ahtapot boss'u. Can azaldıkça aşama değişir ve yeni saldırılar eklenir.
public struct BossFight: Equatable, Sendable {
    /// 1'den başlayan boss sırası (kat 1000 → 1).
    public let number: Int
    public let arenaFloor: Int
    public let maxHP: Int
    public internal(set) var hp: Int
    public internal(set) var x: Double
    public internal(set) var y: Double
    public internal(set) var time: Double = 0
    public internal(set) var attackTimer: Double = 1.6
    /// Uyarısı sürmekte olan saldırı (ahtapot kollarını kaldırmış, parlıyor).
    public internal(set) var telegraph: BossAttack?
    public internal(set) var telegraphLeft: Double = 0
    var attackIndex = 0

    /// 1: tam can, 2: üçte iki altı, 3: üçte bir altı.
    public var phase: Int {
        if hp * 3 > maxHP * 2 { return 1 }
        if hp * 3 > maxHP { return 2 }
        return 3
    }

    var attacks: [BossAttack] {
        switch phase {
        case 1: return [.spread, .wave]
        case 2: return [.spread, .aimed, .wave]
        default: return [.rain, .aimed, .spread, .wave]
        }
    }
}

extension TowerSimulation {
    /// Arena katına varıldı: dövüş başlar, oyuncu arenanın ortasına konur, film beklemeye alınır.
    mutating func startBoss(arenaFloor: Int) -> [TowerEvent] {
        let number = max(1, arenaFloor / max(1, config.chapterLength))
        let hp = config.bossBaseHP + config.bossHPPerChapter * (number - 1)
        let arena = platform(floor: arenaFloor)
        boss = BossFight(number: number, arenaFloor: arenaFloor, maxHP: hp, hp: hp,
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

    /// Dövüşün bir adımı: boss hareketi, saldırılar, mermiler, çarpışmalar.
    mutating func stepBoss(dt: Double) -> [TowerEvent] {
        guard var fight = boss else { return [] }
        var events: [TowerEvent] = []
        let arenaY = Double(fight.arenaFloor) * config.floorSpacing

        // Hareket: yavaş yana salınım, hafif aşağı-yukarı.
        fight.time += dt
        fight.x = config.worldWidth / 2 + config.bossSway * sin(fight.time * 0.7)
        fight.y = arenaY + config.bossHeight + 18 * sin(fight.time * 1.3)

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
                fight.telegraphLeft = fight.phase == 3 ? config.telegraphTime * 0.7 : config.telegraphTime
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
            enemyShots[index].x += enemyShots[index].vx * dt
            enemyShots[index].y += enemyShots[index].vy * dt
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
        switch attack {
        case .spread:
            for index in 0..<5 {
                let angle = -Double.pi / 2 + (Double(index) - 2) * (50.0 / 2 * .pi / 180)
                enemyShots.append(Projectile(id: nextProjectileID(), kind: .fireball, x: mouthX, y: mouthY,
                                             vx: cos(angle) * 230, vy: sin(angle) * 230, radius: 12))
            }
        case .aimed:
            let base = atan2((y + config.playerHeight / 2) - mouthY, x - mouthX)
            for offset in [-0.18, 0, 0.18] {
                enemyShots.append(Projectile(id: nextProjectileID(), kind: .ink, x: mouthX, y: mouthY,
                                             vx: cos(base + offset) * 300, vy: sin(base + offset) * 300, radius: 11))
            }
        case .wave:
            // Oyuncudan uzak duvardan çıkar ki tepki süresi olsun.
            let fromLeft = x > config.worldWidth / 2
            let startX = fromLeft ? config.playMinX : config.playMaxX
            enemyShots.append(Projectile(id: nextProjectileID(), kind: .wave, x: startX, y: arenaY + 16,
                                         vx: fromLeft ? 280 : -280, vy: 0, radius: 18))
        case .rain:
            let lanes = 6
            let laneWidth = (config.playMaxX - config.playMinX) / Double(lanes)
            for lane in 0..<lanes {
                let jitter = (bossRNG.nextUnit() - 0.5) * laneWidth * 0.6
                let laneX = config.playMinX + laneWidth * (Double(lane) + 0.5) + jitter
                enemyShots.append(Projectile(id: nextProjectileID(), kind: .ink, x: laneX,
                                             y: fight.y + 60 + bossRNG.nextUnit() * 120,
                                             vx: 0, vy: -260, radius: 11))
            }
        }
    }

    private mutating func nextProjectileID() -> Int {
        projectileCounter += 1
        return projectileCounter
    }
}
