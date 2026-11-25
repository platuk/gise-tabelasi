import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene: TowerScene
    private let onGameOver: (Int, Int) -> Void

    init(session: GameSession, onGameOver: @escaping (Int, Int) -> Void) {
        self.onGameOver = onGameOver
        _scene = State(initialValue: TowerScene(seed: session.seed))
    }

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .onAppear {
                scene.onGameOver = { score, floor in
                    onGameOver(score, floor)
                }
            }
    }
}
