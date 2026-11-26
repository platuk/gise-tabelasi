import XCTest
@testable import GameCore

/// Ekran görüntüsü modundaki otomatik pilot gerçekten oynayabilmeli: tırmanmalı, boss'a karşı hemen ölmemeli.
final class DemoPilotTests: XCTestCase {
    private let dt = 1.0 / 120.0

    func testPilotClimbs() {
        for start in [140, 2_460, 4_330] {
            var sim = TowerSimulation(seed: 2026, startFloor: start, bossAlreadyDefeated: true)
            var time = 0.0
            while time < 12 && !sim.isDead {
                var input = DemoPilot.input(for: &sim)
                input.jump = input.jump || sim.isGrounded
                _ = sim.step(dt: dt, input: input)
                time += dt
            }
            XCTAssertGreaterThanOrEqual(sim.highestFloor - start, 8, "kat \(start)")
        }
    }

    func testPilotSurvivesBossOpening() {
        for kind in BossKind.allCases {
            var sim = TowerSimulation(seed: 2026, startFloor: (kind.rawValue + 1) * 1000)
            XCTAssertNotNil(sim.boss)
            var time = 0.0
            while time < 8 {
                _ = sim.step(dt: dt, input: DemoPilot.input(for: &sim))
                time += dt
            }
            XCTAssertGreaterThan(sim.playerHP, 0, "\(kind)")
        }
    }
}
