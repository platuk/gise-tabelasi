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
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onCharacters: () -> Void
    let onGallery: () -> Void
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

            VStack(spacing: 14) {
                Spacer().frame(height: 46)
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 12)
                    titleCard
                        .rotationEffect(.degrees(tick % 4 < 2 ? -1.2 : 1.2))
                        .offset(y: tick % 4 < 2 ? 0 : -2)
                }
                Text("title.subtitle")
                    .font(Theme.title(15))
                    .foregroundStyle(Theme.ink.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)

                stage

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
                if bestScore > 0 {
                    Text("title.best \(bestScore) \(bestFloor)")
                        .font(Theme.title(14))
                        .foregroundStyle(Theme.ink)
                }
                HStack(spacing: 8) {
                    PlaqueButton(title: Text("title.characters \(wallet)"), systemImage: "person.crop.circle", action: onCharacters)
                    PlaqueButton(title: Text("title.gallery"), systemImage: "star.circle", action: onGallery)
                    PlaqueButton(title: Text("title.settings"), systemImage: "gearshape", action: onSettings)
                    PlaqueButton(title: Text("title.help"), systemImage: "questionmark.circle", action: onHelp)
                }
                .padding(.horizontal, 54)
                Spacer().frame(height: 14)
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
    private var stage: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Theme.bulb.opacity(0.45))
                .frame(width: 150, height: 26)
                .offset(y: -4)
            SpriteView(scene: CharacterPreviewScene(character: character, dances: true), options: [.allowsTransparency])
                .frame(width: 110, height: 122)
        }
        .frame(height: 126)
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
