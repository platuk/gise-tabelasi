import SpriteKit
import UIKit
import GameCore

// MARK: - Dünya manzaraları

extension WatercolorPainter {
    /// Dünyaya göre ufuk manzarası (400×220, alt kenar yere oturur).
    static func scenery(_ theme: WorldTheme) -> UIImage {
        switch theme {
        case .city:
            return skyline(seed: 5, wash: RGB(r: 0.55, g: 0.62, b: 0.78), window: RGB(r: 1, g: 0.88, b: 0.5))
        case .harbor: return harbor()
        case .garden: return garden()
        case .haunted: return haunted()
        case .space: return spaceSurface()
        case .factory: return factory()
        }
    }

    private static func render(seed: UInt64, _ draw: (CGContext, CGSize, inout SplitMix64) -> Void) -> UIImage {
        let size = CGSize(width: 400, height: 220)
        var rng = SplitMix64(seed: seed)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            draw(cg, size, &rng)
            paperGrain(cg, size: size, rng: &rng, amount: 300)
        }
    }

    private static func outline(_ cg: CGContext, _ width: CGFloat = 2.5) {
        cg.setStrokeColor(ink.color().cgColor)
        cg.setLineWidth(width)
    }

    /// Liman: alçak şehir, deniz, deniz feneri, dumanlı gemiler, iskele.
    private static func harbor() -> UIImage {
        render(seed: 11) { cg, size, rng in
            let wash = RGB(r: 0.58, g: 0.66, b: 0.80)
            var x: CGFloat = -10
            while x < size.width {
                let w = 26 + CGFloat(rng.nextUnit()) * 30
                let h = 40 + CGFloat(rng.nextUnit()) * 60
                cg.setFillColor(wash.mix(ink, CGFloat(rng.nextUnit()) * 0.15).color().cgColor)
                cg.fill(CGRect(x: x, y: 160 - h, width: w, height: h))
                x += w + 3
            }
            // Deniz ve dalgalar
            cg.setFillColor(RGB(r: 0.28, g: 0.50, b: 0.70).color().cgColor)
            cg.fill(CGRect(x: 0, y: 160, width: size.width, height: 60))
            cg.setLineWidth(2)
            cg.setStrokeColor(RGB(r: 0.95, g: 0.95, b: 0.90).color(0.8).cgColor)
            for row in 0..<3 {
                let y = 170 + CGFloat(row) * 16
                var wx = CGFloat(row % 2) * 12
                while wx < size.width {
                    cg.move(to: CGPoint(x: wx, y: y))
                    cg.addQuadCurve(to: CGPoint(x: wx + 24, y: y), control: CGPoint(x: wx + 12, y: y - 7))
                    wx += 30
                }
            }
            cg.strokePath()
            // İskele
            cg.setFillColor(RGB(r: 0.45, g: 0.32, b: 0.22).color().cgColor)
            cg.fill(CGRect(x: 0, y: 156, width: 150, height: 7))
            var px: CGFloat = 8
            while px < 150 {
                cg.fill(CGRect(x: px, y: 156, width: 4, height: 30))
                px += 22
            }
            // Gemiler: gövde, köşk, iki baca
            let ships: [(CGFloat, CGFloat)] = [(170, 1), (40, 0.7)]
            for (sx, scale) in ships {
                cg.setFillColor(RGB(r: 0.20, g: 0.18, b: 0.20).color().cgColor)
                cg.move(to: CGPoint(x: sx, y: 150))
                cg.addLine(to: CGPoint(x: sx + 90 * scale, y: 150))
                cg.addLine(to: CGPoint(x: sx + 80 * scale, y: 150 + 16 * scale))
                cg.addLine(to: CGPoint(x: sx + 6 * scale, y: 150 + 16 * scale))
                cg.fillPath()
                cg.setFillColor(RGB(r: 0.95, g: 0.92, b: 0.85).color().cgColor)
                cg.fill(CGRect(x: sx + 20 * scale, y: 150 - 10 * scale, width: 44 * scale, height: 10 * scale))
                cg.setFillColor(RGB(r: 0.80, g: 0.25, b: 0.20).color().cgColor)
                cg.fill(CGRect(x: sx + 30 * scale, y: 150 - 28 * scale, width: 8 * scale, height: 18 * scale))
                cg.fill(CGRect(x: sx + 48 * scale, y: 150 - 28 * scale, width: 8 * scale, height: 18 * scale))
            }
            // Deniz feneri: kırmızı-beyaz bantlı, daralan kule
            let baseX: CGFloat = 345
            let baseY: CGFloat = 160
            for index in 0..<6 {
                let t0 = CGFloat(index) / 6
                let t1 = CGFloat(index + 1) / 6
                let half0 = 16 - t0 * 7
                let half1 = 16 - t1 * 7
                let color = index % 2 == 0 ? RGB(r: 0.95, g: 0.93, b: 0.88) : RGB(r: 0.82, g: 0.22, b: 0.18)
                cg.setFillColor(color.color().cgColor)
                cg.move(to: CGPoint(x: baseX - half0, y: baseY - t0 * 110))
                cg.addLine(to: CGPoint(x: baseX + half0, y: baseY - t0 * 110))
                cg.addLine(to: CGPoint(x: baseX + half1, y: baseY - t1 * 110))
                cg.addLine(to: CGPoint(x: baseX - half1, y: baseY - t1 * 110))
                cg.fillPath()
            }
            cg.setFillColor(RGB(r: 1, g: 0.85, b: 0.4).color().cgColor)
            cg.fill(CGRect(x: baseX - 8, y: baseY - 124, width: 16, height: 14))
            cg.setFillColor(ink.color().cgColor)
            cg.fill(CGRect(x: baseX - 11, y: baseY - 130, width: 22, height: 6))
            outline(cg)
            cg.stroke(CGRect(x: baseX - 8, y: baseY - 124, width: 16, height: 14))
        }
    }

    /// Bahçe: üç kat tepe, ambar, yel değirmeni, yuvarlak ağaçlar, çit.
    private static func garden() -> UIImage {
        render(seed: 12) { cg, size, rng in
            let hills: [(RGB, CGFloat)] = [
                (RGB(r: 0.55, g: 0.72, b: 0.55), 110),
                (RGB(r: 0.45, g: 0.66, b: 0.38), 140),
                (RGB(r: 0.36, g: 0.58, b: 0.30), 170),
            ]
            for (index, hill) in hills.enumerated() {
                cg.setFillColor(hill.0.color().cgColor)
                cg.move(to: CGPoint(x: 0, y: size.height))
                cg.addLine(to: CGPoint(x: 0, y: hill.1))
                var x: CGFloat = 0
                while x < size.width {
                    let next = x + 80 + CGFloat(rng.nextUnit()) * 60
                    cg.addQuadCurve(to: CGPoint(x: next, y: hill.1 + CGFloat(rng.nextUnit()) * 14),
                                    control: CGPoint(x: (x + next) / 2, y: hill.1 - 34 + CGFloat(index) * 6))
                    x = next
                }
                cg.addLine(to: CGPoint(x: size.width + 140, y: size.height))
                cg.closePath()
                cg.fillPath()
            }
            // Ambar
            let barn = CGRect(x: 250, y: 120, width: 56, height: 42)
            cg.setFillColor(RGB(r: 0.78, g: 0.22, b: 0.18).color().cgColor)
            cg.fill(barn)
            cg.move(to: CGPoint(x: barn.minX - 6, y: barn.minY))
            cg.addLine(to: CGPoint(x: barn.midX, y: barn.minY - 26))
            cg.addLine(to: CGPoint(x: barn.maxX + 6, y: barn.minY))
            cg.fillPath()
            outline(cg, 2)
            cg.stroke(barn)
            let door = CGRect(x: barn.midX - 11, y: barn.maxY - 24, width: 22, height: 24)
            cg.setStrokeColor(RGB(r: 0.97, g: 0.95, b: 0.90).color().cgColor)
            cg.stroke(door)
            cg.move(to: CGPoint(x: door.minX, y: door.minY))
            cg.addLine(to: CGPoint(x: door.maxX, y: door.maxY))
            cg.move(to: CGPoint(x: door.maxX, y: door.minY))
            cg.addLine(to: CGPoint(x: door.minX, y: door.maxY))
            cg.strokePath()
            // Yel değirmeni
            let mill = CGPoint(x: 90, y: 100)
            cg.setFillColor(RGB(r: 0.92, g: 0.88, b: 0.78).color().cgColor)
            cg.move(to: CGPoint(x: mill.x - 12, y: 150))
            cg.addLine(to: CGPoint(x: mill.x - 7, y: mill.y))
            cg.addLine(to: CGPoint(x: mill.x + 7, y: mill.y))
            cg.addLine(to: CGPoint(x: mill.x + 12, y: 150))
            cg.fillPath()
            outline(cg, 2.5)
            for index in 0..<4 {
                let a = CGFloat(index) * .pi / 2 + 0.4
                cg.move(to: mill)
                cg.addLine(to: CGPoint(x: mill.x + cos(a) * 34, y: mill.y + sin(a) * 34))
            }
            cg.strokePath()
            // Ağaçlar
            let trees: [CGFloat] = [30, 170, 215, 360]
            for tx in trees {
                let ty: CGFloat = 140 + CGFloat(rng.nextUnit()) * 10
                cg.setFillColor(RGB(r: 0.45, g: 0.30, b: 0.18).color().cgColor)
                cg.fill(CGRect(x: tx - 3, y: ty, width: 6, height: 20))
                let crown = CGRect(x: tx - 16, y: ty - 26, width: 32, height: 30)
                cg.setFillColor(RGB(r: 0.30, g: 0.55, b: 0.28).color().cgColor)
                cg.fillEllipse(in: crown)
                outline(cg, 2)
                cg.strokeEllipse(in: crown)
            }
            // Çit
            cg.setStrokeColor(RGB(r: 0.97, g: 0.95, b: 0.88).color().cgColor)
            cg.setLineWidth(3)
            cg.move(to: CGPoint(x: 0, y: 190))
            cg.addLine(to: CGPoint(x: size.width, y: 190))
            var fx: CGFloat = 6
            while fx < size.width {
                cg.move(to: CGPoint(x: fx, y: 182))
                cg.addLine(to: CGPoint(x: fx, y: 204))
                fx += 18
            }
            cg.strokePath()
        }
    }

    /// Perili şato: mor tepe, sivri kuleli şato, yanan pencereler, kuru ağaçlar, mezar taşları.
    private static func haunted() -> UIImage {
        render(seed: 13) { cg, size, rng in
            cg.setFillColor(RGB(r: 0.30, g: 0.24, b: 0.38).color().cgColor)
            cg.move(to: CGPoint(x: 0, y: size.height))
            cg.addLine(to: CGPoint(x: 0, y: 150))
            cg.addQuadCurve(to: CGPoint(x: size.width, y: 140), control: CGPoint(x: 220, y: 80))
            cg.addLine(to: CGPoint(x: size.width, y: size.height))
            cg.fillPath()
            // Şato
            cg.setFillColor(RGB(r: 0.20, g: 0.16, b: 0.26).color().cgColor)
            cg.fill(CGRect(x: 180, y: 70, width: 90, height: 60))
            let towers: [(CGFloat, CGFloat)] = [(170, 80), (262, 90), (214, 110)]
            for (tx, th) in towers {
                cg.fill(CGRect(x: tx, y: 130 - th, width: 20, height: th))
                cg.move(to: CGPoint(x: tx - 4, y: 130 - th))
                cg.addLine(to: CGPoint(x: tx + 10, y: 130 - th - 26))
                cg.addLine(to: CGPoint(x: tx + 24, y: 130 - th))
                cg.fillPath()
            }
            cg.setFillColor(RGB(r: 1, g: 0.85, b: 0.35).color().cgColor)
            for _ in 0..<9 {
                let wx = 182 + CGFloat(rng.nextUnit()) * 90
                let wy = 50 + CGFloat(rng.nextUnit()) * 70
                cg.fill(CGRect(x: wx, y: wy, width: 4, height: 7))
            }
            // Kuru ağaçlar
            outline(cg, 3)
            let trees: [(CGFloat, CGFloat)] = [(60, 170), (340, 160)]
            for (tx, ty) in trees {
                cg.move(to: CGPoint(x: tx, y: ty + 40))
                cg.addLine(to: CGPoint(x: tx, y: ty - 20))
                cg.move(to: CGPoint(x: tx, y: ty))
                cg.addLine(to: CGPoint(x: tx - 20, y: ty - 18))
                cg.move(to: CGPoint(x: tx, y: ty - 8))
                cg.addLine(to: CGPoint(x: tx + 18, y: ty - 26))
                cg.move(to: CGPoint(x: tx - 12, y: ty - 10))
                cg.addLine(to: CGPoint(x: tx - 16, y: ty - 30))
            }
            cg.strokePath()
            // Mezar taşları
            let stones: [CGFloat] = [110, 135, 300]
            for gx in stones {
                let path = CGPath(roundedRect: CGRect(x: gx, y: 178, width: 14, height: 20), cornerWidth: 6, cornerHeight: 6, transform: nil)
                cg.setFillColor(RGB(r: 0.62, g: 0.60, b: 0.66).color().cgColor)
                cg.addPath(path)
                cg.fillPath()
                outline(cg, 1.8)
                cg.addPath(path)
                cg.strokePath()
            }
        }
    }

    /// Uzay: halkalı gezegen, kraterli yüzey, cam kubbeler, anten kuleleri.
    private static func spaceSurface() -> UIImage {
        render(seed: 14) { cg, size, rng in
            let planet = CGRect(x: 280, y: 10, width: 70, height: 70)
            cg.setFillColor(RGB(r: 0.90, g: 0.60, b: 0.45).color().cgColor)
            cg.fillEllipse(in: planet)
            outline(cg, 2.5)
            cg.strokeEllipse(in: planet)
            cg.setStrokeColor(RGB(r: 0.95, g: 0.85, b: 0.60).color().cgColor)
            cg.setLineWidth(5)
            cg.strokeEllipse(in: CGRect(x: planet.minX - 22, y: planet.midY - 9, width: planet.width + 44, height: 18))
            // Yüzey
            cg.setFillColor(RGB(r: 0.55, g: 0.52, b: 0.66).color().cgColor)
            cg.move(to: CGPoint(x: 0, y: size.height))
            cg.addLine(to: CGPoint(x: 0, y: 150))
            cg.addQuadCurve(to: CGPoint(x: size.width, y: 150), control: CGPoint(x: size.width / 2, y: 118))
            cg.addLine(to: CGPoint(x: size.width, y: size.height))
            cg.fillPath()
            cg.setFillColor(RGB(r: 0.42, g: 0.40, b: 0.52).color().cgColor)
            for _ in 0..<7 {
                let cx = CGFloat(rng.nextUnit()) * size.width
                let cy = 160 + CGFloat(rng.nextUnit()) * 50
                let r = 6 + CGFloat(rng.nextUnit()) * 12
                cg.fillEllipse(in: CGRect(x: cx - r, y: cy - r * 0.4, width: r * 2, height: r * 0.8))
            }
            // Kubbeler
            let domes: [(CGFloat, CGFloat)] = [(90, 26), (150, 16), (320, 22)]
            for (dx, r) in domes {
                let rect = CGRect(x: dx - r, y: 146 - r, width: r * 2, height: r * 2)
                cg.setFillColor(RGB(r: 0.70, g: 0.90, b: 0.95).color(0.75).cgColor)
                cg.fillEllipse(in: rect)
                outline(cg, 2)
                cg.strokeEllipse(in: rect)
                cg.setFillColor(RGB(r: 0.55, g: 0.52, b: 0.66).color().cgColor)
                cg.fill(CGRect(x: rect.minX - 2, y: rect.midY, width: rect.width + 4, height: r + 2))
                cg.setFillColor(RGB(r: 1, g: 0.9, b: 0.4).color().cgColor)
                cg.fill(CGRect(x: dx - 3, y: rect.midY - 8, width: 6, height: 6))
            }
            // Antenler
            outline(cg, 2.5)
            let antennas: [CGFloat] = [220, 250]
            for ax in antennas {
                cg.move(to: CGPoint(x: ax, y: 140))
                cg.addLine(to: CGPoint(x: ax, y: 90))
                cg.move(to: CGPoint(x: ax - 10, y: 100))
                cg.addLine(to: CGPoint(x: ax + 10, y: 100))
            }
            cg.strokePath()
            cg.setFillColor(RGB(r: 1, g: 0.35, b: 0.30).color().cgColor)
            for ax in antennas {
                cg.fillEllipse(in: CGRect(x: ax - 4, y: 84, width: 8, height: 8))
            }
        }
    }

    /// Fabrika: testere dişi çatılar, bantlı bacalar, su kulesi, vinç.
    private static func factory() -> UIImage {
        render(seed: 15) { cg, size, rng in
            cg.setFillColor(RGB(r: 0.48, g: 0.42, b: 0.40).color().cgColor)
            cg.fill(CGRect(x: 0, y: 140, width: size.width, height: 80))
            var x: CGFloat = 0
            while x < size.width {
                cg.move(to: CGPoint(x: x, y: 140))
                cg.addLine(to: CGPoint(x: x, y: 118))
                cg.addLine(to: CGPoint(x: x + 34, y: 140))
                cg.fillPath()
                x += 34
            }
            cg.setFillColor(RGB(r: 1, g: 0.80, b: 0.40).color(0.8).cgColor)
            for _ in 0..<14 {
                cg.fill(CGRect(x: CGFloat(rng.nextUnit()) * size.width, y: 150 + CGFloat(rng.nextUnit()) * 40, width: 6, height: 8))
            }
            let chimneys: [(CGFloat, CGFloat)] = [(60, 120), (110, 90), (300, 130)]
            for (cx, ch) in chimneys {
                cg.setFillColor(RGB(r: 0.60, g: 0.28, b: 0.22).color().cgColor)
                cg.fill(CGRect(x: cx, y: 140 - ch, width: 18, height: ch))
                cg.setFillColor(RGB(r: 0.95, g: 0.92, b: 0.86).color().cgColor)
                cg.fill(CGRect(x: cx, y: 140 - ch + 8, width: 18, height: 6))
                cg.fill(CGRect(x: cx, y: 140 - ch + 24, width: 18, height: 6))
                outline(cg, 2)
                cg.stroke(CGRect(x: cx, y: 140 - ch, width: 18, height: ch))
            }
            // Su kulesi
            let tank = CGRect(x: 200, y: 60, width: 44, height: 32)
            cg.setFillColor(RGB(r: 0.55, g: 0.45, b: 0.35).color().cgColor)
            cg.fill(tank)
            outline(cg, 2)
            cg.stroke(tank)
            cg.move(to: CGPoint(x: tank.minX + 4, y: tank.maxY))
            cg.addLine(to: CGPoint(x: tank.minX - 2, y: 140))
            cg.move(to: CGPoint(x: tank.maxX - 4, y: tank.maxY))
            cg.addLine(to: CGPoint(x: tank.maxX + 2, y: 140))
            cg.move(to: CGPoint(x: tank.minX, y: 115))
            cg.addLine(to: CGPoint(x: tank.maxX, y: 115))
            cg.move(to: CGPoint(x: tank.minX - 4, y: tank.minY))
            cg.addLine(to: CGPoint(x: tank.midX, y: tank.minY - 14))
            cg.addLine(to: CGPoint(x: tank.maxX + 4, y: tank.minY))
            cg.strokePath()
            // Vinç
            outline(cg, 3)
            cg.move(to: CGPoint(x: 360, y: 140))
            cg.addLine(to: CGPoint(x: 360, y: 40))
            cg.addLine(to: CGPoint(x: 260, y: 40))
            cg.move(to: CGPoint(x: 290, y: 40))
            cg.addLine(to: CGPoint(x: 290, y: 70))
            cg.strokePath()
        }
    }
}

// MARK: - Arka plan

/// Yüksekliğe göre değişen gökyüzü bandı: sabah, öğle, gün batımı, alacakaranlık, gece, gece yarısı.
private struct SkyBand {
    let height: Double
    let top: WatercolorPainter.RGB
    let bottom: WatercolorPainter.RGB
    let cloudTint: WatercolorPainter.RGB
    let sun: Double
    let stars: Double
}

/// Canlı çizgi film dünyası: kamera alanında (ekran noktası), katman katman parallax.
/// Katmanlar (uzaktan yakına): gökyüzü → dünya rengi → yıldızlar → güneş/ay → dünya manzarası → uzak bulutlar
/// → uçanlar (martı, kelebek, yarasa, kayan yıldız, duman, kuş) → büyük gezgin (zeplin, balon, hayalet, roket, çift kanatlı)
/// → yakın bulutlar.
/// Her bölümün dünyası farklıdır (liman, bahçe, perili şato, uzay, fabrika, şehir); her bölümde gökyüzü sabahtan geceye döner.
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

    private static let config = TowerConfig()

    private let skyA = SKSpriteNode()
    private let skyB = SKSpriteNode()
    private var skyTextures: [SKTexture] = []
    private let themeTint = SKSpriteNode(color: .clear, size: .zero)
    private let stars = SKNode()
    private var starUnits: [CGPoint] = []
    private let sun = SKSpriteNode()
    private let sunRays = SKShapeNode()
    private let moon = SKShapeNode(circleOfRadius: 38)
    private let scenery = SKSpriteNode()
    private var sceneryTextures: [WorldTheme: SKTexture] = [:]
    private var farClouds: [SKSpriteNode] = []
    private var nearClouds: [SKSpriteNode] = []
    private var cloudTextures: [SKTexture] = []
    private let flyers = SKNode()
    private var cruisers: [WorldTheme: SKNode] = [:]
    private var viewSize = CGSize(width: 390, height: 844)
    private var time: Double = 0
    private var currentBandTint = RGB(r: 1, g: 1, b: 1)
    private var theme: WorldTheme?

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
        addChild(themeTint)

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

        scenery.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(scenery)

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
        addChild(flyers)
        for _ in 0..<4 {
            let flyer = SKShapeNode()
            flyer.strokeColor = Palette.ink
            flyer.lineWidth = 2.2
            flyer.lineCap = .round
            flyer.lineJoin = .round
            flyers.addChild(flyer)
        }
        for kind in WorldTheme.allCases {
            let cruiser = Self.buildCruiser(kind)
            cruiser.isHidden = true
            cruisers[kind] = cruiser
            addChild(cruiser)
        }
        for index in 0..<4 {
            let cloud = SKSpriteNode(texture: cloudTextures[(index + 2) % cloudTextures.count])
            cloud.size = CGSize(width: 200, height: 110)
            nearClouds.append(cloud)
            addChild(cloud)
        }
    }

    required init?(coder aDecoder: NSCoder) { return nil }

    func layout(in size: CGSize) {
        viewSize = size
        for sky in [skyA, skyB] {
            sky.size = size
            sky.position = .zero
        }
        themeTint.size = size
        for (index, star) in stars.children.enumerated() where index < starUnits.count {
            star.position = CGPoint(x: starUnits[index].x * size.width, y: starUnits[index].y * size.height)
        }
        scenery.size = CGSize(width: size.width * 1.4, height: size.width * 1.4 * 220 / 400)
    }

    private func texture(for kind: WorldTheme) -> SKTexture {
        if let cached = sceneryTextures[kind] { return cached }
        let texture = SKTexture(image: WatercolorPainter.scenery(kind))
        sceneryTextures[kind] = texture
        return texture
    }

    /// Dünyanın rengi: gökyüzünü hafifçe boyar.
    private static func tint(_ kind: WorldTheme) -> (UIColor, CGFloat) {
        switch kind {
        case .harbor: return (UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1), 0.06)
        case .garden: return (UIColor(red: 0.6, green: 0.9, blue: 0.5, alpha: 1), 0.10)
        case .haunted: return (UIColor(red: 0.35, green: 0.22, blue: 0.50, alpha: 1), 0.32)
        case .space: return (UIColor(red: 0.05, green: 0.04, blue: 0.20, alpha: 1), 0.45)
        case .factory: return (UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1), 0.20)
        case .city: return (UIColor.white, 0)
        }
    }

    private func apply(_ newTheme: WorldTheme) {
        let first = theme == nil
        theme = newTheme
        let (color, alpha) = Self.tint(newTheme)
        themeTint.color = color
        themeTint.alpha = alpha
        for (key, cruiser) in cruisers { cruiser.isHidden = key != newTheme }
        let next = texture(for: newTheme)
        if first {
            scenery.texture = next
        } else {
            scenery.removeAllActions()
            scenery.run(.sequence([
                .fadeAlpha(to: 0, duration: 0.3),
                .run { [weak self] in self?.scenery.texture = next },
                .fadeAlpha(to: 1, duration: 0.4),
            ]))
        }
    }

    /// Her karede: kamera yüksekliğine göre katmanları yerleştir. `step`: 12 fps sayaç.
    func update(cameraY: Double, dt: Double, step: Int) {
        time += dt
        let w = viewSize.width
        let h = viewSize.height
        let config = Self.config
        let floor = Int(cameraY / config.floorSpacing)
        let current = WorldTheme.forFloor(floor, config: config)
        if current != theme { apply(current) }
        let chapterBase = Double(config.chapter(forFloor: max(0, floor - 1)) * config.chapterLength) * config.floorSpacing
        let local = max(0, cameraY - chapterBase)

        // Gökyüzü bandı: her bölümde sabahtan geceye.
        let bands = Self.bands
        let chapterHeight = Double(config.chapterLength) * config.floorSpacing
        let cycleY = min(1, local / chapterHeight) * bands[bands.count - 1].height
        var index = 0
        while index < bands.count - 1 && cycleY >= bands[index + 1].height { index += 1 }
        let next = min(index + 1, bands.count - 1)
        let span = max(1, bands[next].height - bands[index].height)
        let t = index == next ? 0 : CGFloat(min(1, max(0, (cycleY - bands[index].height) / span)))
        if skyA.texture !== skyTextures[index] { skyA.texture = skyTextures[index] }
        if skyB.texture !== skyTextures[next] { skyB.texture = skyTextures[next] }
        skyB.alpha = t
        var sunAmount = CGFloat(bands[index].sun) * (1 - t) + CGFloat(bands[next].sun) * t
        var starAmount = CGFloat(bands[index].stars) * (1 - t) + CGFloat(bands[next].stars) * t
        if current == .space {
            starAmount = 1
            sunAmount = 0
        } else if current == .haunted {
            starAmount = max(starAmount, 0.7)
            sunAmount = min(sunAmount, 0.2)
        }
        currentBandTint = bands[index].cloudTint.mix(bands[next].cloudTint, t)

        let sunY = h * 0.3 - CGFloat(cycleY.truncatingRemainder(dividingBy: 30_000)) * 0.004
        sun.position = CGPoint(x: w * 0.27, y: sunY)
        sun.alpha = sunAmount
        sunRays.position = sun.position
        sunRays.alpha = sunAmount
        sunRays.zRotation = CGFloat(step % 24) * (.pi / 72)
        sun.setScale(step % 4 < 2 ? 1 : 1.03)
        moon.position = CGPoint(x: w * 0.3, y: h * 0.3)
        moon.alpha = max(0, starAmount - 0.2)
        moon.fillColor = current == .haunted ? UIColor(red: 0.95, green: 0.92, blue: 0.60, alpha: 1)
            : UIColor(red: 0.98, green: 0.95, blue: 0.82, alpha: 1)
        moon.setScale(current == .haunted ? 1.6 : 1)
        stars.alpha = starAmount
        for (offset, star) in stars.children.enumerated() {
            star.alpha = (step + offset) % 7 == 0 ? 0.4 : 1
        }

        // Dünya manzarası: bölüm başında altta görünür, tırmandıkça aşağı kayıp kaybolur.
        scenery.position = CGPoint(x: 0, y: -h / 2 - CGFloat(local) * 0.12 + 40)
        scenery.isHidden = scenery.position.y + scenery.size.height < -h / 2

        // Bulutlar: uzayda yok, perili şatoda koyu.
        let cloudTint = current == .haunted ? UIColor(red: 0.55, green: 0.50, blue: 0.65, alpha: 1) : currentBandTint.color()
        for cloud in farClouds + nearClouds { cloud.isHidden = current == .space }
        layoutClouds(farClouds, parallax: 0.05, drift: 6, band: h * 1.6, cameraY: cameraY, tint: cloudTint, seed: 3)
        layoutClouds(nearClouds, parallax: 0.22, drift: 14, band: h * 2.2, cameraY: cameraY, tint: cloudTint, seed: 9)

        updateFlyers(current, step: step)

        // Büyük gezgin: ara sıra ekranı boydan boya geçer.
        if let cruiser = cruisers[current] {
            let cycle = (time / 38).truncatingRemainder(dividingBy: 1)
            cruiser.position = CGPoint(x: -w / 2 - 120 + CGFloat(cycle) * (w + 240), y: h * 0.05 + CGFloat(sin(time * 0.8)) * 10)
            if current == .haunted {
                cruiser.alpha = 0.55 + 0.25 * CGFloat(sin(time * 2))
            }
        }
    }

    /// Dünyaya göre uçanlar (12 fps çizim): martı/kuş, kelebek, yarasa, kayan yıldız, duman.
    private func updateFlyers(_ kind: WorldTheme, step: Int) {
        let w = viewSize.width
        let h = viewSize.height
        for (offset, child) in flyers.children.enumerated() {
            guard let flyer = child as? SKShapeNode else { continue }
            let up = (step + offset) % 2 == 0
            let path = CGMutablePath()
            var speed = 22.0
            var y = h * (0.12 + CGFloat(offset) * 0.14) + CGFloat(sin(time * 2 + Double(offset))) * 6
            var fixedX: CGFloat?
            flyer.fillColor = .clear
            flyer.strokeColor = Palette.ink
            flyer.isHidden = false
            switch kind {
            case .harbor, .city:
                path.move(to: CGPoint(x: -9, y: up ? 5 : -2))
                path.addQuadCurve(to: .zero, control: CGPoint(x: -4, y: up ? 7 : 1))
                path.addQuadCurve(to: CGPoint(x: 9, y: up ? 5 : -2), control: CGPoint(x: 4, y: up ? 7 : 1))
            case .garden:
                speed = 14
                let spread: CGFloat = up ? 7 : 3
                path.addEllipse(in: CGRect(x: -spread - 1, y: 0, width: spread, height: 8))
                path.addEllipse(in: CGRect(x: 1, y: 0, width: spread, height: 8))
                flyer.fillColor = offset % 2 == 0 ? UIColor(red: 1, green: 0.55, blue: 0.65, alpha: 1) : Palette.milestone
                y += CGFloat(sin(time * 5 + Double(offset))) * 8
            case .haunted:
                speed = 30
                let tip: CGFloat = up ? 6 : -4
                path.addLines(between: [CGPoint(x: -12, y: tip), CGPoint(x: -6, y: 0), CGPoint(x: -3, y: 3), CGPoint(x: 0, y: 0),
                                        CGPoint(x: 3, y: 3), CGPoint(x: 6, y: 0), CGPoint(x: 12, y: tip), CGPoint(x: 0, y: -4)])
                path.closeSubpath()
                flyer.fillColor = Palette.ink
            case .space:
                speed = 120
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: -34, y: 14))
                path.addEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
                flyer.strokeColor = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
                let fall = CGFloat((time * 40 + Double(offset) * 90).truncatingRemainder(dividingBy: Double(h)))
                y = h * (0.45 - CGFloat(offset) * 0.12) - fall
                flyer.isHidden = offset > 1
            case .factory:
                // Duman: alttan yükselen, büyüyen bulutçuklar.
                let rise = CGFloat((time * 30 + Double(offset) * 60).truncatingRemainder(dividingBy: Double(h * 0.6)))
                let r = 8 + rise * 0.06
                path.addEllipse(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 1.6))
                flyer.fillColor = UIColor(red: 0.85, green: 0.82, blue: 0.78, alpha: 0.85)
                y = -h * 0.35 + rise
                fixedX = -w * 0.35 + CGFloat(offset) * w * 0.22
            }
            flyer.path = path
            let x = CGFloat((time * speed + Double(offset) * 140).truncatingRemainder(dividingBy: Double(w + 80))) - w / 2 - 40
            flyer.position = CGPoint(x: fixedX ?? x, y: y)
        }
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

    // MARK: Büyük gezginler

    private static func shape(_ path: CGPath, fill: UIColor, width: CGFloat = 3) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = width > 0 ? Palette.ink : .clear
        node.lineWidth = width
        node.lineJoin = .round
        node.lineCap = .round
        return node
    }

    private static func buildCruiser(_ kind: WorldTheme) -> SKNode {
        let root = SKNode()
        switch kind {
        case .harbor, .city:
            // Zeplin
            let color = kind == .city ? UIColor(red: 0.85, green: 0.30, blue: 0.24, alpha: 1) : UIColor(red: 0.30, green: 0.50, blue: 0.70, alpha: 1)
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: -60, y: -22, width: 120, height: 44), transform: nil), fill: color))
            root.addChild(shape(CGPath(roundedRect: CGRect(x: -37, y: -7, width: 74, height: 14), cornerWidth: 4, cornerHeight: 4, transform: nil),
                                fill: Palette.cream, width: 2))
            let label = SKLabelNode(fontNamed: Palette.fontName)
            label.text = "CUPTOWER"
            label.fontSize = 11
            label.fontColor = Palette.ink
            label.verticalAlignmentMode = .center
            root.addChild(label)
            root.addChild(shape(CGPath(roundedRect: CGRect(x: -13, y: -33, width: 26, height: 10), cornerWidth: 3, cornerHeight: 3, transform: nil),
                                fill: Palette.cream, width: 2))
            let fin = CGMutablePath()
            fin.addLines(between: [CGPoint(x: -52, y: 0), CGPoint(x: -72, y: 18), CGPoint(x: -72, y: -18)])
            fin.closeSubpath()
            root.addChild(shape(fin, fill: color))
            root.setScale(0.6)
        case .garden:
            // Sıcak hava balonu
            let ropes = CGMutablePath()
            ropes.move(to: CGPoint(x: -22, y: -2))
            ropes.addLine(to: CGPoint(x: -9, y: -28))
            ropes.move(to: CGPoint(x: 22, y: -2))
            ropes.addLine(to: CGPoint(x: 9, y: -28))
            root.addChild(shape(ropes, fill: .clear, width: 2))
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: -34, y: -10, width: 68, height: 76), transform: nil),
                                fill: UIColor(red: 0.95, green: 0.45, blue: 0.30, alpha: 1)))
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: -14, y: -9, width: 28, height: 74), transform: nil), fill: Palette.milestone, width: 2))
            root.addChild(shape(CGPath(rect: CGRect(x: -10, y: -40, width: 20, height: 13), transform: nil),
                                fill: UIColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1), width: 2))
            root.setScale(0.7)
        case .haunted:
            // Hayalet: dalgalı etek, oyuk gözler
            let ghost = CGMutablePath()
            ghost.move(to: CGPoint(x: -24, y: -20))
            ghost.addLine(to: CGPoint(x: -24, y: 10))
            ghost.addArc(center: CGPoint(x: 0, y: 10), radius: 24, startAngle: .pi, endAngle: 0, clockwise: true)
            ghost.addLine(to: CGPoint(x: 24, y: -20))
            for index in 0..<4 {
                let x0 = 24 - CGFloat(index) * 12
                ghost.addQuadCurve(to: CGPoint(x: x0 - 12, y: -20), control: CGPoint(x: x0 - 6, y: index % 2 == 0 ? -30 : -12))
            }
            ghost.closeSubpath()
            root.addChild(shape(ghost, fill: UIColor(white: 0.97, alpha: 1)))
            let eyes = CGMutablePath()
            eyes.addEllipse(in: CGRect(x: -12, y: 6, width: 8, height: 12))
            eyes.addEllipse(in: CGRect(x: 4, y: 6, width: 8, height: 12))
            eyes.addEllipse(in: CGRect(x: -5, y: -8, width: 10, height: 8))
            root.addChild(shape(eyes, fill: Palette.ink, width: 0))
            root.setScale(0.9)
        case .space:
            // Roket
            let flame = CGMutablePath()
            flame.addLines(between: [CGPoint(x: -40, y: -8), CGPoint(x: -66, y: 0), CGPoint(x: -40, y: 8)])
            flame.closeSubpath()
            root.addChild(shape(flame, fill: Palette.flame, width: 2))
            root.addChild(shape(CGPath(roundedRect: CGRect(x: -42, y: -14, width: 70, height: 28), cornerWidth: 14, cornerHeight: 14, transform: nil),
                                fill: UIColor(red: 0.88, green: 0.88, blue: 0.92, alpha: 1)))
            let red = UIColor(red: 0.85, green: 0.22, blue: 0.18, alpha: 1)
            let nose = CGMutablePath()
            nose.addLines(between: [CGPoint(x: 26, y: -13), CGPoint(x: 50, y: 0), CGPoint(x: 26, y: 13)])
            nose.closeSubpath()
            root.addChild(shape(nose, fill: red))
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: 4, y: -6, width: 12, height: 12), transform: nil),
                                fill: UIColor(red: 0.60, green: 0.85, blue: 0.95, alpha: 1), width: 2))
            let fins = CGMutablePath()
            fins.addLines(between: [CGPoint(x: -34, y: 13), CGPoint(x: -46, y: 26), CGPoint(x: -22, y: 13)])
            fins.closeSubpath()
            fins.addLines(between: [CGPoint(x: -34, y: -13), CGPoint(x: -46, y: -26), CGPoint(x: -22, y: -13)])
            fins.closeSubpath()
            root.addChild(shape(fins, fill: red))
            root.setScale(0.65)
        case .factory:
            // Çift kanatlı uçak
            let wing = UIColor(red: 0.85, green: 0.70, blue: 0.30, alpha: 1)
            root.addChild(shape(CGPath(rect: CGRect(x: -20, y: 10, width: 40, height: 6), transform: nil), fill: wing, width: 2))
            root.addChild(shape(CGPath(roundedRect: CGRect(x: -36, y: -8, width: 66, height: 16), cornerWidth: 8, cornerHeight: 8, transform: nil),
                                fill: UIColor(red: 0.80, green: 0.25, blue: 0.20, alpha: 1)))
            root.addChild(shape(CGPath(rect: CGRect(x: -22, y: -16, width: 44, height: 6), transform: nil), fill: wing, width: 2))
            let struts = CGMutablePath()
            struts.move(to: CGPoint(x: -14, y: -10))
            struts.addLine(to: CGPoint(x: -14, y: 10))
            struts.move(to: CGPoint(x: 14, y: -10))
            struts.addLine(to: CGPoint(x: 14, y: 10))
            root.addChild(shape(struts, fill: .clear, width: 2))
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: -6, y: 6, width: 10, height: 10), transform: nil),
                                fill: UIColor(red: 0.99, green: 0.86, blue: 0.70, alpha: 1), width: 1.8))
            root.addChild(shape(CGPath(ellipseIn: CGRect(x: 30, y: -14, width: 5, height: 28), transform: nil), fill: Palette.cream, width: 1.8))
            root.setScale(0.75)
        }
        root.alpha = 0.9
        return root
    }
}
