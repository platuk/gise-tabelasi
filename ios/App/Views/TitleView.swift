import SpriteKit
import SwiftUI

/// Açılış: 1930'lar film başlık kartı, kupa rafı, baştan ya da kayıt noktasından başlama.
/// Başlık kartı saniyede 12 kez hafifçe sallanır (kesik, elle çizilmiş ritim).
struct TitleView: View {
    let bestScore: Int
    let bestFloor: Int
    let checkpointFloor: Int
    let wallet: Int
    let character: GameCharacter
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onCharacters: () -> Void
    let onHelp: () -> Void

    private var earnedTrophies: Int { checkpointFloor / TrophyTier.floorsPerTrophy }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            RadialGradient(colors: [.clear, Theme.ink.opacity(0.5)], center: .center, startRadius: 140, endRadius: 560)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 22) {
                Spacer()
                TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 12)
                    titleCard
                        .rotationEffect(.degrees(tick % 4 < 2 ? -1.2 : 1.2))
                        .offset(y: tick % 4 < 2 ? 0 : -2)
                }
                Text("title.subtitle")
                    .font(Theme.title(17))
                    .foregroundStyle(Theme.ink.opacity(0.8))
                    .multilineTextAlignment(.center)

                trophyShelf

                Spacer()

                if checkpointFloor > 0 {
                    Button(action: onContinue) {
                        Text("title.continue \(checkpointFloor)")
                            .font(Theme.title(26))
                            .foregroundStyle(Theme.cream)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Theme.ink))
                            .overlay(Capsule().stroke(Theme.bulb, lineWidth: 3).padding(5))
                    }
                    Button(action: onPlay) {
                        Text("title.restart")
                            .font(Theme.title(18))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 10)
                            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
                    }
                } else {
                    Button(action: onPlay) {
                        Text("title.play")
                            .font(Theme.title(30))
                            .foregroundStyle(Theme.cream)
                            .padding(.horizontal, 52)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Theme.ink))
                            .overlay(Capsule().stroke(Theme.bulb, lineWidth: 3).padding(5))
                    }
                }
                if bestScore > 0 {
                    Text("title.best \(bestScore) \(bestFloor)")
                        .font(Theme.title(16))
                        .foregroundStyle(Theme.ink)
                }
                HStack(spacing: 18) {
                    Button(action: onCharacters) {
                        HStack(spacing: 6) {
                            SpriteView(scene: CharacterPreviewScene(character: character), options: [.allowsTransparency])
                                .frame(width: 30, height: 34)
                            Text("title.characters \(wallet)")
                                .font(Theme.title(16))
                        }
                    }
                    Button(action: onHelp) {
                        Label("title.help", systemImage: "questionmark.circle")
                            .font(Theme.title(16))
                    }
                }
                .tint(Theme.ink)
                Spacer().frame(height: 20)
            }
            .padding()
        }
    }

    private var titleCard: some View {
        Text("app.title")
            .font(Theme.title(54))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 34)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: 5))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 1.5).padding(9))
    }

    /// Kazanılan kupalar renkli, sıradakiler soluk. Efsane kupadan sonrası sayıyla gösterilir.
    private var trophyShelf: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                ForEach(TrophyTier.allCases, id: \.self) { tier in
                    TrophyIcon(tier: tier, earned: earnedTrophies >= tier.rawValue)
                        .frame(width: 40, height: 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 2))
            Text("title.trophies \(earnedTrophies)")
                .font(Theme.title(14))
                .foregroundStyle(Theme.ink.opacity(0.8))
        }
    }
}
