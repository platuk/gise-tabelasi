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
        for _ in 0..<Int((sim.config.comboWindow + 0.2) / dt) {
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
        for floor in 1...99 { XCTAssertEqual(generator.platform(floor: floor).kind, .steel, "kat \(floor)") }
        for floor in 101...199 {
            guard case .sliding = generator.platform(floor: floor).kind else { return XCTFail("kat \(floor) kaymalı") }
        }
        for floor in 201...299 { XCTAssertEqual(generator.platform(floor: floor).kind, .slippery, "kat \(floor)") }
        var kinds = Set<String>()
        for floor in 301...399 {
            switch generator.platform(floor: floor).kind {
            case .steel: kinds.insert("steel")
            case .sliding: kinds.insert("sliding")
            case .slippery: kinds.insert("slippery")
            }
        }
        XCTAssertEqual(kinds, ["steel", "sliding", "slippery"])
        for floor in [100, 200, 300, 400] {
            let milestone = generator.platform(floor: floor)
            XCTAssertTrue(milestone.isMilestone)
            XCTAssertEqual(milestone.kind, .steel)
        }
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
        var slippery = TowerSimulation(seed: 9)
        slippery.x = slippery.platform(floor: 250).centerX
        slippery.land(onFloor: 250)
        slippery.vx = 200
        for _ in 0..<15 {
            _ = steel.step(dt: dt, input: TowerInput())
            _ = slippery.step(dt: dt, input: TowerInput())
        }
        XCTAssertEqual(steel.vx, 0)
        // Duvara çarpıp sekmiş olabilir; önemli olan hızın büyük ölçüde korunması.
        XCTAssertGreaterThan(abs(slippery.vx), 120)
    }

    func testSlidingGirderCarriesPlayer() {
        var sim = TowerSimulation(seed: 11)
        let floor = 150
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

    func testSlowWallTouchIsNotAKick() {
        var sim = TowerSimulation(seed: 1)
        sim.isGrounded = false
        // Alttaki kirişten 70 pt yukarıda: yardımcı el devreye girmesin, yalnızca duvar test edilsin.
        sim.y = 230
        sim.x = sim.config.playMaxX - sim.config.playerWidth / 2 - 1
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
        for _ in 0..<Int(sim.config.boostDuration / dt) + 10 {
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
        XCTAssertEqual(sim.elapsed, 1.0 * sim.config.slowFactor, accuracy: 0.01)
        XCTAssertEqual(sim.slowRemaining, sim.config.slowDuration - 1, accuracy: 0.01)
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
    private func botClimb(seed: UInt64, startFloor: Int, floors: Int, seconds: Double) -> Int {
        var config = TowerConfig()
        config.burnStartFloor = .max
        var sim = TowerSimulation(config: config, seed: seed, startFloor: startFloor)
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

    func testBotCanClimbSteelChapter() {
        for seed: UInt64 in [1, 42, 2026] {
            XCTAssertGreaterThanOrEqual(botClimb(seed: seed, startFloor: 0, floors: 40, seconds: 180), 40, "tohum \(seed)")
        }
    }

    func testBotCanClimbSlidingChapter() {
        for seed: UInt64 in [1, 42, 2026] {
            XCTAssertGreaterThanOrEqual(botClimb(seed: seed, startFloor: 100, floors: 20, seconds: 240), 20, "tohum \(seed)")
        }
    }

    func testBotCanClimbSlipperyChapter() {
        for seed: UInt64 in [1, 42, 2026] {
            XCTAssertGreaterThanOrEqual(botClimb(seed: seed, startFloor: 200, floors: 20, seconds: 240), 20, "tohum \(seed)")
        }
    }

    func testBotCanClimbMixedChapter() {
        for seed: UInt64 in [1, 42, 2026] {
            XCTAssertGreaterThanOrEqual(botClimb(seed: seed, startFloor: 300, floors: 20, seconds: 240), 20, "tohum \(seed)")
        }
    }
}
