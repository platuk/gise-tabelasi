import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene: TowerScene
    private let onGameOver: (Int, Int) -> Void
    private let onCheckpoint: (Int) -> Void
    private let onAutoJumpChanged: (Bool) -> Void

    init(
        session: GameSession,
        autoJump: Bool,
        onGameOver: @escaping (Int, Int) -> Void,
        onCheckpoint: @escaping (Int) -> Void,
        onAutoJumpChanged: @escaping (Bool) -> Void
    ) {
        self.onGameOver = onGameOver
        self.onCheckpoint = onCheckpoint
        self.onAutoJumpChanged = onAutoJumpChanged
        _scene = State(initialValue: TowerScene(seed: session.seed, startFloor: session.startFloor, autoJump: autoJump))
    }

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .onAppear {
                scene.onGameOver = { score, floor in onGameOver(score, floor) }
                scene.onCheckpoint = { floor in onCheckpoint(floor) }
                scene.onAutoJumpChanged = { on in onAutoJumpChanged(on) }
            }
    }
}
