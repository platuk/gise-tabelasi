import XCTest
@testable import GameCore

final class TowerTests: XCTestCase {
    private let dt = 1.0 / 120.0

    // MARK: Platformlar

    func testSameSeedBuildsSameTower() {
        var a = PlatformGenerator(config: TowerConfig(), seed: 99)
        var b = PlatformGenerator(config: TowerConfig(), seed: 99)
        for floor in 0...300 {
            XCTAssertEqual(a.platform(floor: floor), b.platform(floor: floor))
        }
        var c = PlatformGenerator(config: TowerConfig(), seed: 100)
        XCTAssertNotEqual((1...20).map { a.platform(floor: $0) }, (1...20).map { c.platform(floor: $0) })
    }

    func testPlatformsAreFair() {
        let config = TowerConfig()
        for seed: UInt64 in [1, 2, 3, 42, 12345] {
            var generator = PlatformGenerator(config: config, seed: seed)
            var previous = generator.platform(floor: 0)
            XCTAssertEqual(previous.minX, config.playMinX)
            XCTAssertEqual(previous.maxX, config.playMaxX)
            for floor in 1...1000 {
                let p = generator.platform(floor: floor)
                XCTAssertEqual(p.y, Double(floor) * config.floorSpacing)
                XCTAssertGreaterThanOrEqual(p.minX, config.playMinX - 1e-9)
                XCTAssertLessThanOrEqual(p.maxX, config.playMaxX + 1e-9)
                XCTAssertGreaterThanOrEqual(p.width, config.platformMinWidth - 1e-9)
                if floor % config.milestoneInterval == 0 {
                    XCTAssertTrue(p.isMilestone)
                    XCTAssertEqual(p.width, config.playMaxX - config.playMinX, accuracy: 1e-9)
                }
                // Kayan kiriş en uç konumlarında bile duvarların içinde kalır.
                XCTAssertGreaterThanOrEqual(p.minX - p.amplitude, config.playMinX - 1e-9, "tohum \(seed) kat \(floor)")
                XCTAssertLessThanOrEqual(p.maxX + p.amplitude, config.playMaxX + 1e-9, "tohum \(seed) kat \(floor)")
                let gap = max(0, max(p.minX, previous.minX) - min(p.maxX, previous.maxX))
                XCTAssertLessThanOrEqual(gap, config.platformMaxShift + config.slidingAmplitude.upperBound + 1e-9,
                                         "tohum \(seed) kat \(floor)")
                previous = p
            }
        }
    }

    // MARK: Zıplama fiziği

    func testJumpHeightsMatchDesign() {
        let config = TowerConfig()
        // Durarak zıplama bir kat çıkar ama iki kat çıkamaz.
        XCTAssertGreaterThan(config.jumpHeight(forSpeed: 0), config.floorSpacing * 1.5)
        XCTAssertLessThan(config.jumpHeight(forSpeed: 0), config.floorSpacing * 2)
        // Tam hızla zıplama en az dört kat çıkar.
        XCTAssertGreaterThan(config.jumpHeight(forSpeed: config.maxRunSpeed), config.floorSpacing * 4)
    }

    func testJumpingThroughPlatformFromBelowLandsOnIt() {
        var sim = TowerSimulation(seed: 7)
        sim.x = sim.platform(floor: 1).centerX
        var landedOnFirst = false
        var events = sim.step(dt: dt, input: TowerInput(jump: true))
        XCTAssertTrue(events.contains { if case .jumped = $0 { return true } else { return false } })
        for _ in 0..<240 {
            events = sim.step(dt: dt, input: TowerInput())
            if events.contains(.landed(floor: 1, floorsClimbed: 1)) {
                landedOnFirst = true
                break
            }
        }
        XCTAssertTrue(landedOnFirst)
        XCTAssertEqual(sim.currentFloor, 1)
        XCTAssertTrue(sim.isGrounded)
    }

    func testRunningBuildsSpeedAndFrictionStopsIt() {
        var sim = TowerSimulation(seed: 1)
        sim.x = sim.config.playMinX + 20 // duvara çarpmadan hızlanacak yer olsun
        for _ in 0..<60 { _ = sim.step(dt: dt, input: TowerInput(direction: 1)) }
        XCTAssertGreaterThan(sim.vx, 300)
        XCTAssertEqual(sim.facing, 1)
        for _ in 0..<120 { _ = sim.step(dt: dt, input: TowerInput()) }
        XCTAssertEqual(sim.vx, 0)
    }

    func testWallBounceKeepsMostOfTheSpeed() {
        var sim = TowerSimulation(seed: 1)
        sim.x = sim.config.playMaxX - sim.config.playerWidth / 2 - 1
        sim.vx = sim.config.maxRunSpeed
        let events = sim.step(dt: dt, input: TowerInput(direction: 1))
        XCTAssertTrue(events.contains(.wallBounce(side: 1)))
        XCTAssertLessThan(sim.vx, -sim.config.maxRunSpeed * 0.8)
        XCTAssertLessThanOrEqual(sim.x + sim.config.playerWidth / 2, sim.config.playMaxX)
    }

    func testJumpBufferRemembersEarlyPress() {
        var sim = TowerSimulation(seed: 1)
        sim.isGrounded = false
        sim.y = 2
        sim.vy = -10
        // Yere değmeden hemen önce basıldı.
        _ = sim.step(dt: dt, input: TowerInput(jump: true))
        var jumped = false
        for _ in 0..<10 {
            if sim.step(dt: dt, input: TowerInput()).contains(where: { if case .jumped = $0 { return true } else { return false } }) {
                jumped = true
                break
            }
        }
        XCTAssertTrue(jumped)
    }

    // MARK: Kombo ve puan

    func testComboCountsMultiFloorJumpsAndScoresSquare() {
        var sim = TowerSimulation(seed: 3)
        XCTAssertTrue(sim.land(onFloor: 2).contains(.comboExtended(jumps: 1, floors: 2)))
        XCTAssertTrue(sim.land(onFloor: 5).contains(.comboExtended(jumps: 2, floors: 5)))
        XCTAssertTrue(sim.land(onFloor: 6).contains(.comboEnded(jumps: 2, floors: 5, points: 25)))
        XCTAssertNil(sim.combo)
        XCTAssertEqual(sim.comboPoints, 25)
        XCTAssertEqual(sim.score, 6 * 10 + 25)
    }

    func testSingleJumpComboGivesNoPoints() {
        var sim = TowerSimulation(seed: 3)
        sim.land(onFloor: 3)
        XCTAssertTrue(sim.land(onFloor: 4).contains(.comboEnded(jumps: 1, floors: 3, points: 0)))
        XCTAssertEqual(sim.comboPoints, 0)
    }

    func testComboExpiresAfterWindow() {
        var sim = TowerSimulation(seed: 3)
        sim.x = sim.platform(floor: 2).centerX
        sim.land(onFloor: 2)
        var ended = false
        // Kombo süresi dünya zamanıyla akar; oyun sakin tempoda başladığı için gerçek süre biraz daha uzun.
        for _ in 0..<Int((sim.config.comboWindow / sim.config.paceStart + 0.2) / dt) {
            if sim.step(dt: dt, input: TowerInput()).contains(.comboEnded(jumps: 1, floors: 2, points: 0)) {
                ended = true
                break
            }
        }
        XCTAssertTrue(ended)
        XCTAssertNil(sim.combo)
    }

    func testMilestoneEventEveryCardInterval() {
        var sim = TowerSimulation(seed: 3)
        XCTAssertFalse(sim.land(onFloor: 24).contains(.newMilestone(floor: 25)))
        XCTAssertTrue(sim.land(onFloor: 27).contains(.newMilestone(floor: 25)))
        XCTAssertFalse(sim.land(onFloor: 26).contains { if case .newMilestone = $0 { return true } else { return false } })
    }

    // MARK: Yanan film

    func testBurningFilmStartsAndEventuallyCatchesIdlePlayer() {
        var sim = TowerSimulation(seed: 1)
        sim.land(onFloor: sim.config.burnStartFloor)
        XCTAssertTrue(sim.step(dt: dt, input: TowerInput()).contains(.burnStarted))
        var died = false
        for _ in 0..<(120 * 60) {
            if sim.step(dt: dt, input: TowerInput()).contains(.died) {
                died = true
                break
            }
        }
        XCTAssertTrue(died)
        XCTAssertTrue(sim.isDead)
        XCTAssertEqual(sim.step(dt: dt, input: TowerInput(direction: 1, jump: true)), [])
    }

    func testBurnNeverLagsTooFarBehind() {
        var sim = TowerSimulation(seed: 1)
        sim.land(onFloor: sim.config.burnStartFloor)
        _ = sim.step(dt: dt, input: TowerInput())
        sim.land(onFloor: 400)
        _ = sim.step(dt: dt, input: TowerInput())
        XCTAssertGreaterThanOrEqual(sim.burnY, sim.y - sim.config.burnMaxLag - 1)
    }

    // MARK: Bölümler, kupalar, kayıt noktası

    func testChapterKinds() {
        var generator = PlatformGenerator(config: TowerConfig(), seed: 5)
        for floor in 1...999 where floor % 100 != 0 {
            XCTAssertEqual(generator.platform(floor: floor).kind, .steel, "kat \(floor)")
        }
        for floor in 1001...1999 where floor % 100 != 0 {
            guard case .sliding = generator.platform(floor: floor).kind else { return XCTFail("kat \(floor) kaymalı") }
        }
        for floor in 2001...2999 where floor % 100 != 0 {
            XCTAssertEqual(generator.platform(floor: floor).kind, .slippery, "kat \(floor)")
        }
        var kinds = Set<String>()
        for floor in 3001...3199 where floor % 100 != 0 {
            switch generator.platform(floor: floor).kind {
            case .steel: kinds.insert("steel")
            case .sliding: kinds.insert("sliding")
            case .slippery: kinds.insert("slippery")
            }
        }
        XCTAssertEqual(kinds, ["steel", "sliding", "slippery"])
        for floor in [100, 500, 1000, 2000, 3000] {
            let milestone = generator.platform(floor: floor)
            XCTAssertTrue(milestone.isMilestone)
            XCTAssertEqual(milestone.kind, .steel)
        }
        // Her bölüm geniş kirişlerle başlar, sonuna doğru daralır.
        XCTAssertGreaterThan(generator.platform(floor: 1001).width, generator.platform(floor: 1990).width)
    }

    func testTrophyEveryHundredFloorsReplacesMilestoneCard() {
        var sim = TowerSimulation(seed: 3)
        XCTAssertFalse(sim.land(onFloor: 99).contains(.trophyEarned(floor: 100)))
        let events = sim.land(onFloor: 102) // 100'ün üzerinden atlanarak geçildi
        XCTAssertTrue(events.contains(.trophyEarned(floor: 100)))
        XCTAssertFalse(events.contains(.newMilestone(floor: 100)))
        XCTAssertEqual(sim.checkpointFloor, 100)
        XCTAssertTrue(sim.land(onFloor: 126).contains(.newMilestone(floor: 125)))
        XCTAssertTrue(sim.land(onFloor: 200).contains(.trophyEarned(floor: 200)))
        XCTAssertEqual(sim.checkpointFloor, 200)
    }

    func testStartingFromCheckpoint() {
        var sim = TowerSimulation(seed: 1, startFloor: 200)
        XCTAssertEqual(sim.startFloor, 200)
        XCTAssertEqual(sim.highestFloor, 200)
        XCTAssertEqual(sim.currentFloor, 200)
        XCTAssertEqual(sim.y, 200 * sim.config.floorSpacing)
        XCTAssertTrue(sim.isGrounded)
        // Film, başlangıçtan 5 kat sonra başlar; kayıt noktasında hemen başlamaz.
        for _ in 0..<120 { XCTAssertFalse(sim.step(dt: dt, input: TowerInput()).contains(.burnStarted)) }
        XCTAssertTrue(sim.isGrounded)
        sim.land(onFloor: 205)
        XCTAssertTrue(sim.step(dt: dt, input: TowerInput()).contains(.burnStarted))
    }

    func testSlipperyGirderKeepsSliding() {
        var steel = TowerSimulation(seed: 9)
        steel.x = steel.platform(floor: 50).centerX
        steel.land(onFloor: 50)
        steel.vx = 200
        var slippery = TowerSimulation(seed: 9, startFloor: 2200)
        slippery.x = slippery.platform(floor: 2250).centerX
        slippery.land(onFloor: 2250)
        slippery.vx = 200
        // Çelikte sürtünme hızı tamamen keser; aynı sürede kaygan kirişte hız büyük ölçüde korunur.
        for _ in 0..<26 {
            _ = steel.step(dt: dt, input: TowerInput())
            _ = slippery.step(dt: dt, input: TowerInput())
        }
        XCTAssertEqual(steel.vx, 0)
        // Duvara çarpıp sekmiş olabilir; önemli olan hızın büyük ölçüde korunması.
        XCTAssertGreaterThan(abs(slippery.vx), 85)
    }

    func testSlidingGirderCarriesPlayer() {
        var sim = TowerSimulation(seed: 11, startFloor: 1100)
        let floor = 1150
        let start = sim.bounds(floor: floor)
        sim.x = (start.minX + start.maxX) / 2
        sim.land(onFloor: floor)
        let relative = sim.x - (start.minX + start.maxX) / 2
        var moved = 0.0
        for _ in 0..<120 {
            let before = sim.x
            _ = sim.step(dt: dt, input: TowerInput())
            moved += abs(sim.x - before)
            XCTAssertTrue(sim.isGrounded)
        }
        let now = sim.bounds(floor: floor)
        XCTAssertEqual(sim.x - (now.minX + now.maxX) / 2, relative, accuracy: 0.5)
        XCTAssertGreaterThan(moved, 1)
    }

    // MARK: Gizli yardım ve duvar taklası

    func testLandingAssistSavesNearMiss() {
        var sim = TowerSimulation(seed: 7)
        let girder = sim.platform(floor: 1)
        let foot = sim.config.playerWidth * 0.3
        // Kenarı 10 pt kaçıracak şekilde, kirişin hemen üstünden düşüyor.
        sim.isGrounded = false
        sim.x = girder.maxX + foot + 10
        sim.y = girder.y + 30
        sim.vy = -100
        var landedFloor: Int?
        for _ in 0..<120 {
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .landed(let floor, _) = event { landedFloor = floor }
            }
            if landedFloor != nil { break }
        }
        XCTAssertEqual(landedFloor, 1)
    }

    func testLandingAssistDoesNotRescueClearMiss() {
        var sim = TowerSimulation(seed: 7)
        let girder = sim.platform(floor: 1)
        let foot = sim.config.playerWidth * 0.3
        sim.isGrounded = false
        sim.x = min(sim.config.playMaxX - 14, girder.maxX + foot + 45)
        sim.y = girder.y + 30
        sim.vy = -100
        var landedFloor: Int?
        for _ in 0..<240 {
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .landed(let floor, _) = event { landedFloor = floor }
            }
            if landedFloor != nil { break }
        }
        if girder.maxX + foot + 45 <= sim.config.playMaxX - 14 {
            XCTAssertEqual(landedFloor, 0)
        }
    }

    func testWallKickLaunchesUpward() {
        var sim = TowerSimulation(seed: 1)
        sim.isGrounded = false
        sim.y = 200
        sim.vy = -50
        sim.x = sim.config.playMaxX - sim.config.playerWidth / 2 - 1
        sim.vx = sim.config.maxRunSpeed
        let events = sim.step(dt: dt, input: TowerInput(direction: 1))
        XCTAssertTrue(events.contains(.wallKick(side: 1)))
        XCTAssertGreaterThan(sim.vy, sim.config.wallKickVelocity * 0.9)
        XCTAssertLessThan(sim.vx, 0)
        XCTAssertTrue(sim.wallKickGuiding)
    }

    func testWallKicksAreLimitedUntilLanding() {
        var sim = TowerSimulation(seed: 1)
        func slamRightWall() -> Bool {
            sim.isGrounded = false
            sim.y = 430 // iki kirişin arası: bu adımda inilmez
            sim.vy = -50
            sim.x = sim.config.playMaxX - sim.config.playerWidth / 2 - 1
            sim.vx = sim.config.maxRunSpeed
            return sim.step(dt: dt, input: TowerInput(direction: 1)).contains(.wallKick(side: 1))
        }
        var kicks = 0
        for _ in 0..<(sim.config.maxWallKicks + 5) where slamRightWall() { kicks += 1 }
        XCTAssertEqual(kicks, sim.config.maxWallKicks)
        XCTAssertEqual(sim.wallKicksSinceLanding, sim.config.maxWallKicks)
        // 11. çarpış: duvar yalnızca seker, yükseltmez.
        XCTAssertFalse(slamRightWall())
        XCTAssertLessThan(sim.vy, 0)
        // Bir kirişe basınca sayaç sıfırlanır.
        sim.land(onFloor: 4)
        XCTAssertEqual(sim.wallKicksSinceLanding, 0)
        XCTAssertTrue(slamRightWall())
    }

    func testSlowWallTouchIsNotAKick() {
        // Yardımcı el kapalı: yalnızca duvar davranışı ölçülsün (yoksa oyuncuyu duvardan önce kirişe çekebilir).
        var config = TowerConfig()
        config.landingAssistMargin = 0
        var sim = TowerSimulation(config: config, seed: 1)
        sim.isGrounded = false
        sim.y = 230
        // Duvara yarım nokta: sakin başlangıç temposunda bile bu adımda duvara değer.
        sim.x = sim.config.playMaxX - sim.config.playerWidth / 2 - 0.5
        sim.vx = 150
        let events = sim.step(dt: dt, input: TowerInput())
        XCTAssertTrue(events.contains(.wallBounce(side: 1)))
        XCTAssertFalse(events.contains(.wallKick(side: 1)))
    }

    // MARK: Baloncuklar

    func testBubblesAreDeterministicAndVaried() {
        let config = TowerConfig()
        var a = PlatformGenerator(config: config, seed: 77)
        var b = PlatformGenerator(config: config, seed: 77)
        var kinds = Set<PowerUp>()
        var count = 0
        for floor in 0...1500 {
            let p = a.platform(floor: floor)
            XCTAssertEqual(p.bubble, b.platform(floor: floor).bubble)
            if let bubble = p.bubble {
                XCTAssertGreaterThanOrEqual(floor, config.bubbleMinFloor)
                XCTAssertFalse(p.isMilestone)
                kinds.insert(bubble)
                count += 1
            }
        }
        XCTAssertEqual(kinds, Set(PowerUp.allCases))
        XCTAssertGreaterThan(count, 60)
        XCTAssertLessThan(count, 200)
    }

    /// Baloncuklu bir kirişin ortasında durup düz zıplayan oyuncu baloncuğu alır.
    private func collectFirstBubble(_ kind: PowerUp, seed: UInt64 = 21) -> (TowerSimulation, [TowerEvent])? {
        var sim = TowerSimulation(seed: seed)
        guard let floor = (8..<2000).first(where: { sim.platform(floor: $0).bubble == kind }) else { return nil }
        sim.x = sim.platform(floor: floor).centerX
        sim.land(onFloor: floor)
        var events = sim.step(dt: dt, input: TowerInput(jump: true))
        for _ in 0..<120 where !events.contains(.powerUp(kind)) {
            events += sim.step(dt: dt, input: TowerInput())
        }
        return events.contains(.powerUp(kind)) ? (sim, events) : nil
    }

    func testBoostBubbleFliesFiftyFloors() throws {
        var (sim, _) = try XCTUnwrap(collectFirstBubble(.boost))
        let from = sim.boost?.targetFloor ?? -1
        XCTAssertNotNil(sim.boost)
        var finished: Int?
        // Yolda ağır çekim baloncuğu da alınmış olabilir: en yavaş tempoya göre süre tanınır.
        for _ in 0..<Int(sim.config.boostDuration / (sim.config.paceStart * sim.config.slowFactor) / dt) + 10 {
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .boostFinished(let floor) = event { finished = floor }
            }
            if finished != nil { break }
        }
        XCTAssertEqual(finished, from)
        XCTAssertEqual(sim.currentFloor, from)
        XCTAssertGreaterThanOrEqual(sim.highestFloor, from)
        XCTAssertTrue(sim.isGrounded)
        XCTAssertNil(sim.boost)
    }

    func testEachBubbleCanBeCollected() throws {
        for kind in PowerUp.allCases {
            XCTAssertNotNil(collectFirstBubble(kind), "\(kind)")
        }
    }

    func testSlowTimeSlowsTheWorld() {
        var sim = TowerSimulation(seed: 1)
        sim.apply(.slowTime)
        for _ in 0..<120 { _ = sim.step(dt: dt, input: TowerInput()) }
        XCTAssertEqual(sim.elapsed, 1.0 * sim.config.slowFactor * sim.config.pace(forFloor: 0), accuracy: 0.01)
        XCTAssertEqual(sim.slowRemaining, sim.config.slowDuration - 1, accuracy: 0.01)
    }

    // MARK: Tempo

    func testPaceStartsCalmAndRisesWithFloors() {
        let config = TowerConfig()
        XCTAssertEqual(config.pace(forFloor: 0), config.paceStart, accuracy: 1e-9)
        XCTAssertLessThan(config.pace(forFloor: 0), 1)
        XCTAssertEqual(config.pace(forFloor: 2000), 1, accuracy: 1e-9)
        XCTAssertGreaterThan(config.pace(forFloor: 2000), config.pace(forFloor: 1000))
        XCTAssertEqual(config.pace(forFloor: 100_000), config.paceMax, accuracy: 1e-9)
        // Yanan filmin azami hızı her bölümde artar, ama bir tavanı vardır.
        XCTAssertLessThan(config.burnSpeedLimit(forFloor: 10), config.burnSpeedLimit(forFloor: 1500))
        XCTAssertEqual(config.burnSpeedLimit(forFloor: 100_000), config.burnMaxSpeedCap, accuracy: 1e-9)

        // Aynı gerçek sürede, yukarıdaki katlarda dünya daha hızlı akar.
        var low = TowerSimulation(seed: 1)
        var high = TowerSimulation(seed: 1, startFloor: 2900)
        for _ in 0..<120 {
            _ = low.step(dt: dt, input: TowerInput())
            _ = high.step(dt: dt, input: TowerInput())
        }
        XCTAssertEqual(low.elapsed, config.paceStart, accuracy: 0.01)
        XCTAssertGreaterThan(high.elapsed, 1.0)
    }

    func testAdrenalineRaisesTopSpeed() {
        var sim = TowerSimulation(seed: 1)
        sim.x = sim.config.playMinX + 20
        sim.apply(.adrenaline)
        for _ in 0..<50 { _ = sim.step(dt: dt, input: TowerInput(direction: 1)) }
        XCTAssertGreaterThan(sim.vx, sim.config.maxRunSpeed)
    }

    func testShieldBouncesOffTheBurn() {
        var sim = TowerSimulation(seed: 1)
        sim.land(onFloor: sim.config.burnStartFloor)
        _ = sim.step(dt: dt, input: TowerInput())
        sim.apply(.shield)
        sim.burnY = sim.y + 5
        let events = sim.step(dt: dt, input: TowerInput())
        XCTAssertTrue(events.contains(.shieldSaved))
        XCTAssertFalse(sim.isDead)
        XCTAssertLessThan(sim.burnY, sim.y)
    }

    // MARK: Diriliş

    func testOneFreeRespawn() {
        var sim = TowerSimulation(seed: 1)
        sim.land(onFloor: sim.config.burnStartFloor)
        func runUntilDeath() -> Bool {
            for _ in 0..<(120 * 90) where sim.step(dt: dt, input: TowerInput()).contains(.died) { return true }
            return sim.isDead
        }
        XCTAssertTrue(runUntilDeath())
        XCTAssertTrue(sim.canRespawn)
        let events = sim.respawn()
        guard case .respawned(let floor)? = events.first else { return XCTFail("diriliş olmadı") }
        XCTAssertFalse(sim.isDead)
        XCTAssertTrue(sim.isGrounded)
        XCTAssertEqual(sim.currentFloor, floor)
        XCTAssertLessThan(sim.burnY, sim.y)
        XCTAssertGreaterThan(sim.shieldRemaining, 0)
        XCTAssertTrue(runUntilDeath())
        XCTAssertFalse(sim.canRespawn)
        XCTAssertEqual(sim.respawn(), [])
    }

    // MARK: Oynanabilirlik

    /// Basit bir bot her bölümü tırmanabilmeli: kuralların ve kiriş yerleşiminin oynanabilir olduğunun kanıtı.
    private func botClimb(seed: UInt64, startFloor: Int, floors: Int, seconds: Double, speed: Double = 1) -> Int {
        var config = TowerConfig()
        config.burnStartFloor = .max
        config.speedMultiplier = speed
        // Bölüm başından (boss katından) başlanıyorsa boss yenilmiş sayılır; burada yalnızca tırmanış ölçülür.
        var sim = TowerSimulation(config: config, seed: seed, startFloor: startFloor, bossAlreadyDefeated: true)
        var time = 0.0
        while time < seconds && sim.highestFloor < startFloor + floors {
            // Bir insan gibi oynar:
            // - Yerde: hızını ön görerek hedef kirişe yönelir; altına gelince sakin zıplar,
            //   hedef yandaysa kirişin ucundan düşmeden çapraz zıplar.
            // - Havada: iniş anındaki konumunu tahmin edip hedefin ortasına yönelir.
            let target = sim.bounds(floor: sim.currentFloor + 1)
            let center = (target.minX + target.maxX) / 2
            let halfWidth = (target.maxX - target.minX) / 2
            var direction = 0
            var jump = false
            if sim.isGrounded {
                let dx = center - sim.x
                let lead = dx - sim.vx * 0.25
                direction = abs(lead) < 4 ? 0 : (lead > 0 ? 1 : -1)
                let current = sim.bounds(floor: sim.currentFloor)
                let nextX = sim.x + sim.vx * 0.06
                let atEdge = (dx > 0 && nextX > current.maxX) || (dx < 0 && nextX < current.minX)
                jump = (abs(dx) < halfWidth * 0.7 && abs(sim.vx) < 200) || atEdge
            } else {
                let targetY = Double(sim.currentFloor + 1) * config.floorSpacing
                let discriminant = sim.vy * sim.vy - 2 * config.gravity * (targetY - sim.y)
                let timeToLand = discriminant > 0 ? (sim.vy + discriminant.squareRoot()) / config.gravity : 0.2
                let error = center - (sim.x + sim.vx * timeToLand)
                direction = abs(error) < 3 ? 0 : (error > 0 ? 1 : -1)
            }
            _ = sim.step(dt: dt, input: TowerInput(direction: direction, jump: jump))
            time += dt
        }
        return sim.highestFloor - startFloor
    }

    /// Her bölümün hem geniş başı hem dar sonu denenir.
    private func assertBotClimbs(from starts: [Int], floors: Int, file: StaticString = #filePath, line: UInt = #line) {
        for start in starts {
            for seed: UInt64 in [1, 42, 2026] {
                XCTAssertGreaterThanOrEqual(botClimb(seed: seed, startFloor: start, floors: floors, seconds: 240), floors,
                                            "kat \(start) tohum \(seed)", file: file, line: line)
            }
        }
    }

    func testBotCanClimbSteelChapter() {
        XCTAssertGreaterThanOrEqual(botClimb(seed: 1, startFloor: 0, floors: 40, seconds: 180), 40)
        assertBotClimbs(from: [0, 900], floors: 20)
    }

    func testBotCanClimbSlidingChapter() {
        assertBotClimbs(from: [1000, 1900], floors: 20)
    }

    func testBotCanClimbSlipperyChapter() {
        assertBotClimbs(from: [2000, 2900], floors: 20)
    }

    func testBotCanClimbMixedChapter() {
        assertBotClimbs(from: [3000, 3500], floors: 20)
    }

    /// Orta ve hızlı oyun hızında da her bölüm tırmanılabilir.
    func testBotClimbsAtEverySpeed() {
        for speed in [1.15, 1.3] {
            for start in [0, 900, 1900, 2900, 3500] {
                XCTAssertGreaterThanOrEqual(botClimb(seed: 42, startFloor: start, floors: 20, seconds: 240, speed: speed), 20,
                                            "hız \(speed) kat \(start)")
            }
        }
        var fast = TowerConfig()
        fast.speedMultiplier = 1.3
        XCTAssertEqual(fast.pace(forFloor: 0), TowerConfig().pace(forFloor: 0) * 1.3, accuracy: 1e-9)
    }

    // MARK: Boss dövüşü

    func testBossStartsAtThousandAndLocksArena() {
        var sim = TowerSimulation(seed: 4, startFloor: 900)
        let events = sim.land(onFloor: 1003) // sınırın üstünden atlanarak geçildi
        XCTAssertTrue(events.contains(.bossStarted(number: 1)))
        XCTAssertTrue(events.contains(.trophyEarned(floor: 1000)))
        let fight = try? XCTUnwrap(sim.boss)
        XCTAssertEqual(fight?.arenaFloor, 1000)
        XCTAssertEqual(fight?.hp, sim.config.bossBaseHP)
        // Oyuncu arenaya indirildi.
        XCTAssertEqual(sim.currentFloor, 1000)
        XCTAssertEqual(sim.y, 1000 * sim.config.floorSpacing)
        XCTAssertEqual(sim.playerHP, sim.config.playerMaxHP)
        // Arenanın üstündeki kirişlere basılamaz: yukarıdan düşen oyuncu arenaya iner.
        sim.isGrounded = false
        sim.y = 1003 * sim.config.floorSpacing + 10
        sim.x = sim.platform(floor: 1003).centerX
        sim.vy = -10
        var landed: Int?
        for _ in 0..<240 {
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .landed(let floor, _) = event { landed = floor }
            }
            if landed != nil { break }
        }
        XCTAssertEqual(landed, 1000)
    }

    func testStartingAtBossFloorStartsFightUnlessDefeated() {
        let fresh = TowerSimulation(seed: 4, startFloor: 2000)
        XCTAssertEqual(fresh.boss?.number, 2)
        XCTAssertEqual(fresh.boss?.maxHP, fresh.config.bossBaseHP + fresh.config.bossHPPerChapter)
        let skipped = TowerSimulation(seed: 4, startFloor: 2000, bossAlreadyDefeated: true)
        XCTAssertNil(skipped.boss)
    }

    func testBurnIsPausedDuringBoss() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        for _ in 0..<(120 * 5) {
            let events = sim.step(dt: dt, input: TowerInput())
            XCTAssertFalse(events.contains(.burnStarted))
            XCTAssertFalse(events.contains(.died) && sim.burnY > sim.y)
        }
        XCTAssertLessThan(sim.burnY, sim.y - 1000)
    }

    func testBossTelegraphsBeforeAttacking() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        sim.shieldRemaining = 1_000 // yalnızca saldırı sırası ölçülsün
        var order: [String] = []
        for _ in 0..<(120 * 8) {
            for event in sim.step(dt: dt, input: TowerInput()) {
                switch event {
                case .bossAttackWarning(let attack): order.append("uyari-\(attack.rawValue)")
                case .bossAttack(let attack): order.append("atis-\(attack.rawValue)")
                default: break
                }
            }
        }
        XCTAssertGreaterThanOrEqual(order.count, 4)
        // Her atıştan hemen önce aynı saldırının uyarısı gelir.
        for (index, entry) in order.enumerated() where entry.hasPrefix("atis-") {
            XCTAssertGreaterThan(index, 0)
            XCTAssertEqual(order[index - 1], entry.replacingOccurrences(of: "atis-", with: "uyari-"))
        }
    }

    func testAutoFireDamagesBossWhenUnderIt() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        sim.shieldRemaining = 1_000
        let startHP = sim.boss?.hp ?? 0
        for _ in 0..<(120 * 4) {
            if let fight = sim.boss { sim.x = fight.x }
            _ = sim.step(dt: dt, input: TowerInput())
        }
        XCTAssertLessThan(sim.boss?.hp ?? 0, startHP - 8)
    }

    func testBossShotHurtsPlayerThenBriefInvulnerability() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        let body = (x: sim.x, y: sim.y + sim.config.playerHeight / 2)
        sim.enemyShots = [
            Projectile(id: 900, kind: .ink, x: body.x, y: body.y, vx: 0, vy: 0, radius: 11),
            Projectile(id: 901, kind: .ink, x: body.x, y: body.y + 2, vx: 0, vy: 0, radius: 11),
        ]
        let events = sim.step(dt: dt, input: TowerInput())
        XCTAssertTrue(events.contains(.playerHit(hp: sim.config.playerMaxHP - 1)))
        XCTAssertEqual(sim.playerHP, sim.config.playerMaxHP - 1)
        XCTAssertGreaterThan(sim.hurtTimer, 0)
    }

    func testLosingAllHealthKillsAndRespawnRestoresArena() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        sim.playerHP = 1
        sim.enemyShots = [Projectile(id: 1, kind: .fireball, x: sim.x, y: sim.y + 22, vx: 0, vy: 0, radius: 12)]
        XCTAssertTrue(sim.step(dt: dt, input: TowerInput()).contains(.died))
        XCTAssertTrue(sim.canRespawn)
        let bossHP = sim.boss?.hp
        XCTAssertEqual(sim.respawn(), [.respawned(floor: 1000)])
        XCTAssertEqual(sim.playerHP, sim.config.playerMaxHP)
        XCTAssertEqual(sim.boss?.hp, bossHP)
        XCTAssertTrue(sim.enemyShots.isEmpty)
    }

    func testBossKindsCycleEveryChapter() {
        XCTAssertEqual(BossKind.forNumber(1), .octopus)
        XCTAssertEqual(BossKind.forNumber(2), .worm)
        XCTAssertEqual(BossKind.forNumber(3), .bat)
        XCTAssertEqual(BossKind.forNumber(4), .alien)
        XCTAssertEqual(BossKind.forNumber(5), .robot)
        XCTAssertEqual(BossKind.forNumber(6), .bulldog)
        XCTAssertEqual(BossKind.forNumber(7), .octopus)
        XCTAssertEqual(TowerSimulation(seed: 4, startFloor: 3000).boss?.kind, .bat)
        // Her boss, her aşamada en az iki farklı saldırı yapar.
        for kind in BossKind.allCases {
            for phase in 1...3 {
                XCTAssertGreaterThanOrEqual(Set(kind.attacks(phase: phase)).count, 2, "\(kind) aşama \(phase)")
            }
        }
    }

    /// Oyuncu boss'un altında kalır (mermi yolculuğu kadar ileriyi tahmin ederek): her tür yenilebilmeli.
    func testEveryBossKindCanBeDefeated() {
        for kind in BossKind.allCases {
            var sim = TowerSimulation(seed: 4, startFloor: (kind.rawValue + 1) * 1000)
            XCTAssertEqual(sim.boss?.kind, kind)
            sim.shieldRemaining = 100_000
            var defeated = false
            var attacks = Set<BossAttack>()
            for _ in 0..<(120 * 240) {
                if let fight = sim.boss {
                    let lead = (fight.y - sim.y) / sim.config.bulletSpeed
                    let ahead = TowerSimulation.bossPosition(kind: kind, time: fight.time + lead,
                                                             centerX: sim.config.worldWidth / 2,
                                                             sway: sim.config.bossSway,
                                                             baseY: Double(fight.arenaFloor) * sim.config.floorSpacing + sim.config.bossHeight)
                    sim.x = ahead.0
                }
                for event in sim.step(dt: dt, input: TowerInput()) {
                    if case .bossAttack(let attack) = event { attacks.insert(attack) }
                    if case .bossDefeated = event { defeated = true }
                }
                if defeated { break }
            }
            XCTAssertTrue(defeated, "\(kind) yenilemedi")
            XCTAssertGreaterThanOrEqual(attacks.count, 2, "\(kind) saldırıları: \(attacks)")
        }
    }

    /// Işın, uyarıda işaretlenen sütuna düşer: oraya basan vurulur, kenara kaçan kurtulur.
    func testLaserHitsOnlyTheMarkedColumn() {
        func run(dodge: Double) -> Bool {
            var sim = TowerSimulation(seed: 4, startFloor: 4000) // uzaylı: ilk saldırı ışın
            sim.x = 120
            sim.boss?.attackTimer = 0
            var warned = false
            var hit = false
            for _ in 0..<(120 * 2) {
                for event in sim.step(dt: dt, input: TowerInput()) {
                    if case .bossAttackWarning(.laser) = event {
                        warned = true
                        XCTAssertEqual(sim.boss?.targetX ?? 0, 120, accuracy: 1)
                        sim.x += dodge
                    }
                    if case .playerHit = event { hit = true }
                }
            }
            XCTAssertTrue(warned)
            return hit
        }
        XCTAssertTrue(run(dodge: 0))
        XCTAssertFalse(run(dodge: 90))
    }

    func testBouncingShotsBounceAndExpire() {
        var sim = TowerSimulation(seed: 4, startFloor: 5000) // robot: ilk saldırı seken cıvatalar
        sim.shieldRemaining = 100_000
        sim.boss?.attackTimer = 0
        let arenaY = 5000 * sim.config.floorSpacing
        var sawBounce = false
        var everSpawned = false
        for _ in 0..<(120 * 4) {
            _ = sim.step(dt: dt, input: TowerInput())
            for shot in sim.enemyShots where shot.kind == .bolt {
                everSpawned = true
                XCTAssertGreaterThanOrEqual(shot.y, arenaY + shot.radius - 1)
                if shot.vy > 0 && shot.y < arenaY + 40 { sawBounce = true }
            }
        }
        XCTAssertTrue(everSpawned)
        XCTAssertTrue(sawBounce)
        for _ in 0..<(120 * 9) { _ = sim.step(dt: dt, input: TowerInput()) }
        XCTAssertFalse(sim.enemyShots.contains { $0.kind == .bolt && $0.age > 8.1 })
    }

    /// Yandan gelen dalga: uyarıda hangi duvardan geleceği belli olur ve zıplamaya hazırlanmak için en az 1.3 saniye vardır.
    func testWaveWarnsWhichSideWithTimeToJump() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000) // ahtapot, 1. aşama: yelpaze, dalga
        sim.shieldRemaining = 100_000
        sim.x = 100
        sim.boss?.attackIndex = 1
        sim.boss?.attackTimer = 0
        var warnedAt: Double?
        var firedAt: Double?
        var realTime = 0.0
        for _ in 0..<(120 * 4) {
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .bossAttackWarning(.wave) = event {
                    warnedAt = realTime
                    XCTAssertEqual(sim.boss?.waveFromLeft, false) // oyuncu solda: dalga sağdan gelir
                }
                if case .bossAttack(.wave) = event { firedAt = realTime }
            }
            realTime += dt
            if firedAt != nil { break }
        }
        let warned = try? XCTUnwrap(warnedAt)
        let fired = try? XCTUnwrap(firedAt)
        XCTAssertGreaterThanOrEqual((fired ?? 0) - (warned ?? 0), 1.3)
        XCTAssertTrue(sim.enemyShots.contains { $0.kind == .wave && $0.vx < 0 })
    }

    func testBossCanBeDefeatedAndClimbingResumes() {
        var sim = TowerSimulation(seed: 4, startFloor: 1000)
        sim.shieldRemaining = 10_000
        var defeated: (Int, Int)?
        for _ in 0..<(120 * 120) {
            if let fight = sim.boss { sim.x = fight.x }
            for event in sim.step(dt: dt, input: TowerInput()) {
                if case .bossDefeated(let number, let floor) = event { defeated = (number, floor) }
            }
            if defeated != nil { break }
        }
        XCTAssertEqual(defeated?.0, 1)
        XCTAssertEqual(defeated?.1, 1000)
        XCTAssertNil(sim.boss)
        XCTAssertTrue(sim.enemyShots.isEmpty)
        XCTAssertEqual(sim.defeatedBossFloor, 1000)
        XCTAssertGreaterThanOrEqual(sim.score, sim.config.bossDefeatBonus)
        // Artık arenanın üstündeki kirişlere basılabilir.
        XCTAssertTrue(sim.land(onFloor: 1001).contains(.landed(floor: 1001, floorsClimbed: 1)))
        XCTAssertNil(sim.boss)
    }
}
