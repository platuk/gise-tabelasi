import GameCore
import SwiftUI

struct GameSession: Identifiable {
    let id = UUID()
    let seed: UInt64
    let startFloor: Int
    /// Boss katından başlanıyorsa ve o boss daha önce yenildiyse dövüş atlanır.
    let bossAlreadyDefeated: Bool
    let character: GameCharacter
    /// Tırmanış, tek boss ya da bütün boss'lar sırayla (boss modlarında ödül ve tırmanış rekoru yok).
    var mode: PlayMode = .climb
    var speed: GameSpeed = .normal
}

struct GameResult: Equatable {
    let score: Int
    let floor: Int
    let isNewBest: Bool
    let checkpointFloor: Int
    /// Sıralı boss modu: yenilen boss sayısı ve rekor.
    var bossRush: Bool = false
    var bossesBeaten: Int = 0
    var bestBossRush: Int = 0
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
    /// Oyun hızı: 0 normal, 1 orta, 2 hızlı.
    @AppStorage("gameSpeed") private var gameSpeed = 0
    /// Sıralı boss modunda en çok yenilen boss sayısı.
    @AppStorage("bestBossRush") private var bestBossRush = 0
    @State private var session: GameSession?
    @State private var result: GameResult?
    @State private var showingHelp = false
    @State private var showingCharacters = false
    @State private var showingBosses = false
    @State private var showingSettings = false

    private var character: GameCharacter {
        let chosen = GameCharacter(rawValue: selectedCharacter) ?? .tipi
        return GameCharacter.unlocked(from: unlockedCharacters).contains(chosen) ? chosen : .tipi
    }

    private var speed: GameSpeed { GameSpeed(rawValue: gameSpeed) ?? .normal }

    var body: some View {
        ZStack {
            if let session {
                GameView(
                    session: session,
                    onGameOver: { summary in finish(summary) },
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
                        onRetry: {
                            if result.bossRush {
                                startBossRush()
                            } else {
                                start(from: result.checkpointFloor)
                            }
                        },
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
                    gameSpeed: $gameSpeed,
                    onPlay: { start(from: 0) },
                    onContinue: { start(from: checkpointFloor) },
                    onBosses: { showingBosses = true },
                    onCharacters: { showingCharacters = true },
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
        .sheet(isPresented: $showingBosses) {
            BossGalleryView(defeatedBossFloor: defeatedBossFloor, bestBossRush: bestBossRush,
                            onFight: { kind in
                                showingBosses = false
                                fightBoss(kind)
                            },
                            onRush: {
                                showingBosses = false
                                startBossRush()
                            })
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
                              bossAlreadyDefeated: start > 0 && defeatedBossFloor >= start, character: character, speed: speed)
    }

    /// Tek boss: boss katından başlanır, dövüş hemen başlar.
    private func fightBoss(_ kind: BossKind) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: (kind.rawValue + 1) * 1000,
                              bossAlreadyDefeated: false, character: character, mode: .singleBoss, speed: speed)
    }

    /// Bütün boss'lar sırayla: ahtapottan bulldoga.
    private func startBossRush() {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: 1000,
                              bossAlreadyDefeated: false, character: character, mode: .bossRush, speed: speed)
    }

    private func restart(_ current: GameSession) {
        result = nil
        session = GameSession(seed: UInt64.random(in: 1...UInt64.max), startFloor: current.startFloor,
                              bossAlreadyDefeated: current.bossAlreadyDefeated, character: character,
                              mode: current.mode, speed: current.speed)
    }

    private func backToMenu() {
        result = nil
        session = nil
    }

    private func finish(_ summary: GameSummary) {
        switch session?.mode ?? .climb {
        case .singleBoss:
            // Tek dövüş bitti: boss ekranına dönülür.
            backToMenu()
            showingBosses = true
        case .bossRush:
            bestBossRush = max(bestBossRush, summary.bossesBeaten)
            result = GameResult(score: summary.score, floor: summary.floor, isNewBest: false, checkpointFloor: 0,
                                bossRush: true, bossesBeaten: summary.bossesBeaten, bestBossRush: bestBossRush)
        case .climb:
            let isNewBest = summary.score > bestScore
            if isNewBest { bestScore = summary.score }
            bestFloor = max(bestFloor, summary.floor)
            result = GameResult(score: summary.score, floor: summary.floor, isNewBest: isNewBest, checkpointFloor: checkpointFloor)
        }
    }

    private func resetProgress() {
        bestScore = 0
        bestFloor = 0
        checkpointFloor = 0
        trophyWallet = 0
        unlockedCharacters = "0"
        selectedCharacter = 0
        defeatedBossFloor = 0
        bestBossRush = 0
    }
}
