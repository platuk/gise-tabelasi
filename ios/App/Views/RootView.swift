import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let seed: UInt64
}

struct GameResult: Equatable {
    let score: Int
    let floor: Int
    let isNewBest: Bool
}

struct RootView: View {
    @AppStorage("bestScore") private var bestScore = 0
    @AppStorage("bestFloor") private var bestFloor = 0
    @State private var session: GameSession?
    @State private var result: GameResult?
    @State private var showingHelp = false

    var body: some View {
        ZStack {
            if let session {
                GameView(session: session) { score, floor in
                    finish(score: score, floor: floor)
                }
                .id(session.id)
                .ignoresSafeArea()

                if let result {
                    GameOverView(result: result, onRetry: start, onMenu: backToMenu)
                        .transition(.opacity)
                }
            } else {
                TitleView(bestScore: bestScore, bestFloor: bestFloor, onPlay: start, onHelp: { showingHelp = true })
            }
        }
        .animation(.easeOut(duration: 0.2), value: result)
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
    }

    private func start() {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max))
    }

    private func backToMenu() {
        result = nil
        session = nil
    }

    private func finish(score: Int, floor: Int) {
        let isNewBest = score > bestScore
        if isNewBest { bestScore = score }
        bestFloor = max(bestFloor, floor)
        result = GameResult(score: score, floor: floor, isNewBest: isNewBest)
    }
}
