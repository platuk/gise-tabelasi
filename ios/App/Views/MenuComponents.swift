import SwiftUI

/// Menülerde dokunuş: tahta blok "tok" sesi ve hafif titreşim.
enum MenuFeedback {
    static func tap() {
        SoundEngine.shared.play(.click)
        if GameSettings.haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

/// Basılınca kesik (12 fps hissi) küçülen düğme.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -1.5 : 0))
            .animation(.linear(duration: 0.08), value: configuration.isPressed)
    }
}

/// Sinema bileti biçiminde büyük düğme: yan çentikli, iç çizgili.
struct TicketButton: View {
    let title: LocalizedStringKey
    var size: CGFloat = 28
    var filled = true
    let action: () -> Void

    var body: some View {
        Button {
            MenuFeedback.tap()
            action()
        } label: {
            Text(title)
                .font(Theme.title(size))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(filled ? Theme.cream : Theme.ink)
                .padding(.horizontal, size * 1.4)
                .padding(.vertical, size * 0.45)
                .background(TicketShape().fill(filled ? Theme.marquee : Theme.cream))
                .overlay(TicketShape().stroke(Theme.ink, lineWidth: 3.5))
                .overlay(TicketShape().inset(by: 6).stroke(filled ? Theme.bulb : Theme.ink, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
        }
        .buttonStyle(PressStyle())
    }
}

/// Bilet: köşeleri içe oyuk dikdörtgen.
struct TicketShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let notch: CGFloat = min(12, r.height * 0.22)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + notch, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - notch, y: r.minY))
        path.addArc(center: CGPoint(x: r.maxX, y: r.minY), radius: notch, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - notch))
        path.addArc(center: CGPoint(x: r.maxX, y: r.maxY), radius: notch, startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        path.addLine(to: CGPoint(x: r.minX + notch, y: r.maxY))
        path.addArc(center: CGPoint(x: r.minX, y: r.maxY), radius: notch, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + notch))
        path.addArc(center: CGPoint(x: r.minX, y: r.minY), radius: notch, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> TicketShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

/// Pirinç levha düğme: ikon + yazı (menünün ikinci sıra düğmeleri).
struct PlaqueButton: View {
    let title: Text
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button {
            MenuFeedback.tap()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .bold))
                title
                    .font(Theme.title(13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink, lineWidth: 2.5))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink.opacity(0.5), lineWidth: 1).padding(4))
        }
        .buttonStyle(PressStyle())
    }
}

/// Sinema tabelası ışıkları: çerçeve boyunca sırayla yanan ampuller (12 fps).
struct MarqueeBulbs: View {
    var spacing: CGFloat = 17
    var radius: CGFloat = 4

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 8.0)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate * 8)
            Canvas { ctx, size in
                let points = Self.perimeter(size: size, spacing: spacing)
                for (index, point) in points.enumerated() {
                    let lit = (index + tick) % 3 == 0
                    let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                    if lit {
                        ctx.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(Theme.bulb.opacity(0.35)))
                    }
                    ctx.fill(Path(ellipseIn: rect), with: .color(lit ? Theme.bulb : Theme.bulb.opacity(0.35)))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.ink), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func perimeter(size: CGSize, spacing: CGFloat) -> [CGPoint] {
        let inset: CGFloat = 9
        let w = size.width - inset * 2
        let h = size.height - inset * 2
        guard w > 0, h > 0 else { return [] }
        var points: [CGPoint] = []
        let across = max(1, Int(w / spacing))
        let down = max(1, Int(h / spacing))
        for i in 0..<across { points.append(CGPoint(x: inset + w * CGFloat(i) / CGFloat(across), y: inset)) }
        for i in 0..<down { points.append(CGPoint(x: inset + w, y: inset + h * CGFloat(i) / CGFloat(down))) }
        for i in 0..<across { points.append(CGPoint(x: inset + w - w * CGFloat(i) / CGFloat(across), y: inset + h)) }
        for i in 0..<down { points.append(CGPoint(x: inset, y: inset + h - h * CGFloat(i) / CGFloat(down))) }
        return points
    }
}

/// Tiyatro perdesi: kadife kıvrımlı iki kanat ve saçaklı üst pervaz. `open`: 0 kapalı, 1 açık.
struct TheaterCurtain: View, Animatable {
    var open: CGFloat

    /// Perde açılışı canlandırılabilsin diye.
    var animatableData: CGFloat {
        get { open }
        set { open = newValue }
    }

    private static let velvet = Color(red: 0.62, green: 0.12, blue: 0.11)
    private static let fold = Color(red: 0.42, green: 0.06, blue: 0.07)
    private static let gold = Color(red: 0.86, green: 0.66, blue: 0.24)

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            // Açıkken her kanat ekranın %13'ünü kaplar, kapalıyken yarısını.
            let panel = w * (0.5 - 0.37 * open)
            for side in [0, 1] {
                let x0: CGFloat = side == 0 ? 0 : w - panel
                let rect = CGRect(x: x0, y: 0, width: panel, height: h)
                ctx.fill(Path(rect), with: .color(Self.velvet))
                // Kıvrımlar: koyu dikey şeritler, alta doğru genişleyen.
                let folds = max(2, Int(panel / 22))
                for index in 0..<folds {
                    let fx = x0 + panel * (CGFloat(index) + 0.5) / CGFloat(folds)
                    var path = Path()
                    path.move(to: CGPoint(x: fx - 2, y: 0))
                    path.addLine(to: CGPoint(x: fx + 2, y: 0))
                    path.addLine(to: CGPoint(x: fx + 7, y: h))
                    path.addLine(to: CGPoint(x: fx - 7, y: h))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(Self.fold))
                }
                // Kenar çizgisi ve altın bağ.
                let edgeX = side == 0 ? panel : w - panel
                var edge = Path()
                edge.move(to: CGPoint(x: edgeX, y: 0))
                edge.addLine(to: CGPoint(x: edgeX, y: h))
                ctx.stroke(edge, with: .color(Theme.ink), lineWidth: 3)
                if open > 0.5 {
                    let tie = CGRect(x: edgeX - (side == 0 ? 16 : 0), y: h * 0.62, width: 16, height: 9)
                    ctx.fill(Path(roundedRect: tie, cornerRadius: 3), with: .color(Self.gold))
                    ctx.stroke(Path(roundedRect: tie, cornerRadius: 3), with: .color(Theme.ink), lineWidth: 1.5)
                }
            }
            // Üst pervaz: dalgalı alt kenar, altın saçak.
            let valanceHeight: CGFloat = 46
            var valance = Path()
            valance.move(to: .zero)
            valance.addLine(to: CGPoint(x: w, y: 0))
            valance.addLine(to: CGPoint(x: w, y: valanceHeight))
            let scallops = 7
            for index in (0..<scallops).reversed() {
                let x1 = w * CGFloat(index) / CGFloat(scallops)
                let x2 = w * CGFloat(index + 1) / CGFloat(scallops)
                valance.addQuadCurve(to: CGPoint(x: x1, y: valanceHeight), control: CGPoint(x: (x1 + x2) / 2, y: valanceHeight + 18))
                _ = x2
            }
            valance.closeSubpath()
            ctx.fill(valance, with: .color(Self.velvet))
            ctx.stroke(valance, with: .color(Theme.ink), lineWidth: 3)
            var fringe = Path()
            fringe.move(to: CGPoint(x: 0, y: valanceHeight - 6))
            fringe.addLine(to: CGPoint(x: w, y: valanceHeight - 6))
            ctx.stroke(fringe, with: .color(Self.gold), style: StrokeStyle(lineWidth: 4, dash: [3, 3]))
        }
        .allowsHitTesting(false)
    }
}

/// Eski film geri sayım kartı: daire, artı işareti, dönen tarama dilimi, ortada rakam.
struct FilmLeader: View {
    let number: Int
    @State private var sweep: Double = 0

    var body: some View {
        ZStack {
            Circle().fill(Theme.cream)
            Circle()
                .trim(from: 0, to: sweep)
                .fill(Theme.ink.opacity(0.18))
                .rotationEffect(.degrees(-90))
            Circle().stroke(Theme.ink, lineWidth: 5)
            Circle().stroke(Theme.ink, lineWidth: 2).padding(18)
            Rectangle().fill(Theme.ink).frame(width: 2)
            Rectangle().fill(Theme.ink).frame(height: 2)
            Text("\(number)")
                .font(Theme.title(96))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 210, height: 210)
        .onAppear {
            sweep = 0
            withAnimation(.linear(duration: 0.42)) { sweep = 1 }
        }
        .id(number)
    }
}

/// Kâğıt zeminli, mürekkep çerçeveli kart (ayar, galeri ve ara menüsü).
struct PaperCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink, lineWidth: 5))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.ink, lineWidth: 1.5).padding(9))
    }
}
