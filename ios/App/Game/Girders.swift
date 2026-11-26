import SpriteKit
import GameCore

/// Her bölümün dünyası; bölüm sonundaki boss'a göz kırpar.
/// Liman (ahtapot) → bahçe (solucan) → perili şato (yarasa) → uzay (uzaylı) → fabrika (robot) → şehir (bulldog), sonra baştan.
enum WorldTheme: Int, CaseIterable {
    case harbor = 0
    case garden
    case haunted
    case space
    case factory
    case city

    /// Boss arenası (1000, 2000, ...) önceki bölümün dünyasında kalır.
    static func forFloor(_ floor: Int, config: TowerConfig) -> WorldTheme {
        let chapter = config.chapter(forFloor: max(0, floor - 1))
        return WorldTheme(rawValue: chapter % allCases.count) ?? .harbor
    }

    /// Bu dünyanın kiriş malzemeleri: her 100 katta sıradaki.
    var materials: [GirderMaterial] {
        switch self {
        case .harbor: return [.steel, .wood, .rope, .pipe, .truss, .deco, .wood, .steel, .rope, .pipe]
        case .garden: return [.wood, .brick, .bamboo, .stone, .wood, .flowerbox, .brick, .bamboo, .stone, .flowerbox]
        case .haunted: return [.stone, .darkWood, .clockwork, .brick, .stone, .truss, .darkWood, .clockwork, .stone, .brick]
        case .space: return [.panel, .neon, .truss, .panel, .clockwork, .neon, .panel, .truss, .neon, .panel]
        case .factory: return [.pipe, .clockwork, .truss, .steel, .bamboo, .pipe, .panel, .clockwork, .steel, .truss]
        case .city: return [.deco, .neon, .brick, .steel, .cloud, .deco, .neon, .wood, .cloud, .deco]
        }
    }
}

enum GirderMaterial {
    case steel, wood, darkWood, rope, brick, stone, bamboo, truss, deco, neon, pipe, cloud, clockwork, panel, flowerbox
}

/// Kiriş. Orijin: üst yüzeyin ortası. Görünüş iki katmanlıdır:
/// 1) Malzeme (dünyaya ve 100 katlık dilime göre): çelik, ahşap, halat köprü, tuğla, taş, bambu iskele, kafes,
///    art deco mermer, neon tabela, bakır boru, bulut, saat çarkları, uzay paneli, çiçek saksısı.
/// 2) Oynanış işareti (her zaman okunur): kayan kirişte tekerlek ve ray, kaygan kirişte buz kaplama ve sarkıtlar,
///    kupa katında altın kaplama, kupa ve flamalar.
/// Ayrıca katın tohumuyla seçilen küçük süsler (üstte ve altta); hiçbiri oynanışı etkilemez.
final class PlatformNode: SKNode {
    let isSliding: Bool

    init(platform: Platform, theme: WorldTheme, materialIndex: Int) {
        if case .sliding = platform.kind { isSliding = true } else { isSliding = false }
        super.init()
        position = CGPoint(x: platform.centerX, y: platform.y)
        let width = CGFloat(platform.width)
        var rng = SplitMix64(seed: UInt64(truncatingIfNeeded: platform.floor &* 2_654_435_761 &+ 97))

        if platform.isMilestone {
            drawMilestone(width: width, floor: platform.floor)
        } else {
            let materials = theme.materials
            let material = materials[((materialIndex % materials.count) + materials.count) % materials.count]
            drawMaterial(material, width: width, rng: &rng)
            drawDecor(theme: theme, width: width, rng: &rng)
        }

        if isSliding { drawSlidingGear(width: width) }
        if platform.isSlippery { drawIce(width: width, rng: &rng) }

        if platform.floor > 0 && platform.floor % 10 == 0 && !platform.isMilestone {
            let plate = shape(CGPath(roundedRect: CGRect(x: -17, y: -32, width: 34, height: 16), cornerWidth: 3, cornerHeight: 3, transform: nil),
                              fill: Palette.cream, width: 2)
            plate.zPosition = 2
            let label = SKLabelNode(fontNamed: Palette.fontName)
            label.text = "\(platform.floor)"
            label.fontSize = 11
            label.fontColor = Palette.ink
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: -24)
            label.zPosition = 3
            addChild(label)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    // MARK: Yardımcılar

    @discardableResult
    private func shape(_ path: CGPath, fill: SKColor, stroke: SKColor = Palette.ink, width: CGFloat = 2.5) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = width > 0 ? stroke : .clear
        node.lineWidth = width
        node.lineJoin = .round
        node.lineCap = .round
        addChild(node)
        return node
    }

    @discardableResult
    private func lines(_ path: CGPath, color: SKColor = Palette.ink, width: CGFloat = 1.5, alpha: CGFloat = 1) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = .clear
        node.strokeColor = color
        node.lineWidth = width
        node.lineCap = .round
        node.lineJoin = .round
        node.alpha = alpha
        addChild(node)
        return node
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> SKColor { SKColor(red: r, green: g, blue: b, alpha: 1) }

    private func body(_ width: CGFloat, fill: SKColor, top: CGFloat = 0, bottom: CGFloat = -13, radius: CGFloat = 2) {
        shape(CGPath(roundedRect: CGRect(x: -width / 2, y: bottom, width: width, height: top - bottom), cornerWidth: radius, cornerHeight: radius, transform: nil), fill: fill)
    }

    // MARK: Malzemeler

    private func drawMaterial(_ material: GirderMaterial, width w: CGFloat, rng: inout SplitMix64) {
        let half = w / 2
        switch material {
        case .steel:
            body(w, fill: Palette.beam)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -half + 3, y: -9))
            path.addLine(to: CGPoint(x: half - 3, y: -9))
            var x = -half + 9
            while x < half - 6 {
                path.addEllipse(in: CGRect(x: x - 1.6, y: -5.6, width: 3.2, height: 3.2))
                x += 17
            }
            shape(path, fill: Palette.ink, width: 1)
            // Kiriş altı: I profili gölgesi
            lines(CGPath(rect: CGRect(x: -half + 2, y: -12, width: w - 4, height: 1), transform: nil), width: 1, alpha: 0.5)

        case .wood, .darkWood:
            let dark = material == .darkWood
            body(w, fill: dark ? Self.rgb(0.36, 0.24, 0.18) : Self.rgb(0.70, 0.48, 0.26))
            let grain = CGMutablePath()
            for row in [CGFloat(-4), -8.5] {
                grain.move(to: CGPoint(x: -half + 4, y: row))
                var x = -half + 4
                while x < half - 8 {
                    let next = min(half - 4, x + 18)
                    grain.addQuadCurve(to: CGPoint(x: next, y: row), control: CGPoint(x: (x + next) / 2, y: row + CGFloat(rng.nextUnit() * 3 - 1.5)))
                    x = next
                }
            }
            lines(grain, width: 1, alpha: 0.45)
            // Budaklar ve uçlarda çiviler
            let knots = CGMutablePath()
            for _ in 0..<max(1, Int(w / 70)) {
                let kx = -half + 10 + CGFloat(rng.nextUnit()) * (w - 20)
                knots.addEllipse(in: CGRect(x: kx - 3, y: -8, width: 6, height: 4))
            }
            for x in [-half + 5, half - 5] {
                knots.addEllipse(in: CGRect(x: x - 1.3, y: -4, width: 2.6, height: 2.6))
                knots.addEllipse(in: CGRect(x: x - 1.3, y: -10, width: 2.6, height: 2.6))
            }
            shape(knots, fill: Palette.ink.withAlphaComponent(0.7), width: 0)
            if dark {
                // Perili şato: yosun lekesi ve çatlak
                let crack = CGMutablePath()
                let cx = -half + CGFloat(rng.nextUnit()) * w
                crack.move(to: CGPoint(x: cx, y: 0))
                crack.addLines(between: [CGPoint(x: cx, y: 0), CGPoint(x: cx + 3, y: -4), CGPoint(x: cx - 1, y: -8)])
                lines(crack, width: 1.2)
            }

        case .rope:
            // Halat köprü: ayrık tahtalar, altta iki halat.
            var x = -half
            var index = 0
            while x < half - 1 {
                let plank = min(13, half - x)
                let tone: SKColor = index % 2 == 0 ? Self.rgb(0.72, 0.52, 0.30) : Self.rgb(0.62, 0.43, 0.24)
                shape(CGPath(roundedRect: CGRect(x: x, y: -9, width: plank - 1.5, height: 9), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil),
                      fill: tone, width: 1.8)
                x += plank
                index += 1
            }
            let rope = CGMutablePath()
            rope.move(to: CGPoint(x: -half, y: -11))
            rope.addQuadCurve(to: CGPoint(x: half, y: -11), control: CGPoint(x: 0, y: -18))
            rope.move(to: CGPoint(x: -half, y: -6))
            rope.addLine(to: CGPoint(x: half, y: -6))
            lines(rope, color: Self.rgb(0.55, 0.40, 0.22), width: 2.4)

        case .brick:
            body(w, fill: Self.rgb(0.74, 0.36, 0.24))
            let mortar = CGMutablePath()
            mortar.move(to: CGPoint(x: -half, y: -6.5))
            mortar.addLine(to: CGPoint(x: half, y: -6.5))
            for row in 0..<2 {
                var x = -half + (row == 0 ? 8 : 16)
                while x < half {
                    let y0: CGFloat = row == 0 ? -6.5 : -13
                    mortar.move(to: CGPoint(x: x, y: y0))
                    mortar.addLine(to: CGPoint(x: x, y: y0 + 6.5))
                    x += 16
                }
            }
            lines(mortar, color: Palette.cream, width: 1.4, alpha: 0.8)
            // Taş başlık
            body(w + 4, fill: Self.rgb(0.90, 0.84, 0.70), top: 0, bottom: -3, radius: 1.5)

        case .stone:
            body(w, fill: Self.rgb(0.66, 0.64, 0.60))
            let blocks = CGMutablePath()
            var x = -half + 22
            while x < half - 4 {
                blocks.move(to: CGPoint(x: x, y: 0))
                blocks.addLine(to: CGPoint(x: x, y: -13))
                x += 22 + CGFloat(rng.nextUnit() * 8)
            }
            let cx = -half + 8 + CGFloat(rng.nextUnit()) * (w - 16)
            blocks.move(to: CGPoint(x: cx, y: -2))
            blocks.addLines(between: [CGPoint(x: cx, y: -2), CGPoint(x: cx + 4, y: -6), CGPoint(x: cx + 1, y: -10)])
            lines(blocks, width: 1.3, alpha: 0.7)
            // Yosun
            let moss = CGMutablePath()
            for _ in 0..<2 {
                let mx = -half + CGFloat(rng.nextUnit()) * w
                moss.addEllipse(in: CGRect(x: mx - 6, y: -3, width: 12, height: 5))
            }
            shape(moss, fill: Self.rgb(0.42, 0.62, 0.30).withAlphaComponent(0.85), width: 0)

        case .bamboo:
            // İskele: üstte tahta, altta çapraz bağlı direkler.
            let brace = CGMutablePath()
            var x = -half + 4
            while x < half - 10 {
                let next = min(half - 4, x + 26)
                brace.move(to: CGPoint(x: x, y: -6))
                brace.addLine(to: CGPoint(x: next, y: -16))
                brace.move(to: CGPoint(x: x, y: -16))
                brace.addLine(to: CGPoint(x: next, y: -6))
                x = next
            }
            brace.move(to: CGPoint(x: -half + 2, y: -16))
            brace.addLine(to: CGPoint(x: half - 2, y: -16))
            lines(brace, color: Self.rgb(0.55, 0.62, 0.30), width: 3)
            lines(brace, width: 0.8, alpha: 0.6)
            body(w, fill: Self.rgb(0.80, 0.66, 0.40), top: 0, bottom: -6, radius: 1.5)
            let knots = CGMutablePath()
            var kx = -half + 12
            while kx < half - 6 {
                knots.move(to: CGPoint(x: kx, y: -1))
                knots.addLine(to: CGPoint(x: kx, y: -5))
                kx += 24
            }
            lines(knots, width: 1, alpha: 0.6)

        case .truss:
            // Kafes kiriş: üst ve alt başlık, arada zikzak; içi açık.
            let navy = Self.rgb(0.22, 0.30, 0.46)
            body(w, fill: navy, top: 0, bottom: -3.5, radius: 1)
            body(w, fill: navy, top: -10, bottom: -13, radius: 1)
            let zig = CGMutablePath()
            var x = -half + 2
            var up = true
            zig.move(to: CGPoint(x: x, y: -10))
            while x < half - 2 {
                x = min(half - 2, x + 9)
                zig.addLine(to: CGPoint(x: x, y: up ? -3.5 : -10))
                up.toggle()
            }
            lines(zig, color: navy, width: 2.6)

        case .deco:
            // 1930'lar art deco: krem mermer, altın şeritler, ok uçlu desen, siyah uç blokları.
            body(w, fill: Self.rgb(0.95, 0.90, 0.80))
            let gold = Self.rgb(0.86, 0.66, 0.24)
            body(w, fill: gold, top: -1, bottom: -3, radius: 0)
            body(w, fill: gold, top: -10, bottom: -12, radius: 0)
            let chevrons = CGMutablePath()
            var x = -half + 12
            while x < half - 12 {
                chevrons.move(to: CGPoint(x: x - 4, y: -4.5))
                chevrons.addLine(to: CGPoint(x: x, y: -8))
                chevrons.addLine(to: CGPoint(x: x + 4, y: -4.5))
                x += 12
            }
            lines(chevrons, color: gold, width: 1.6)
            for side in [CGFloat(-1), 1] {
                shape(CGPath(rect: CGRect(x: side < 0 ? -half : half - 8, y: -13, width: 8, height: 13), transform: nil), fill: Palette.ink, width: 1)
            }

        case .neon:
            // Neon tabela: koyu levha, kenarda ampuller, ortada dalgalı neon tüp.
            body(w, fill: Self.rgb(0.22, 0.12, 0.26))
            let tube = CGMutablePath()
            tube.move(to: CGPoint(x: -half + 8, y: -6.5))
            var x = -half + 8
            while x < half - 8 {
                let next = min(half - 8, x + 14)
                tube.addQuadCurve(to: CGPoint(x: next, y: -6.5), control: CGPoint(x: (x + next) / 2, y: x.truncatingRemainder(dividingBy: 28) < 14 ? -2.5 : -10.5))
                x = next
            }
            let tint: SKColor = rng.nextUnit() < 0.5 ? Self.rgb(1, 0.40, 0.70) : Self.rgb(0.35, 0.95, 0.95)
            lines(tube, color: tint.withAlphaComponent(0.35), width: 5)
            lines(tube, color: tint, width: 2)
            let bulbs = CGMutablePath()
            var bx = -half + 5
            while bx < half - 3 {
                bulbs.addEllipse(in: CGRect(x: bx - 1.6, y: -2.6, width: 3.2, height: 3.2))
                bulbs.addEllipse(in: CGRect(x: bx - 1.6, y: -12, width: 3.2, height: 3.2))
                bx += 9
            }
            shape(bulbs, fill: Palette.milestone, width: 0.6)

        case .pipe:
            // Bakır boru: parlak çizgi, aralıklarla flanş ve cıvata.
            body(w, fill: Self.rgb(0.80, 0.48, 0.25), top: 0, bottom: -12, radius: 6)
            lines(CGPath(rect: CGRect(x: -half + 5, y: -3, width: w - 10, height: 0.5), transform: nil), color: Self.rgb(1, 0.82, 0.62), width: 2)
            var x = -half + 30
            while x < half - 10 {
                shape(CGPath(roundedRect: CGRect(x: x - 3.5, y: -14, width: 7, height: 16), cornerWidth: 2, cornerHeight: 2, transform: nil),
                      fill: Self.rgb(0.62, 0.34, 0.16), width: 1.8)
                x += 44
            }
            if w > 110 {
                // Vana çarkı (altta)
                let wheel = CGMutablePath()
                wheel.addEllipse(in: CGRect(x: -7, y: -27, width: 14, height: 14))
                wheel.move(to: CGPoint(x: 0, y: -27))
                wheel.addLine(to: CGPoint(x: 0, y: -13))
                wheel.move(to: CGPoint(x: -7, y: -20))
                wheel.addLine(to: CGPoint(x: 7, y: -20))
                lines(wheel, color: Palette.beam, width: 2.5)
            }

        case .cloud:
            // Bulut kiriş (yükseklerde): kabarık tepecikler, altta mavimsi gölge.
            let puffs = CGMutablePath()
            var x = -half + 8
            while x < half - 4 {
                let r = CGFloat(7 + rng.nextUnit() * 5)
                puffs.addEllipse(in: CGRect(x: x - r, y: -9 - r * 0.6, width: r * 2, height: r * 1.6))
                x += r * 1.3
            }
            puffs.addRoundedRect(in: CGRect(x: -half, y: -8, width: w, height: 8), cornerWidth: 4, cornerHeight: 4)
            shape(puffs, fill: Palette.cream, width: 2.2)
            shape(CGPath(roundedRect: CGRect(x: -half + 6, y: -14, width: w - 12, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil),
                  fill: Self.rgb(0.72, 0.80, 0.95).withAlphaComponent(0.8), width: 0)
            body(w, fill: Palette.cream, top: 0, bottom: -5, radius: 2.5)

        case .clockwork:
            // Pirinç saat mekanizması: dişli alt kenar, altta dönen çarklar.
            let brass = Self.rgb(0.84, 0.66, 0.30)
            body(w, fill: brass, top: 0, bottom: -9)
            let teeth = CGMutablePath()
            var x = -half + 3
            while x < half - 3 {
                teeth.addRect(CGRect(x: x, y: -13, width: 3.5, height: 4))
                x += 7
            }
            shape(teeth, fill: brass, width: 1.2)
            for gx in [-half * 0.45, half * 0.35] where w > 90 {
                let gear = CGMutablePath()
                let r: CGFloat = 8
                for index in 0..<10 {
                    let a = CGFloat(index) * .pi / 5
                    let rr = index % 2 == 0 ? r + 2.5 : r
                    let point = CGPoint(x: gx + cos(a) * rr, y: -22 + sin(a) * rr)
                    if index == 0 { gear.move(to: point) } else { gear.addLine(to: point) }
                }
                gear.closeSubpath()
                gear.addEllipse(in: CGRect(x: gx - 2.5, y: -24.5, width: 5, height: 5))
                shape(gear, fill: Self.rgb(0.72, 0.52, 0.22), width: 1.6)
            }
            lines(CGPath(rect: CGRect(x: -half + 4, y: -4.5, width: w - 8, height: 0.5), transform: nil), color: Self.rgb(1, 0.9, 0.6), width: 1.5)

        case .panel:
            // Uzay paneli: dikişler, yanıp sönen ışıklar, uçlarda tehlike şeritleri.
            body(w, fill: Self.rgb(0.70, 0.76, 0.84))
            let seams = CGMutablePath()
            var x = -half + 20
            while x < half - 10 {
                seams.move(to: CGPoint(x: x, y: 0))
                seams.addLine(to: CGPoint(x: x, y: -13))
                x += 20
            }
            lines(seams, width: 1, alpha: 0.55)
            let lights = CGMutablePath()
            var lx = -half + 10
            while lx < half - 8 {
                lights.addEllipse(in: CGRect(x: lx - 1.8, y: -8, width: 3.6, height: 3.6))
                lx += 20
            }
            shape(lights, fill: rng.nextUnit() < 0.5 ? Self.rgb(0.40, 0.95, 0.45) : Self.rgb(1, 0.35, 0.30), width: 0.8)
            for side in [CGFloat(-1), 1] {
                let start = side < 0 ? -half : half - 12
                let stripes = CGMutablePath()
                stripes.addRect(CGRect(x: start, y: -13, width: 12, height: 13))
                shape(stripes, fill: Palette.milestone, width: 1.2)
                let diag = CGMutablePath()
                for offset in stride(from: CGFloat(0), to: 12, by: 6) {
                    diag.move(to: CGPoint(x: start + offset, y: -13))
                    diag.addLine(to: CGPoint(x: start + offset + 4, y: 0))
                }
                lines(diag, width: 2.2)
            }

        case .flowerbox:
            // Çiçek saksısı: toprak ve üstte çiçek sırası (kenarlarda, ortası basılabilir boş).
            body(w, fill: Self.rgb(0.80, 0.42, 0.26))
            body(w + 4, fill: Self.rgb(0.70, 0.34, 0.20), top: -9, bottom: -13, radius: 1)
            let soil = CGMutablePath()
            soil.addRect(CGRect(x: -half + 2, y: -2.5, width: w - 4, height: 2.5))
            shape(soil, fill: Self.rgb(0.32, 0.22, 0.14), width: 0)
            for side in [CGFloat(-1), 1] {
                let fx = side * (half - 9)
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: fx, y: 0))
                stem.addLine(to: CGPoint(x: fx, y: 9))
                lines(stem, color: Self.rgb(0.30, 0.55, 0.25), width: 2)
                let petals = CGMutablePath()
                for index in 0..<5 {
                    let a = CGFloat(index) * 2 * .pi / 5
                    petals.addEllipse(in: CGRect(x: fx + cos(a) * 3.2 - 2.5, y: 11 + sin(a) * 3.2 - 2.5, width: 5, height: 5))
                }
                shape(petals, fill: side < 0 ? Self.rgb(1, 0.45, 0.55) : Palette.milestone, width: 1)
                shape(CGPath(ellipseIn: CGRect(x: fx - 1.8, y: 9.2, width: 3.6, height: 3.6), transform: nil), fill: Palette.ink, width: 0)
            }
        }
    }

    // MARK: Oynanış işaretleri

    /// Kupa katı: altın kaplama, kupa, renkli flamalar.
    private func drawMilestone(width w: CGFloat, floor: Int) {
        let half = w / 2
        body(w, fill: Palette.milestone)
        let pattern = CGMutablePath()
        var x = -half + 10
        while x < half - 10 {
            pattern.addEllipse(in: CGRect(x: x - 2, y: -8.5, width: 4, height: 4))
            x += 14
        }
        shape(pattern, fill: Palette.beam, width: 0)
        // Flamalar
        let colors: [SKColor] = [Palette.beam, Palette.slidingBeam, Palette.cream, Self.rgb(0.40, 0.30, 0.60)]
        var fx = -half + 6
        var index = 0
        while fx < half - 12 {
            let flag = CGMutablePath()
            flag.addLines(between: [CGPoint(x: fx, y: -13), CGPoint(x: fx + 12, y: -13), CGPoint(x: fx + 6, y: -24)])
            flag.closeSubpath()
            shape(flag, fill: colors[index % colors.count], width: 1.3)
            fx += 14
            index += 1
        }
        if let tier = TrophyTier(checkpointFloor: floor) {
            let trophy = TrophyNode(tier: tier, size: 30)
            trophy.position = CGPoint(x: 0, y: 17)
            trophy.zPosition = 1
            addChild(trophy)
        }
    }

    /// Kayan kiriş: altta ray tekerlekleri ve ok işaretleri.
    private func drawSlidingGear(width w: CGFloat) {
        for side in [CGFloat(-1), 1] {
            let wheel = CGMutablePath()
            let center = CGPoint(x: side * (w / 2 - 9), y: -18)
            wheel.addEllipse(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10))
            shape(wheel, fill: Palette.slidingBeam, width: 2)
            let hub = CGMutablePath()
            hub.move(to: CGPoint(x: center.x - 4, y: center.y))
            hub.addLine(to: CGPoint(x: center.x + 4, y: center.y))
            hub.move(to: CGPoint(x: center.x, y: center.y - 4))
            hub.addLine(to: CGPoint(x: center.x, y: center.y + 4))
            lines(hub, width: 1.4)
        }
        let arrows = CGMutablePath()
        for side in [CGFloat(-1), 1] {
            let tip = CGPoint(x: side * 12, y: -19)
            arrows.move(to: CGPoint(x: tip.x - side * 7, y: tip.y + 3.5))
            arrows.addLine(to: tip)
            arrows.addLine(to: CGPoint(x: tip.x - side * 7, y: tip.y - 3.5))
        }
        lines(arrows, color: Palette.slidingBeam, width: 2.4)
    }

    /// Kaygan kiriş: buz kaplaması, parlama çizgileri, farklı boyda sarkıtlar.
    private func drawIce(width w: CGFloat, rng: inout SplitMix64) {
        let half = w / 2
        let coat = shape(CGPath(roundedRect: CGRect(x: -half - 2, y: -5, width: w + 4, height: 7), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil),
                         fill: Palette.slipperyBeam.withAlphaComponent(0.92), width: 2)
        coat.zPosition = 1
        let shine = CGMutablePath()
        var x = -half + 10
        while x < half - 10 {
            shine.move(to: CGPoint(x: x, y: 0))
            shine.addLine(to: CGPoint(x: x + 6, y: -3))
            x += 20
        }
        lines(shine, color: .white, width: 2).zPosition = 2
        let icicles = CGMutablePath()
        var ix = -half + 8
        while ix < half - 6 {
            let length = CGFloat(6 + rng.nextUnit() * 10)
            icicles.addLines(between: [CGPoint(x: ix - 3, y: -13), CGPoint(x: ix, y: -13 - length), CGPoint(x: ix + 3, y: -13)])
            icicles.closeSubpath()
            ix += CGFloat(14 + rng.nextUnit() * 12)
        }
        shape(icicles, fill: Palette.slipperyBeam, width: 1.2)
    }

    // MARK: Süsler

    /// Dünyaya özgü küçük süsler: kirişin ucunda (üstte) ya da altında asılı. Katların yaklaşık üçte birinde.
    private func drawDecor(theme: WorldTheme, width w: CGFloat, rng: inout SplitMix64) {
        let roll = rng.nextUnit()
        guard roll < 0.38, w > 70 else { return }
        let side: CGFloat = rng.nextUnit() < 0.5 ? -1 : 1
        let x = side * (w / 2 - 10)
        let variant = Int(rng.next() % 3)
        let ink = Palette.ink
        switch (theme, variant) {
        case (.harbor, 0): // halat yumağı
            let coil = CGMutablePath()
            coil.addEllipse(in: CGRect(x: x - 7, y: 0, width: 14, height: 6))
            coil.addEllipse(in: CGRect(x: x - 5, y: 3, width: 10, height: 5))
            shape(coil, fill: Self.rgb(0.80, 0.66, 0.42), width: 1.5)
        case (.harbor, 1): // can simidi (altta asılı)
            let ring = CGPath(ellipseIn: CGRect(x: x - 6, y: -30, width: 12, height: 12), transform: nil)
            lines(ring, color: Palette.ink, width: 7)
            lines(ring, color: Palette.beam, width: 4.5)
            lines(CGPath(rect: CGRect(x: x - 0.5, y: -18, width: 1, height: 5), transform: nil), width: 1.5)
        case (.harbor, _): // martı (üstte duruyor)
            shape(CGPath(ellipseIn: CGRect(x: x - 6, y: 2, width: 12, height: 8), transform: nil), fill: .white, width: 1.5)
            shape(CGPath(ellipseIn: CGRect(x: x + side * 4 - 3, y: 7, width: 6, height: 6), transform: nil), fill: .white, width: 1.5)
            let beak = CGMutablePath()
            beak.addLines(between: [CGPoint(x: x + side * 6.5, y: 10), CGPoint(x: x + side * 10, y: 9), CGPoint(x: x + side * 6.5, y: 8.5)])
            shape(beak, fill: Palette.milestone, width: 1)
            lines(CGPath(rect: CGRect(x: x - 2, y: 0, width: 0.5, height: 2), transform: nil), width: 1.2)
        case (.garden, 0): // salyangoz
            shape(CGPath(ellipseIn: CGRect(x: x - 8, y: 0, width: 14, height: 4), transform: nil), fill: Self.rgb(0.75, 0.80, 0.50), width: 1.3)
            let shell = CGMutablePath()
            shell.addEllipse(in: CGRect(x: x - 6, y: 2, width: 10, height: 10))
            shape(shell, fill: Self.rgb(0.80, 0.55, 0.30), width: 1.5)
            let spiral = CGMutablePath()
            spiral.addArc(center: CGPoint(x: x - 1, y: 7), radius: 2.5, startAngle: 0, endAngle: .pi * 1.6, clockwise: false)
            lines(spiral, width: 1)
        case (.garden, 1): // sarmaşık (altta)
            let vine = CGMutablePath()
            vine.move(to: CGPoint(x: x, y: -13))
            vine.addCurve(to: CGPoint(x: x + 2, y: -40), control1: CGPoint(x: x + 8, y: -22), control2: CGPoint(x: x - 8, y: -30))
            lines(vine, color: Self.rgb(0.30, 0.55, 0.25), width: 2)
            let leaves = CGMutablePath()
            for (dy, dx) in [(CGFloat(-20), CGFloat(4)), (-30, -4), (-38, 4)] {
                leaves.addEllipse(in: CGRect(x: x + dx - 3, y: dy - 2, width: 6, height: 4))
            }
            shape(leaves, fill: Self.rgb(0.42, 0.70, 0.32), width: 1)
        case (.garden, _): // elma
            shape(CGPath(ellipseIn: CGRect(x: x - 5, y: 0, width: 10, height: 9), transform: nil), fill: Palette.beam, width: 1.5)
            lines(CGPath(rect: CGRect(x: x, y: 9, width: 0.5, height: 3), transform: nil), width: 1.5)
            shape(CGPath(ellipseIn: CGRect(x: x + 1, y: 9, width: 5, height: 3), transform: nil), fill: Self.rgb(0.42, 0.70, 0.32), width: 1)
        case (.haunted, 0): // örümcek ağı (köşede, altta)
            // Kirişin alt köşesinden içeri ve aşağı açılan çeyrek ağ.
            let web = CGMutablePath()
            let corner = CGPoint(x: side * w / 2, y: -13)
            let inward = -side
            for index in 0..<4 {
                let a = CGFloat(index) * (CGFloat.pi / 2) / 3
                web.move(to: corner)
                web.addLine(to: CGPoint(x: corner.x + inward * cos(a) * 18, y: corner.y - sin(a) * 18))
            }
            for r in [CGFloat(7), 13] {
                web.move(to: CGPoint(x: corner.x + inward * r, y: corner.y))
                web.addQuadCurve(to: CGPoint(x: corner.x, y: corner.y - r),
                                 control: CGPoint(x: corner.x + inward * r * 0.45, y: corner.y - r * 0.45))
            }
            lines(web, color: Palette.cream, width: 1, alpha: 0.85)
        case (.haunted, 1): // mum
            shape(CGPath(rect: CGRect(x: x - 2.5, y: 0, width: 5, height: 10), transform: nil), fill: Palette.cream, width: 1.4)
            let flame = CGMutablePath()
            flame.addEllipse(in: CGRect(x: x - 2, y: 11, width: 4, height: 7))
            shape(flame, fill: Palette.flame, width: 1)
        case (.haunted, _): // asılı yarasa yavrusu
            lines(CGPath(rect: CGRect(x: x, y: -18, width: 0.5, height: 5), transform: nil), width: 1.2)
            shape(CGPath(ellipseIn: CGRect(x: x - 4, y: -27, width: 8, height: 10), transform: nil), fill: Self.rgb(0.34, 0.24, 0.40), width: 1.4)
            let wings = CGMutablePath()
            wings.addLines(between: [CGPoint(x: x - 4, y: -20), CGPoint(x: x - 9, y: -28), CGPoint(x: x - 4, y: -26)])
            wings.addLines(between: [CGPoint(x: x + 4, y: -20), CGPoint(x: x + 9, y: -28), CGPoint(x: x + 4, y: -26)])
            shape(wings, fill: Self.rgb(0.26, 0.18, 0.30), width: 1.2)
        case (.space, 0): // anten
            lines(CGPath(rect: CGRect(x: x, y: 0, width: 0.5, height: 14), transform: nil), width: 1.8)
            shape(CGPath(ellipseIn: CGRect(x: x - 3, y: 13, width: 6, height: 6), transform: nil), fill: Self.rgb(1, 0.35, 0.30), width: 1.2)
        case (.space, 1): // uzay bitkisi
            let plant = CGMutablePath()
            plant.move(to: CGPoint(x: x, y: 0))
            plant.addQuadCurve(to: CGPoint(x: x + 4, y: 12), control: CGPoint(x: x - 6, y: 6))
            lines(plant, color: Self.rgb(0.55, 0.30, 0.80), width: 2)
            shape(CGPath(ellipseIn: CGRect(x: x + 1, y: 11, width: 7, height: 7), transform: nil), fill: Self.rgb(0.50, 0.95, 0.60), width: 1.2)
        case (.space, _): // çanak anten
            let dish = CGMutablePath()
            dish.addArc(center: CGPoint(x: x, y: 8), radius: 7, startAngle: .pi * 1.1, endAngle: .pi * 1.9, clockwise: true)
            dish.closeSubpath()
            shape(dish, fill: Self.rgb(0.80, 0.84, 0.90), width: 1.4)
            lines(CGPath(rect: CGRect(x: x, y: 0, width: 0.5, height: 5), transform: nil), width: 1.6)
        case (.factory, 0): // yağdanlık
            shape(CGPath(roundedRect: CGRect(x: x - 5, y: 0, width: 10, height: 8), cornerWidth: 2, cornerHeight: 2, transform: nil),
                  fill: Self.rgb(0.40, 0.48, 0.40), width: 1.4)
            let spout = CGMutablePath()
            spout.move(to: CGPoint(x: x + side * 4, y: 7))
            spout.addLine(to: CGPoint(x: x + side * 11, y: 13))
            lines(spout, width: 2)
        case (.factory, 1): // zincir ve kanca (altta)
            let chain = CGMutablePath()
            for index in 0..<4 {
                chain.addEllipse(in: CGRect(x: x - 2, y: -18 - CGFloat(index) * 5, width: 4, height: 6))
            }
            chain.move(to: CGPoint(x: x, y: -36))
            chain.addArc(center: CGPoint(x: x - 3, y: -38), radius: 3, startAngle: 0, endAngle: .pi, clockwise: true)
            lines(chain, width: 1.5)
        case (.factory, _): // alet kutusu
            shape(CGPath(rect: CGRect(x: x - 7, y: 0, width: 14, height: 7), transform: nil), fill: Palette.beam, width: 1.4)
            lines(CGPath(roundedRect: CGRect(x: x - 3, y: 7, width: 6, height: 3), cornerWidth: 1, cornerHeight: 1, transform: nil), width: 1.4)
        case (.city, 0): // yemek kutusu
            shape(CGPath(roundedRect: CGRect(x: x - 6, y: 0, width: 12, height: 8), cornerWidth: 3, cornerHeight: 3, transform: nil),
                  fill: Palette.slidingBeam, width: 1.4)
            lines(CGPath(roundedRect: CGRect(x: x - 3, y: 8, width: 6, height: 3), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), width: 1.4)
        case (.city, 1): // sarkan lamba (altta)
            lines(CGPath(rect: CGRect(x: x, y: -22, width: 0.5, height: 9), transform: nil), width: 1.4)
            let shade = CGMutablePath()
            shade.addLines(between: [CGPoint(x: x - 7, y: -28), CGPoint(x: x - 3, y: -22), CGPoint(x: x + 3, y: -22), CGPoint(x: x + 7, y: -28)])
            shade.closeSubpath()
            shape(shade, fill: Palette.slidingBeam, width: 1.4)
            shape(CGPath(ellipseIn: CGRect(x: x - 2.5, y: -31, width: 5, height: 4), transform: nil), fill: Palette.flameCore, width: 1)
        case (.city, _): // boya kovası
            shape(CGPath(rect: CGRect(x: x - 5, y: 0, width: 10, height: 9), transform: nil), fill: Self.rgb(0.80, 0.82, 0.86), width: 1.4)
            shape(CGPath(rect: CGRect(x: x - 5, y: 6, width: 10, height: 3), transform: nil), fill: Self.rgb(0.95, 0.55, 0.20), width: 0)
            let drip = CGMutablePath()
            drip.addEllipse(in: CGRect(x: x + 2, y: 2, width: 3, height: 5))
            shape(drip, fill: Self.rgb(0.95, 0.55, 0.20), width: 0.8)
            _ = ink
        }
    }
}
