/// Kendi kendine oynayan basit pilot: tanıtım ve App Store ekran görüntüleri için.
/// Tırmanışta bir sonraki kirişe yönelir; boss dövüşünde boss'un altında kalır, dalgaların üstünden zıplar,
/// işaretlenen ışın ve fışkırma yerinden kaçar.
public enum DemoPilot {
    public static func input(for sim: inout TowerSimulation) -> TowerInput {
        if let fight = sim.boss { return bossInput(sim: sim, fight: fight) }
        let config = sim.config
        let target = sim.bounds(floor: sim.currentFloor + 1)
        let center = (target.minX + target.maxX) / 2
        let halfWidth = (target.maxX - target.minX) / 2
        if sim.isGrounded {
            let dx = center - sim.x
            let lead = dx - sim.vx * 0.25
            let direction = abs(lead) < 4 ? 0 : (lead > 0 ? 1 : -1)
            let current = sim.bounds(floor: sim.currentFloor)
            let nextX = sim.x + sim.vx * 0.06
            let atEdge = (dx > 0 && nextX > current.maxX) || (dx < 0 && nextX < current.minX)
            let jump = (abs(dx) < halfWidth * 0.7 && abs(sim.vx) < 200) || atEdge
            return TowerInput(direction: direction, jump: jump)
        }
        let targetY = Double(sim.currentFloor + 1) * config.floorSpacing
        let discriminant = sim.vy * sim.vy - 2 * config.gravity * (targetY - sim.y)
        let timeToLand = discriminant > 0 ? (sim.vy + discriminant.squareRoot()) / config.gravity : 0.2
        let error = center - (sim.x + sim.vx * timeToLand)
        return TowerInput(direction: abs(error) < 3 ? 0 : (error > 0 ? 1 : -1), jump: false)
    }

    private static func bossInput(sim: TowerSimulation, fight: BossFight) -> TowerInput {
        var goal = fight.x
        if let attack = fight.telegraph, attack == .laser || attack == .geyser, abs(goal - fight.targetX) < 90 {
            goal = fight.targetX + (fight.targetX < sim.config.worldWidth / 2 ? 140 : -140)
        }
        let dx = goal - sim.x
        let direction = abs(dx) < 10 ? 0 : (dx > 0 ? 1 : -1)
        let waveClose = sim.enemyShots.contains { shot in
            shot.kind == .wave && abs(shot.x - sim.x) < 70 && (shot.vx > 0) == (shot.x < sim.x)
        }
        return TowerInput(direction: direction, jump: sim.isGrounded && waveClose)
    }
}
