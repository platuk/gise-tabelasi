import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let seed: UInt64
    let startFloor: Int
}

struct GameResult: Equatable {
    let score: Int
    let floor: Int
    let isNewBest: Bool
    let checkpointFloor: Int
}

struct RootView: View {
    @AppStorage("bestScore") private var bestScore = 0
    @AppStorage("bestFloor") private var bestFloor = 0
    /// En yüksek kupanın katı (100, 200, ...): kayıt noktası. Kupa kazanıldığı an kaydedilir.
    @AppStorage("checkpointFloor") private var checkpointFloor = 0
    @AppStorage("autoJump") private var autoJump = false
    @State private var session: GameSession?
    @State private var result: GameResult?
    @State private var showingHelp = false

    var body: some View {
        ZStack {
            if let session {
                GameView(
                    session: session,
                    autoJump: autoJump,
                    onGameOver: { score, floor in finish(score: score, floor: floor) },
                    onCheckpoint: { floor in checkpointFloor = max(checkpointFloor, floor) },
                    onAutoJumpChanged: { autoJump = $0 }
                )
                .id(session.id)
                .ignoresSafeArea()

                if let result {
                    GameOverView(
                        result: result,
                        onRetry: { start(from: result.checkpointFloor) },
                        onMenu: backToMenu
                    )
                    .transition(.opacity)
                }
            } else {
                TitleView(
                    bestScore: bestScore,
                    bestFloor: bestFloor,
                    checkpointFloor: checkpointFloor,
                    onPlay: { start(from: 0) },
                    onContinue: { start(from: checkpointFloor) },
                    onHelp: { showingHelp = true }
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: result)
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
    }

    private func start(from floor: Int) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: max(0, floor))
    }

    private func backToMenu() {
        result = nil
        session = nil
    }

    private func finish(score: Int, floor: Int) {
        let isNewBest = score > bestScore
        if isNewBest { bestScore = score }
        bestFloor = max(bestFloor, floor)
        result = GameResult(score: score, floor: floor, isNewBest: isNewBest, checkpointFloor: checkpointFloor)
    }
}
