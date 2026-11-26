import SpriteKit
import SwiftUI
import UIKit

struct GameView: View {
    @State private var scene: TowerScene
    @State private var paused = false
    @State private var countdown: Int?
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    private let onGameOver: (GameSummary) -> Void
    private let onCheckpoint: (Int) -> Void
    private let onBossDefeated: (Int) -> Void
    private let onRestart: () -> Void
    private let onMenu: () -> Void

    init(
        session: GameSession,
        onGameOver: @escaping (GameSummary) -> Void,
        onCheckpoint: @escaping (Int) -> Void,
        onBossDefeated: @escaping (Int) -> Void,
        onRestart: @escaping () -> Void,
        onMenu: @escaping () -> Void
    ) {
        self.onGameOver = onGameOver
        self.onCheckpoint = onCheckpoint
        self.onBossDefeated = onBossDefeated
        self.onRestart = onRestart
        self.onMenu = onMenu
        let scene = TowerScene(
            seed: session.seed, startFloor: session.startFloor, bossAlreadyDefeated: session.bossAlreadyDefeated,
            character: session.character, mode: session.mode, speed: session.speed
        )
        scene.demoPilot = session.demo
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                .onAppear {
                    scene.onGameOver = { summary in onGameOver(summary) }
                    scene.onCheckpoint = { floor in onCheckpoint(floor) }
                    scene.onBossDefeated = { floor in onBossDefeated(floor) }
                }
                .ignoresSafeArea()

            if !paused && countdown == nil {
                VStack {
                    Button {
                        MenuFeedback.tap()
                        pause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Theme.cream))
                            .overlay(Circle().stroke(Theme.ink, lineWidth: 2.5))
                            .contentShape(Circle().inset(by: -6))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel(Text("pause.title"))
                    // Oyun ekranı güvenli alanı yok sayar; düğme Dynamic Island / çentiğin altına, HUD'un
                    // kat ve puan satırıyla aynı hizaya konur (bkz. HUD.layout: üst boşluk + 24).
                    .padding(.top, Self.deviceTopInset + 5)
                    Spacer()
                }
            }

            if paused {
                Theme.ink.opacity(0.45).ignoresSafeArea()
                PaperCard {
                    VStack(spacing: 14) {
                        Text("pause.title").font(Theme.title(40))
                        Text("pause.subtitle").font(Theme.title(14)).opacity(0.75)
                        TicketButton(title: "pause.resume", size: 22) { resume() }
                        TicketButton(title: "pause.restart", size: 17, filled: false) { onRestart() }
                        TicketButton(title: "pause.settings", size: 17, filled: false) { showingSettings = true }
                        TicketButton(title: "pause.menu", size: 17, filled: false) { onMenu() }
                        Text("pause.note").font(Theme.title(12)).opacity(0.7).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.ink)
                }
                .padding(30)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            if let countdown {
                Theme.ink.opacity(0.25).ignoresSafeArea()
                FilmLeader(number: countdown)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: paused)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Uygulama arka plana geçerse (arama, bildirim) oyun kendiliğinden duraklar.
            if phase != .active { pause() }
        }
    }

    /// Cihazın gerçek üst güvenli alanı (Dynamic Island ya da çentik dahil).
    private static var deviceTopInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 0
    }

    private func pause() {
        guard !paused, !scene.isOver else { return }
        countdown = nil
        paused = true
        scene.setPaused(true)
    }

    /// Eski film geri sayımı (3-2-1) ile devam: oyuncu parmağını yerleştirecek zaman bulur.
    private func resume() {
        paused = false
        Task { @MainActor in
            for number in [3, 2, 1] {
                countdown = number
                SoundEngine.shared.play(.countdown)
                try? await Task.sleep(nanoseconds: 450_000_000)
                if paused { return }
            }
            countdown = nil
            SoundEngine.shared.play(.go)
            scene.setPaused(false)
        }
    }
}
