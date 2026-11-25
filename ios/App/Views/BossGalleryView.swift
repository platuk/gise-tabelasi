import GameCore
import SpriteKit
import SwiftUI

/// Boss galerisi: altı boss, hangi bölüm sonunda beklediği, yenilip yenilmediği ve prova düğmesi.
/// Provada ödül ya da kayıt yoktur; oyuncu istediği boss'a çalışabilir.
struct BossGalleryView: View {
    let defeatedBossFloor: Int
    let onPractice: (BossKind) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("gallery.title").font(Theme.title(30))
                        Spacer()
                        Button {
                            MenuFeedback.tap()
                            dismiss()
                        } label: {
                            Text("help.done").font(Theme.title(18))
                        }
                    }
                    Text("gallery.hint")
                        .font(Theme.title(14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(0.8)
                    ForEach(BossKind.allCases, id: \.rawValue) { kind in
                        card(kind)
                    }
                }
                .foregroundStyle(Theme.ink)
                .padding(24)
            }
        }
    }

    private func card(_ kind: BossKind) -> some View {
        let number = kind.rawValue + 1
        let floor = number * 1000
        let defeated = defeatedBossFloor >= floor
        return VStack(spacing: 8) {
            SpriteView(scene: BossPreviewScene(kind: kind, locked: false), options: [.allowsTransparency])
                .frame(height: 170)
                .overlay(alignment: .topTrailing) {
                    if defeated {
                        Text("gallery.defeated")
                            .font(Theme.title(15))
                            .foregroundStyle(Theme.marquee)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.marquee, lineWidth: 3))
                            .rotationEffect(.degrees(-12))
                            .padding(8)
                    }
                }
            Text(BossNode.displayName(kind)).font(Theme.title(20))
            Text("gallery.floor \(floor)").font(Theme.title(14)).opacity(0.8)
            TicketButton(title: "gallery.practice", size: 18) {
                onPractice(kind)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink, lineWidth: 3))
    }
}
