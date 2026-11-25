import SpriteKit
import UIKit
import GameCore

/// Kodla "suluboya" boyayan ressam. Cuphead'in arka planları elle suluboya boyanmıştır;
/// burada aynı hissi katman katman yarı saydam fırça lekeleri ve kâğıt dokusuyla taklit ederiz.
/// Her doku bir kez, oyun açılırken boyanır (deterministik: aynı tohum, aynı resim).
enum WatercolorPainter {
    struct RGB {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat
        func color(_ alpha: CGFloat = 1) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: alpha) }
        func mix(_ other: RGB, _ t: CGFloat) -> RGB {
            RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
        }
    }

    static let ink = RGB(r: 0.12, g: 0.09, b: 0.07)

    /// Gökyüzü: dikey geçiş, üstüne düzensiz suluboya lekeleri ve kâğıt greni.
    static func sky(top: RGB, bottom: RGB, seed: UInt64) -> UIImage {
        let size = CGSize(width: 180, height: 360)
        var rng = SplitMix64(seed: seed)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let steps = 60
            for index in 0..<steps {
                let t = CGFloat(index) / CGFloat(steps - 1)
                cg.setFillColor(top.mix(bottom, t).color().cgColor)
                cg.fill(CGRect(x: 0, y: size.height * CGFloat(index) / CGFloat(steps), width: size.width, height: size.height / CGFloat(steps) + 1))
            }
            // Suluboya lekeleri: açık ve koyu, çok saydam, üst üste.
            for _ in 0..<90 {
                let x = CGFloat(rng.nextUnit()) * size.width
                let y = CGFloat(rng.nextUnit()) * size.height
                let w = 20 + CGFloat(rng.nextUnit()) * 90
                let h = w * (0.4 + CGFloat(rng.nextUnit()) * 0.5)
                let base = top.mix(bottom, y / size.height)
                let tone = rng.nextUnit() < 0.5 ? base.mix(RGB(r: 1, g: 1, b: 1), 0.35) : base.mix(ink, 0.12)
                cg.setFillColor(tone.color(0.05 + CGFloat(rng.nextUnit()) * 0.05).cgColor)
                cg.fillEllipse(in: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
            }
            paperGrain(cg, size: size, rng: &rng, amount: 900)
        }
    }

    /// Kabarık çizgi film bulutu: mürekkep çerçeve, krem dolgu, altta mavimsi gölge; bazılarının yüzü var.
    static func cloud(seed: UInt64, tint: RGB, withFace: Bool) -> UIImage {
        var rng = SplitMix64(seed: seed)
        let size = CGSize(width: 200, height: 110)
        let puffs: [(CGPoint, CGFloat)] = (0..<7).map { index in
            let t = CGFloat(index) / 6
            let x = 34 + t * 132 + CGFloat(rng.nextUnit() - 0.5) * 10
            let arch = sin(t * .pi)
            let radius = 20 + arch * 18 + CGFloat(rng.nextUnit()) * 8
            let y = 68 - arch * 20 + CGFloat(rng.nextUnit() - 0.5) * 6
            return (CGPoint(x: x, y: y), radius)
        }
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            // Çerçeve: biraz büyük mürekkep daireleri, sonra içi.
            cg.setFillColor(ink.color().cgColor)
            for (center, radius) in puffs {
                cg.fillEllipse(in: CGRect(x: center.x - radius - 3, y: center.y - radius - 3, width: (radius + 3) * 2, height: (radius + 3) * 2))
            }
            cg.fill(CGRect(x: 30, y: 70, width: 140, height: 22))
            let body = tint.mix(RGB(r: 1, g: 0.98, b: 0.92), 0.75)
            cg.setFillColor(body.color().cgColor)
            for (center, radius) in puffs {
                cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            cg.fill(CGRect(x: 33, y: 70, width: 134, height: 19))
            // Alt gölge ve suluboya lekeleri
            let shade = body.mix(tint, 0.5).mix(RGB(r: 0.5, g: 0.6, b: 0.8), 0.25)
            cg.setFillColor(shade.color(0.45).cgColor)
            cg.fillEllipse(in: CGRect(x: 36, y: 72, width: 128, height: 16))
            for _ in 0..<18 {
                let (center, radius) = puffs[Int(rng.next() % UInt64(puffs.count))]
                cg.setFillColor(shade.color(0.08).cgColor)
                cg.fillEllipse(in: CGRect(x: center.x - radius * 0.8, y: center.y - radius * 0.2, width: radius * 1.4, height: radius))
            }
            // Parlak kenar
            cg.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            let (top, topRadius) = puffs[3]
            cg.fillEllipse(in: CGRect(x: top.x - topRadius * 0.55, y: top.y - topRadius * 0.75, width: topRadius * 0.6, height: topRadius * 0.35))
            if withFace {
                // 1930'lar bulut yüzü: turta gözler ve gülümseme.
                let face = CGPoint(x: 100, y: 62)
                cg.setFillColor(ink.color().cgColor)
                for dx in [CGFloat(-11), 11] {
                    cg.fillEllipse(in: CGRect(x: face.x + dx - 4, y: face.y - 9, width: 8, height: 13))
                }
                cg.setStrokeColor(ink.color().cgColor)
                cg.setLineWidth(3)
                cg.setLineCap(.round)
                cg.addArc(center: CGPoint(x: face.x, y: face.y + 6), radius: 9, startAngle: 0.25 * .pi, endAngle: 0.75 * .pi, clockwise: false)
                cg.strokePath()
                cg.setFillColor(RGB(r: 1, g: 0.55, b: 0.5).color(0.5).cgColor)
                for dx in [CGFloat(-20), 20] {
                    cg.fillEllipse(in: CGRect(x: face.x + dx - 6, y: face.y + 2, width: 12, height: 7))
                }
            }
            paperGrain(cg, size: size, rng: &rng, amount: 120)
        }
    }

    /// Uzak şehir silueti: farklı yükseklikte binalar, kuleler, su depoları, yanan pencereler.
    static func skyline(seed: UInt64, wash: RGB, window: RGB) -> UIImage {
        var rng = SplitMix64(seed: seed)
        let size = CGSize(width: 400, height: 220)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            var x: CGFloat = -10
            while x < size.width {
                let width = 30 + CGFloat(rng.nextUnit()) * 40
                let height = 60 + CGFloat(rng.nextUnit()) * 140
                let rect = CGRect(x: x, y: size.height - height, width: width, height: height)
                let tone = wash.mix(ink, CGFloat(rng.nextUnit()) * 0.15)
                cg.setFillColor(tone.color().cgColor)
                cg.fill(rect)
                // Çatı süsü
                let roof = rng.nextUnit()
                if roof < 0.25 {
                    cg.move(to: CGPoint(x: rect.midX - 6, y: rect.minY))
                    cg.addLine(to: CGPoint(x: rect.midX, y: rect.minY - 34))
                    cg.addLine(to: CGPoint(x: rect.midX + 6, y: rect.minY))
                    cg.fillPath()
                } else if roof < 0.45 {
                    cg.fillEllipse(in: CGRect(x: rect.midX - width * 0.3, y: rect.minY - width * 0.3, width: width * 0.6, height: width * 0.6))
                } else if roof < 0.6 {
                    cg.fill(CGRect(x: rect.minX + 6, y: rect.minY - 20, width: 14, height: 14))
                    cg.fill(CGRect(x: rect.minX + 8, y: rect.minY - 6, width: 2, height: 6))
                    cg.fill(CGRect(x: rect.minX + 16, y: rect.minY - 6, width: 2, height: 6))
                }
                // Pencereler
                var wy = rect.minY + 8
                while wy < size.height - 10 {
                    var wx = rect.minX + 5
                    while wx < rect.maxX - 8 {
                        let lit = rng.nextUnit() < 0.35
                        cg.setFillColor((lit ? window.color(0.85) : tone.mix(ink, 0.25).color(0.6)).cgColor)
                        cg.fill(CGRect(x: wx, y: wy, width: 4, height: 6))
                        wx += 9
                    }
                    wy += 12
                }
                x += width + CGFloat(rng.nextUnit()) * 6
            }
            // Suluboya pusu: alta doğru açılır (atmosfer derinliği).
            for index in 0..<20 {
                let t = CGFloat(index) / 19
                cg.setFillColor(wash.mix(RGB(r: 1, g: 1, b: 1), 0.6).color(0.03 * t).cgColor)
                cg.fill(CGRect(x: 0, y: size.height * t, width: size.width, height: size.height * (1 - t)))
            }
            paperGrain(cg, size: size, rng: &rng, amount: 300)
        }
    }

    /// Gülümseyen 1930'lar güneşi (ışınları ayrı, döner).
    static func sun(color: RGB) -> UIImage {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setFillColor(ink.color().cgColor)
            cg.fillEllipse(in: CGRect(x: 8, y: 8, width: 104, height: 104))
            cg.setFillColor(color.color().cgColor)
            cg.fillEllipse(in: CGRect(x: 12, y: 12, width: 96, height: 96))
            cg.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            cg.fillEllipse(in: CGRect(x: 28, y: 24, width: 30, height: 18))
            cg.setFillColor(ink.color().cgColor)
            for dx in [CGFloat(-14), 14] {
                cg.fillEllipse(in: CGRect(x: 60 + dx - 5, y: 46, width: 10, height: 16))
            }
            cg.setStrokeColor(ink.color().cgColor)
            cg.setLineWidth(4)
            cg.setLineCap(.round)
            cg.addArc(center: CGPoint(x: 60, y: 70), radius: 16, startAngle: 0.2 * .pi, endAngle: 0.8 * .pi, clockwise: false)
            cg.strokePath()
            cg.setFillColor(RGB(r: 1, g: 0.45, b: 0.35).color(0.55).cgColor)
            for dx in [CGFloat(-28), 28] {
                cg.fillEllipse(in: CGRect(x: 60 + dx - 8, y: 64, width: 16, height: 9))
            }
        }
    }

    private static func paperGrain(_ cg: CGContext, size: CGSize, rng: inout SplitMix64, amount: Int) {
        for _ in 0..<amount {
            let x = CGFloat(rng.nextUnit()) * size.width
            let y = CGFloat(rng.nextUnit()) * size.height
            let light = rng.nextUnit() < 0.5
            cg.setFillColor((light ? UIColor.white : UIColor.black).withAlphaComponent(0.05).cgColor)
            cg.fill(CGRect(x: x, y: y, width: 1.2, height: 1.2))
        }
    }
}

/// Yüksekliğe göre değişen gökyüzü bandı: sabah, öğle, gün batımı, alacakaranlık, gece, uzay.
private struct SkyBand {
    let height: Double
    let top: WatercolorPainter.RGB
    let bottom: WatercolorPainter.RGB
    let cloudTint: WatercolorPainter.RGB
    let sun: Double
    let stars: Double
}

/// Canlı çizgi film dünyası: kamera alanında (ekran noktası), katman katman parallax.
/// Katmanlar (uzaktan yakına): gökyüzü → yıldızlar → güneş/ay → şehir → uzak bulutlar → kuşlar/zeplin → yakın bulutlar.
final class CartoonWorldBackground: SKNode {
    private typealias RGB = WatercolorPainter.RGB

    private static let bands: [SkyBand] = [
        SkyBand(height: 0, top: RGB(r: 0.45, g: 0.78, b: 0.92), bottom: RGB(r: 0.99, g: 0.90, b: 0.70),
                cloudTint: RGB(r: 1, g: 0.95, b: 0.85), sun: 1, stars: 0),
        SkyBand(height: 12_000, top: RGB(r: 0.32, g: 0.70, b: 0.92), bottom: RGB(r: 0.80, g: 0.93, b: 0.95),
                cloudTint: RGB(r: 0.95, g: 0.97, b: 1), sun: 1, stars: 0),
        SkyBand(height: 30_000, top: RGB(r: 0.55, g: 0.45, b: 0.75), bottom: RGB(r: 1.0, g: 0.62, b: 0.42),
                cloudTint: RGB(r: 1, g: 0.75, b: 0.65), sun: 0.8, stars: 0),
        SkyBand(height: 50_000, top: RGB(r: 0.22, g: 0.20, b: 0.45), bottom: RGB(r: 0.75, g: 0.42, b: 0.55),
                cloudTint: RGB(r: 0.80, g: 0.62, b: 0.75), sun: 0, stars: 0.5),
        SkyBand(height: 72_000, top: RGB(r: 0.07, g: 0.08, b: 0.22), bottom: RGB(r: 0.20, g: 0.24, b: 0.45),
                cloudTint: RGB(r: 0.55, g: 0.60, b: 0.80), sun: 0, stars: 1),
        SkyBand(height: 100_000, top: RGB(r: 0.03, g: 0.02, b: 0.10), bottom: RGB(r: 0.12, g: 0.08, b: 0.28),
                cloudTint: RGB(r: 0.45, g: 0.40, b: 0.70), sun: 0, stars: 1),
    ]

    private let skyA = SKSpriteNode()
    private let skyB = SKSpriteNode()
    private var skyTextures: [SKTexture] = []
    private let stars = SKNode()
    /// Yıldızların ekran boyutuna göre birim konumları (-0.5...0.5).
    private var starUnits: [CGPoint] = []
    private let sun = SKSpriteNode()
    private let sunRays = SKShapeNode()
    private let moon = SKShapeNode(circleOfRadius: 38)
    private let skyline = SKSpriteNode()
    private var farClouds: [SKSpriteNode] = []
    private var nearClouds: [SKSpriteNode] = []
    private var cloudTextures: [SKTexture] = []
    private let birds = SKNode()
    private let blimp = SKNode()
    private var viewSize = CGSize(width: 390, height: 844)
    private var time: Double = 0
    private var currentBandTint = RGB(r: 1, g: 1, b: 1)

    override init() {
        super.init()
        skyTextures = Self.bands.enumerated().map { index, band in
            SKTexture(image: WatercolorPainter.sky(top: band.top, bottom: band.bottom, seed: UInt64(100 + index)))
        }
        for texture in skyTextures { texture.filteringMode = .linear }
        skyA.texture = skyTextures[0]
        skyB.texture = skyTextures[1]
        skyB.alpha = 0
        addChild(skyA)
        addChild(skyB)

        var rng = SplitMix64(seed: 77)
        for _ in 0..<70 {
            let star = SKShapeNode(circleOfRadius: 1 + CGFloat(rng.nextUnit()) * 1.6)
            star.fillColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
            star.strokeColor = .clear
            starUnits.append(CGPoint(x: CGFloat(rng.nextUnit() - 0.5), y: CGFloat(rng.nextUnit() - 0.5)))
            stars.addChild(star)
        }
        addChild(stars)

        sunRays.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.7)
        sunRays.lineWidth = 6
        sunRays.lineCap = .round
        let rays = CGMutablePath()
        for index in 0..<12 {
            let angle = CGFloat(index) * .pi / 6
            rays.move(to: CGPoint(x: cos(angle) * 66, y: sin(angle) * 66))
            rays.addLine(to: CGPoint(x: cos(angle) * 92, y: sin(angle) * 92))
        }
        sunRays.path = rays
        addChild(sunRays)
        sun.texture = SKTexture(image: WatercolorPainter.sun(color: RGB(r: 1, g: 0.82, b: 0.32)))
        sun.size = CGSize(width: 120, height: 120)
        addChild(sun)
        moon.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.82, alpha: 1)
        moon.strokeColor = Palette.ink
        moon.lineWidth = 3
        addChild(moon)

        skyline.texture = SKTexture(image: WatercolorPainter.skyline(
            seed: 5, wash: RGB(r: 0.55, g: 0.62, b: 0.78), window: RGB(r: 1, g: 0.88, b: 0.5)))
        skyline.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(skyline)

        cloudTextures = (0..<6).map { index in
            SKTexture(image: WatercolorPainter.cloud(seed: UInt64(200 + index), tint: RGB(r: 1, g: 0.95, b: 0.85), withFace: index % 3 == 0))
        }
        for index in 0..<5 {
            let cloud = SKSpriteNode(texture: cloudTextures[index % cloudTextures.count])
            cloud.size = CGSize(width: 120, height: 66)
            cloud.alpha = 0.8
            farClouds.append(cloud)
            addChild(cloud)
        }
        addChild(birds)
        addChild(blimp)
        buildBlimp()
        for index in 0..<4 {
            let cloud = SKSpriteNode(texture: cloudTextures[(index + 2) % cloudTextures.count])
            cloud.size = CGSize(width: 200, height: 110)
            nearClouds.append(cloud)
            addChild(cloud)
        }
        for _ in 0..<3 {
            let bird = SKShapeNode()
            bird.strokeColor = Palette.ink
            bird.lineWidth = 2.5
            bird.lineCap = .round
            birds.addChild(bird)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize) {
        viewSize = size
        for sky in [skyA, skyB] {
            sky.size = size
            sky.position = .zero
        }
        for (index, star) in stars.children.enumerated() where index < starUnits.count {
            star.position = CGPoint(x: starUnits[index].x * size.width, y: starUnits[index].y * size.height)
        }
        skyline.size = CGSize(width: size.width * 1.4, height: size.width * 1.4 * 220 / 400)
    }

    /// Her karede: kamera yüksekliğine göre katmanları yerleştir. `step`: 12 fps sayaç.
    func update(cameraY: Double, dt: Double, step: Int) {
        time += dt
        let w = viewSize.width
        let h = viewSize.height

        // Gökyüzü bandı ve geçişi
        let bands = Self.bands
        var index = 0
        while index < bands.count - 1 && cameraY >= bands[index + 1].height { index += 1 }
        let next = min(index + 1, bands.count - 1)
        let span = max(1, bands[next].height - bands[index].height)
        let t = index == next ? 0 : CGFloat(min(1, max(0, (cameraY - bands[index].height) / span)))
        if skyA.texture !== skyTextures[index] { skyA.texture = skyTextures[index] }
        if skyB.texture !== skyTextures[next] { skyB.texture = skyTextures[next] }
        skyB.alpha = t
        let sunAmount = CGFloat(bands[index].sun) * (1 - t) + CGFloat(bands[next].sun) * t
        let starAmount = CGFloat(bands[index].stars) * (1 - t) + CGFloat(bands[next].stars) * t
        currentBandTint = bands[index].cloudTint.mix(bands[next].cloudTint, t)

        // Güneş: yavaşça "batar"; ışınlar 12 fps'te kesik kesik döner.
        let sunY = h * 0.3 - CGFloat(cameraY.truncatingRemainder(dividingBy: 30_000)) * 0.004
        sun.position = CGPoint(x: w * 0.27, y: sunY)
        sun.alpha = sunAmount
        sunRays.position = sun.position
        sunRays.alpha = sunAmount
        sunRays.zRotation = CGFloat(step % 24) * (.pi / 72)
        sun.setScale(step % 4 < 2 ? 1 : 1.03)
        moon.position = CGPoint(x: w * 0.3, y: h * 0.3)
        moon.alpha = max(0, starAmount - 0.2)
        stars.alpha = starAmount
        for (offset, star) in stars.children.enumerated() {
            star.alpha = (step + offset) % 7 == 0 ? 0.4 : 1
        }

        // Uzak şehir: yalnızca alçakta; yükseldikçe aşağı kayıp kaybolur.
        skyline.position = CGPoint(x: 0, y: -h / 2 - CGFloat(cameraY) * 0.12 + 40)
        skyline.isHidden = skyline.position.y + skyline.size.height < -h / 2

        // Bulutlar: iki katman, farklı parallax ve yatay sürüklenme.
        let tint = currentBandTint.color()
        layoutClouds(farClouds, parallax: 0.05, drift: 6, band: h * 1.6, cameraY: cameraY, tint: tint, seed: 3)
        layoutClouds(nearClouds, parallax: 0.22, drift: 14, band: h * 2.2, cameraY: cameraY, tint: tint, seed: 9)

        // Kuşlar: alçakta, iki kareli kanat çırpma.
        birds.isHidden = cameraY > 40_000
        for (offset, node) in birds.children.enumerated() {
            guard let bird = node as? SKShapeNode else { continue }
            let up = (step + offset) % 2 == 0
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: up ? 5 : -2))
            path.addQuadCurve(to: .zero, control: CGPoint(x: -4, y: up ? 7 : 1))
            path.addQuadCurve(to: CGPoint(x: 9, y: up ? 5 : -2), control: CGPoint(x: 4, y: up ? 7 : 1))
            bird.path = path
            let lane = CGFloat(offset) * 0.18
            let x = CGFloat((time * 22 + Double(offset) * 140).truncatingRemainder(dividingBy: Double(w + 80))) - w / 2 - 40
            bird.position = CGPoint(x: x, y: h * (0.18 + lane) + CGFloat(sin(time * 2 + Double(offset))) * 6)
        }

        // Zeplin: ara sıra ekranı boydan boya geçer.
        let blimpCycle = (time / 38).truncatingRemainder(dividingBy: 1)
        blimp.position = CGPoint(x: -w / 2 - 120 + CGFloat(blimpCycle) * (w + 240), y: h * 0.05)
        blimp.isHidden = cameraY > 60_000
    }

    private func layoutClouds(_ clouds: [SKSpriteNode], parallax: Double, drift: Double, band: CGFloat,
                              cameraY: Double, tint: UIColor, seed: UInt64) {
        let w = viewSize.width
        var rng = SplitMix64(seed: seed)
        for (index, cloud) in clouds.enumerated() {
            let baseY = CGFloat(rng.nextUnit()) * band
            let baseX = CGFloat(rng.nextUnit()) * (w + 200)
            var y = (baseY - CGFloat(cameraY * parallax)).truncatingRemainder(dividingBy: band)
            if y < 0 { y += band }
            var x = (baseX + CGFloat(time * drift * (index % 2 == 0 ? 1 : 0.7))).truncatingRemainder(dividingBy: w + 200)
            if x < 0 { x += w + 200 }
            cloud.position = CGPoint(x: x - w / 2 - 100, y: y - band / 2)
            cloud.color = tint
            cloud.colorBlendFactor = 0.35
        }
    }

    private func buildBlimp() {
        let body = SKShapeNode(ellipseOf: CGSize(width: 120, height: 44))
        body.fillColor = UIColor(red: 0.85, green: 0.30, blue: 0.24, alpha: 1)
        body.strokeColor = Palette.ink
        body.lineWidth = 3
        blimp.addChild(body)
        let stripe = SKShapeNode(rectOf: CGSize(width: 74, height: 14), cornerRadius: 4)
        stripe.fillColor = Palette.cream
        stripe.strokeColor = Palette.ink
        stripe.lineWidth = 2
        blimp.addChild(stripe)
        let label = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
        label.text = "TOPCUP"
        label.fontSize = 11
        label.fontColor = Palette.ink
        label.verticalAlignmentMode = .center
        blimp.addChild(label)
        let gondola = SKShapeNode(rectOf: CGSize(width: 26, height: 10), cornerRadius: 3)
        gondola.fillColor = Palette.cream
        gondola.strokeColor = Palette.ink
        gondola.lineWidth = 2
        gondola.position = CGPoint(x: 0, y: -28)
        blimp.addChild(gondola)
        let fin = SKShapeNode()
        let finPath = CGMutablePath()
        finPath.addLines(between: [CGPoint(x: -52, y: 0), CGPoint(x: -72, y: 18), CGPoint(x: -72, y: -18)])
        finPath.closeSubpath()
        fin.path = finPath
        fin.fillColor = body.fillColor
        fin.strokeColor = Palette.ink
        fin.lineWidth = 3
        blimp.addChild(fin)
        blimp.setScale(0.6)
        blimp.alpha = 0.9
    }
}
