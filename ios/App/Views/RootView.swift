import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let seed: UInt64
    let startFloor: Int
    let character: GameCharacter
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
    /// Harcanabilir kupalar: her kazanılan kupa +1. Karakter açmak için kullanılır (gerçek para yok).
    @AppStorage("trophyWallet") private var trophyWallet = 0
    @AppStorage("unlockedCharacters") private var unlockedCharacters = "0"
    @AppStorage("selectedCharacter") private var selectedCharacter = 0
    /// Varsayılan açık: kontroller yalnızca sol/sağ olduğundan zıplama kendiliğinden olur.
    @AppStorage("autoJump") private var autoJump = true
    @State private var session: GameSession?
    @State private var result: GameResult?
    @State private var showingHelp = false
    @State private var showingCharacters = false

    private var character: GameCharacter {
        let chosen = GameCharacter(rawValue: selectedCharacter) ?? .tipi
        return GameCharacter.unlocked(from: unlockedCharacters).contains(chosen) ? chosen : .tipi
    }

    var body: some View {
        ZStack {
            if let session {
                GameView(
                    session: session,
                    autoJump: autoJump,
                    onGameOver: { score, floor in finish(score: score, floor: floor) },
                    onCheckpoint: { floor in
                        checkpointFloor = max(checkpointFloor, floor)
                        trophyWallet += 1
                    },
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
                    wallet: trophyWallet,
                    character: character,
                    onPlay: { start(from: 0) },
                    onContinue: { start(from: checkpointFloor) },
                    onCharacters: { showingCharacters = true },
                    onHelp: { showingHelp = true }
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: result)
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingCharacters) {
            CharacterShopView(wallet: $trophyWallet, unlockedStorage: $unlockedCharacters, selected: $selectedCharacter)
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
    }

    private func start(from floor: Int) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: max(0, floor), character: character)
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
