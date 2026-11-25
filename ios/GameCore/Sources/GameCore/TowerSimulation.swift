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

public enum TowerEvent: Equatable, Sendable {
    /// `power`: 0 (duran) ile 1 (tam hız) arası.
    case jumped(power: Double)
    case landed(floor: Int, floorsClimbed: Int)
    case wallBounce(side: Int)
    case comboExtended(jumps: Int, floors: Int)
    case comboEnded(jumps: Int, floors: Int, points: Int)
    case newMilestone(floor: Int)
    /// Her 100 katta bir kupa: bu kat aynı zamanda kayıt noktası ve yeni bölümün başı.
    case trophyEarned(floor: Int)
    case burnStarted
    case died
}

/// Oyunun tüm kuralları. Arayüzden bağımsız, sabit zaman adımlı, tamamen deterministik.
///
/// Kurallar:
/// - Koştukça hız kazanılır; hızlı koşan daha yükseğe zıplar.
/// - Kirişler tek yönlüdür: alttan geçilir, üstten basılır.
/// - Duvara çarpan oyuncu hızını büyük ölçüde koruyarak geri seker.
/// - 2 veya daha fazla kat atlayan iniş kombo başlatır/uzatır (3 sn içinde).
///   Kombo; tek kat atlanınca, aşağı düşülünce ya da süre dolunca biter.
///   En az 2 zıplamalık kombo, (kat sayısı)² puan verir.
/// - Her 100 katta bir kupa kazanılır; o kat kayıt noktasıdır ve yeni bölüm başlar.
/// - Kayan kirişler üzerindeki oyuncuyu taşır; kaygan kirişlerde sürtünme düşüktür.
/// - Başlangıçtan 5 kat sonra alttan yanan film yükselir; ona yakalanan oyun biter.
public struct TowerSimulation: Sendable {
    public let config: TowerConfig
    public let startFloor: Int
    private var generator: PlatformGenerator

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
    public internal(set) var elapsed: Double = 0

    private var coyoteTimer: Double = 0
    private var jumpBuffer: Double = 0
    private var burnElapsed: Double = 0

    /// `startFloor`: kayıt noktasından başlamak için (ör. 100, 200). Kat 0'dan başlamak için 0.
    public init(config: TowerConfig = TowerConfig(), seed: UInt64, startFloor: Int = 0) {
        self.config = config
        var generator = PlatformGenerator(config: config, seed: seed)
        let start = generator.platform(floor: max(0, startFloor))
        self.generator = generator
        self.startFloor = start.floor
        self.x = start.centerX
        self.y = start.y
        self.currentFloor = start.floor
        self.highestFloor = start.floor
        self.burnY = start.y - config.burnStartDistance
    }

    public var score: Int { highestFloor * 10 + comboPoints }

    /// Şu ana kadar kazanılan en yüksek kupanın katı (kayıt noktası). Hiç yoksa 0.
    public var checkpointFloor: Int {
        highestFloor / config.milestoneInterval * config.milestoneInterval
    }

    public mutating func platform(floor: Int) -> Platform {
        generator.platform(floor: floor)
    }

    /// Kirişin şu anki konumu (kayan kirişler zamanla yer değiştirir).
    public mutating func bounds(floor: Int) -> (minX: Double, maxX: Double) {
        platform(floor: floor).bounds(at: elapsed)
    }

    public mutating func step(dt: Double, input: TowerInput) -> [TowerEvent] {
        guard !isDead, dt > 0 else { return [] }
        var events: [TowerEvent] = []
        let previousTime = elapsed
        elapsed += dt

        let direction = input.direction.signum()
        jumpBuffer = input.jump ? config.jumpBufferTime : max(0, jumpBuffer - dt)
        coyoteTimer = isGrounded ? config.coyoteTime : max(0, coyoteTimer - dt)

        let standing: Platform? = isGrounded ? platform(floor: currentFloor) : nil
        let onSlippery = standing?.isSlippery ?? false

        // Yatay hareket
        if direction != 0 {
            facing = direction
            let acceleration: Double
            if isGrounded {
                acceleration = onSlippery ? config.slipperyAcceleration : config.groundAcceleration
            } else {
                acceleration = config.airAcceleration
            }
            vx += Double(direction) * acceleration * dt
        } else if isGrounded {
            let friction = (onSlippery ? config.slipperyFriction : config.groundFriction) * dt
            vx = abs(vx) <= friction ? 0 : vx - friction * (vx > 0 ? 1 : -1)
        }
        vx = min(max(vx, -config.maxRunSpeed), config.maxRunSpeed)

        // Zıplama
        if jumpBuffer > 0 && coyoteTimer > 0 {
            vy = config.jumpVelocity(forSpeed: vx)
            isGrounded = false
            coyoteTimer = 0
            jumpBuffer = 0
            events.append(.jumped(power: abs(vx) / config.maxRunSpeed))
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

        // Duvarlardan sekme
        let half = config.playerWidth / 2
        if x - half < config.playMinX {
            x = config.playMinX + half
            if vx < 0 {
                vx = -vx * config.wallBounceDamping
                events.append(.wallBounce(side: -1))
            }
        } else if x + half > config.playMaxX {
            x = config.playMaxX - half
            if vx > 0 {
                vx = -vx * config.wallBounceDamping
                events.append(.wallBounce(side: 1))
            }
        }

        // Kirişin ucundan düşme
        if isGrounded, let standing, !supports(standing) {
            isGrounded = false
            vy = 0
        }

        // İniş: düşerken geçilen kirişlerden en üsttekine basılır.
        if !isGrounded && vy <= 0 {
            let top = Int((previousY / config.floorSpacing).rounded(.down))
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

        // Kombo süresi
        if var running = combo {
            running.timeLeft -= dt
            if running.timeLeft <= 0 {
                events += endCombo()
            } else {
                combo = running
            }
        }

        // Yanan film
        if !burnActive && highestFloor - startFloor >= config.burnStartFloor {
            burnActive = true
            burnY = y - config.burnStartDistance
            events.append(.burnStarted)
        }
        if burnActive {
            burnElapsed += dt
            burnSpeed = min(config.burnMaxSpeed, config.burnBaseSpeed + config.burnAcceleration * burnElapsed)
            burnY = max(burnY + burnSpeed * dt, y - config.burnMaxLag)
            if y < burnY {
                isDead = true
                events += endCombo()
                events.append(.died)
            }
        }

        return events
    }

    @discardableResult
    mutating func land(onFloor floor: Int) -> [TowerEvent] {
        var events: [TowerEvent] = []
        let target = platform(floor: floor)
        y = target.y
        vy = 0
        isGrounded = true
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
