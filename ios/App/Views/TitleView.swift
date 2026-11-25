import SpriteKit
import SwiftUI

/// Ana ekran: 1930'lar sinema salonu. Perde açılır, tabela ampulleri sırayla yanar,
/// seçili karakter spot ışığı altında müzikle dans eder.
///
/// İçerik (oyun menüsü araştırmasına göre): Oyna / Devam, Baştan başla, Karakterler, Boss galerisi,
/// Ayarlar, Nasıl oynanır, kupa rafı ve en iyi skor.
struct TitleView: View {
    let bestScore: Int
    let bestFloor: Int
    let checkpointFloor: Int
    let wallet: Int
    let character: GameCharacter
    @Binding var gameSpeed: Int
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onBosses: () -> Void
    let onCharacters: () -> Void
    let onSettings: () -> Void
    let onHelp: () -> Void

    @State private var curtainOpen: CGFloat = 0
    @State private var showContent = false

    private var earnedTrophies: Int { checkpointFloor / TrophyTier.floorsPerTrophy }

    var body: some View {
        ZStack {
            // Sahne: kâğıt perde, ortada spot ışığı.
            Theme.paper.ignoresSafeArea()
            RadialGradient(colors: [Theme.bulb.opacity(0.35), .clear], center: .init(x: 0.5, y: 0.42), startRadius: 10, endRadius: 260)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            RadialGradient(colors: [.clear, Theme.ink.opacity(0.55)], center: .center, startRadius: 160, endRadius: 600)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { geo in
            // Küçük ekranlarda (iPhone SE) alt yazı gizlenir, sahne küçülür.
            let compact = geo.size.height < 760
            VStack(spacing: compact ? 9 : 14) {
                Spacer().frame(height: compact ? 40 : 46)
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 12)
                    titleCard
                        .scaleEffect(compact ? 0.8 : 1)
                        .rotationEffect(.degrees(tick % 4 < 2 ? -1.2 : 1.2))
                        .offset(y: tick % 4 < 2 ? 0 : -2)
                }
                .frame(height: compact ? 96 : 120)
                if !compact {
                    Text("title.subtitle")
                        .font(Theme.title(15))
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                }

                stage(height: compact ? 80 : 122)

                trophyShelf

                Spacer(minLength: 4)

                if checkpointFloor > 0 {
                    TicketButton(title: "title.continue \(checkpointFloor)", size: 24, action: onContinue)
                    Button {
                        MenuFeedback.tap()
                        onPlay()
                    } label: {
                        Text("title.restart")
                            .font(Theme.title(16))
                            .foregroundStyle(Theme.ink)
                            .underline()
                    }
                    .buttonStyle(PressStyle())
                } else {
                    TicketButton(title: "title.play", size: 30, action: onPlay)
                }
                TicketButton(title: "title.bossFight", size: 17, filled: false, action: onBosses)
                speedPicker
                if bestScore > 0 {
                    Text("title.best \(bestScore) \(bestFloor)")
                        .font(Theme.title(14))
                        .foregroundStyle(Theme.ink)
                }
                HStack(spacing: 8) {
                    PlaqueButton(title: Text("title.characters \(wallet)"), systemImage: "person.crop.circle", action: onCharacters)
                    PlaqueButton(title: Text("title.settings"), systemImage: "gearshape", action: onSettings)
                    PlaqueButton(title: Text("title.help"), systemImage: "questionmark.circle", action: onHelp)
                }
                .padding(.horizontal, 54)
                Spacer().frame(height: compact ? 8 : 14)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            }
            .opacity(showContent ? 1 : 0)

            TheaterCurtain(open: curtainOpen)
                .ignoresSafeArea()
        }
        .onAppear {
            SoundEngine.shared.start()
            SoundEngine.shared.setPaused(false)
            SoundEngine.shared.setMood(.menu)
            curtainOpen = 0
            withAnimation(.easeOut(duration: 0.25)) { showContent = true }
            withAnimation(.easeInOut(duration: 0.9).delay(0.15)) { curtainOpen = 1 }
        }
    }

    /// Oyun hızı: normal, orta, hızlı. Seçim saklanır; tırmanış da boss dövüşleri de bu hızda oynanır.
    private var speedPicker: some View {
        HStack(spacing: 6) {
            Text("speed.title").font(Theme.title(13))
            ForEach(GameSpeed.allCases, id: \.rawValue) { speed in
                speedButton(speed)
            }
        }
    }

    private func speedButton(_ speed: GameSpeed) -> some View {
        let selected = gameSpeed == speed.rawValue
        return Button {
            MenuFeedback.tap()
            gameSpeed = speed.rawValue
        } label: {
            Text(speedName(speed))
                .font(Theme.title(13))
                .foregroundStyle(selected ? Theme.cream : Theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(selected ? Theme.ink : Theme.cream))
                .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
        }
        .buttonStyle(PressStyle())
    }

    private func speedName(_ speed: GameSpeed) -> LocalizedStringKey {
        switch speed {
        case .normal: return "speed.normal"
        case .medium: return "speed.medium"
        case .fast: return "speed.fast"
        }
    }

    private var titleCard: some View {
        Text("app.title")
            .font(Theme.title(52))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 40)
            .padding(.vertical, 26)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cream))
            .overlay(MarqueeBulbs())
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: 5))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 1.5).padding(20))
    }

    /// Spot ışığında dans eden karakter: tahta sahne kenarı ve ışık halkası.
    private func stage(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Theme.bulb.opacity(0.45))
                .frame(width: height * 1.2, height: 26)
                .offset(y: -4)
            SpriteView(scene: CharacterPreviewScene(character: character, dances: true), options: [.allowsTransparency])
                .frame(width: height * 0.9, height: height)
        }
        .frame(height: height + 4)
    }

    /// Kazanılan kupalar renkli, sıradakiler soluk.
    private var trophyShelf: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                ForEach(TrophyTier.allCases, id: \.self) { tier in
                    TrophyIcon(tier: tier, earned: earnedTrophies >= tier.rawValue)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 2))
            Text("title.trophies \(earnedTrophies)")
                .font(Theme.title(12))
                .foregroundStyle(Theme.ink.opacity(0.8))
        }
    }
}
