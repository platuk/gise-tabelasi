import SwiftUI

/// CupTower logosu: 1930'lar film afişi harfleri (sarı dolgu, kalın mürekkep kontur, kırmızı gölge),
/// iki kelimenin arasında altın kupa. Ad her dilde aynıdır (marka); erişilebilirlik etiketi `app.title`.
struct CupTowerLogo: View {
    var scale: CGFloat = 1

    var body: some View {
        HStack(alignment: .center, spacing: 2 * scale) {
            word("CUP")
            TrophyIcon(tier: .gold)
                .frame(width: 46 * scale, height: 50 * scale)
                .rotationEffect(.degrees(-6))
                .offset(y: -4 * scale)
            word("TOWER")
        }
        // Marka adı her dilde soldan sağa okunur (Arapça gibi sağdan sola dillerde de).
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("app.title"))
    }

    /// Harf: kırmızı gölge, mürekkep kontur (8 yönde kaydırılmış kopya), sarı dolgu, üstte ince parlaklık.
    private func word(_ text: String) -> some View {
        let size = 40 * scale
        let outline = 2.2 * scale
        let base = Text(verbatim: text).font(Theme.title(size)).kerning(1)
        return ZStack {
            base.foregroundStyle(Theme.marquee).offset(x: 3.5 * scale, y: 4 * scale)
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) * .pi / 4
                base.foregroundStyle(Theme.ink)
                    .offset(x: cos(angle) * outline, y: sin(angle) * outline)
            }
            base.foregroundStyle(Theme.bulb)
            base.foregroundStyle(Color.white.opacity(0.55))
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
        }
        .fixedSize()
    }
}
