import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene: TowerScene
    private let onGameOver: (Int, Int) -> Void
    private let onCheckpoint: (Int) -> Void
    private let onBossDefeated: (Int) -> Void

    init(
        session: GameSession,
        onGameOver: @escaping (Int, Int) -> Void,
        onCheckpoint: @escaping (Int) -> Void,
        onBossDefeated: @escaping (Int) -> Void
    ) {
        self.onGameOver = onGameOver
        self.onCheckpoint = onCheckpoint
        self.onBossDefeated = onBossDefeated
        _scene = State(initialValue: TowerScene(
            seed: session.seed, startFloor: session.startFloor, bossAlreadyDefeated: session.bossAlreadyDefeated,
            character: session.character
        ))
    }

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .onAppear {
                scene.onGameOver = { score, floor in onGameOver(score, floor) }
                scene.onCheckpoint = { floor in onCheckpoint(floor) }
                scene.onBossDefeated = { floor in onBossDefeated(floor) }
            }
    }
}
