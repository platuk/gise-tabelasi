import GameCore
import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let seed: UInt64
    let startFloor: Int
    /// Boss katından başlanıyorsa ve o boss daha önce yenildiyse dövüş atlanır.
    let bossAlreadyDefeated: Bool
    let character: GameCharacter
    /// Boss provası: ödül, kupa ve rekor kaydı yok.
    var practice = false
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
    /// En son yenilen boss'un arena katı (1000, 2000, ...).
    @AppStorage("defeatedBossFloor") private var defeatedBossFloor = 0
    @State private var session: GameSession?
    @State private var result: GameResult?
    @State private var showingHelp = false
    @State private var showingCharacters = false
    @State private var showingGallery = false
    @State private var showingSettings = false

    private var character: GameCharacter {
        let chosen = GameCharacter(rawValue: selectedCharacter) ?? .tipi
        return GameCharacter.unlocked(from: unlockedCharacters).contains(chosen) ? chosen : .tipi
    }

    var body: some View {
        ZStack {
            if let session {
                GameView(
                    session: session,
                    onGameOver: { score, floor in finish(score: score, floor: floor) },
                    onCheckpoint: { floor in
                        checkpointFloor = max(checkpointFloor, floor)
                        trophyWallet += 1
                    },
                    onBossDefeated: { floor in
                        defeatedBossFloor = max(defeatedBossFloor, floor)
                        trophyWallet += TowerScene.bossRewardCups
                    },
                    onRestart: { restart(session) },
                    onMenu: backToMenu
                )
                .id(session.id)
                .ignoresSafeArea()

                if let result {
                    GameOverView(
                        result: result,
                        onRetry: { start(from: result.checkpointFloor) },
                        onMenu: backToMenu
                    )
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
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
                    onGallery: { showingGallery = true },
                    onSettings: { showingSettings = true },
                    onHelp: { showingHelp = true }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: result)
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingCharacters) {
            CharacterShopView(wallet: $trophyWallet, unlockedStorage: $unlockedCharacters, selected: $selectedCharacter)
        }
        .sheet(isPresented: $showingGallery) {
            BossGalleryView(defeatedBossFloor: defeatedBossFloor) { kind in
                showingGallery = false
                practice(kind)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(onReset: resetProgress)
        }
        .preferredColorScheme(.light)
        .statusBarHidden(true)
        .onAppear {
            GameSettings.register()
            SoundEngine.shared.start()
        }
    }

    private func start(from floor: Int) {
        result = nil
        let start = max(0, floor)
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: start,
                              bossAlreadyDefeated: start > 0 && defeatedBossFloor >= start, character: character)
    }

    /// Provada boss katından başlanır; dövüş hemen başlar.
    private func practice(_ kind: BossKind) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: (kind.rawValue + 1) * 1000,
                              bossAlreadyDefeated: false, character: character, practice: true)
    }

    private func restart(_ current: GameSession) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: current.startFloor,
                              bossAlreadyDefeated: current.bossAlreadyDefeated, character: character, practice: current.practice)
    }

    private func backToMenu() {
        result = nil
        session = nil
    }

    private func finish(score: Int, floor: Int) {
        if session?.practice == true {
            // Prova sonu: rekor yok, galeriye dönülür.
            backToMenu()
            showingGallery = true
            return
        }
        let isNewBest = score > bestScore
        if isNewBest { bestScore = score }
        bestFloor = max(bestFloor, floor)
        result = GameResult(score: score, floor: floor, isNewBest: isNewBest, checkpointFloor: checkpointFloor)
    }

    private func resetProgress() {
        bestScore = 0
        bestFloor = 0
        checkpointFloor = 0
        trophyWallet = 0
        unlockedCharacters = "0"
        selectedCharacter = 0
        defeatedBossFloor = 0
    }
}
