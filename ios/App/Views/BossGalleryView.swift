import GameCore
import SpriteKit
import SwiftUI

/// Boss savaşı ekranı: yalnızca boss'larla dövüş.
/// "Hepsi sırayla": altı boss arka arkaya (rekor tutulur). Ya da istenen tek boss seçilip dövüşülür.
/// Bu modlarda kupa, kayıt noktası ya da tırmanış rekoru değişmez.
struct BossGalleryView: View {
    let defeatedBossFloor: Int
    let bestBossRush: Int
    let onFight: (BossKind) -> Void
    let onRush: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("bosses.title").font(Theme.title(30))
                        Spacer()
                        Button {
                            MenuFeedback.tap()
                            dismiss()
                        } label: {
                            Text("help.done").font(Theme.title(18))
                        }
                    }
                    Text("bosses.hint")
                        .font(Theme.title(14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.8)
                    VStack(spacing: 8) {
                        TicketButton(title: "bosses.rush", size: 22, action: onRush)
                        if bestBossRush > 0 {
                            Text("bosses.rushBest \(bestBossRush)").font(Theme.title(14))
                        }
                    }
                    .padding(.vertical, 6)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BossKind.allCases, id: \.rawValue) { kind in
                            card(kind)
                        }
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(20)
            }
        }
    }

    private func card(_ kind: BossKind) -> some View {
        let number = kind.rawValue + 1
        let floor = number * 1000
        let defeated = defeatedBossFloor >= floor
        return VStack(spacing: 6) {
            SpriteView(scene: BossPreviewScene(kind: kind, locked: false), options: [.allowsTransparency])
                .frame(height: 120)
                .overlay(alignment: .topTrailing) {
                    if defeated {
                        Text("gallery.defeated")
                            .font(Theme.title(12))
                            .foregroundStyle(Theme.marquee)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.marquee, lineWidth: 2.5))
                            .rotationEffect(.degrees(-12))
                    }
                }
            Text(BossNode.displayName(kind))
                .font(Theme.title(14))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(height: 36)
            Text("gallery.floor \(floor)").font(Theme.title(12)).opacity(0.75)
            TicketButton(title: "bosses.fight", size: 15) {
                onFight(kind)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 3))
    }
}
