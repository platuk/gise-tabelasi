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
        XCTAssertGreaterThan(slippery.vx, 150)
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

    // MARK: Oynanabilirlik

    /// Basit bir bot her bölümü tırmanabilmeli: kuralların ve kiriş yerleşiminin oynanabilir olduğunun kanıtı.
    private func botClimb(seed: UInt64, startFloor: Int, floors: Int, seconds: Double) -> Int {
        var config = TowerConfig()
        config.burnStartFloor = .max
        var sim = TowerSimulation(config: config, seed: seed, startFloor: startFloor)
        var time = 0.0
        while time < seconds && sim.highestFloor < startFloor + floors {
            let target = sim.bounds(floor: sim.currentFloor + 1)
            let center = (target.minX + target.maxX) / 2
            let dx = center - sim.x
            let direction = abs(dx) < 6 ? 0 : (dx > 0 ? 1 : -1)
            let jump = sim.isGrounded && abs(dx) < (target.maxX - target.minX) / 2 + 40
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
}
