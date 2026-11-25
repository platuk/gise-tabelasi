import SwiftUI

/// Açılış: 1930'lar film başlık kartı. Kart, saniyede 12 kez hafifçe sallanır (kesik, elle çizilmiş ritim).
struct TitleView: View {
    let bestScore: Int
    let bestFloor: Int
    let onPlay: () -> Void
    let onHelp: () -> Void

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            RadialGradient(colors: [.clear, Theme.ink.opacity(0.5)], center: .center, startRadius: 140, endRadius: 560)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 26) {
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
                Spacer()
                Button(action: onPlay) {
                    Text("title.play")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.cream)
                        .padding(.horizontal, 52)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.ink))
                        .overlay(Capsule().stroke(Theme.bulb, lineWidth: 3).padding(5))
                }
                if bestScore > 0 {
                    Text("title.best \(bestScore) \(bestFloor)")
                        .font(Theme.title(16))
                        .foregroundStyle(Theme.ink)
                }
                Button(action: onHelp) {
                    Label("title.help", systemImage: "questionmark.circle")
                        .font(Theme.title(16))
                }
                .tint(Theme.ink)
                Spacer().frame(height: 24)
            }
            .padding()
        }
    }

    private var titleCard: some View {
        Text("app.title")
            .font(Theme.title(46))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink, lineWidth: 5))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 1.5).padding(9))
    }
}
