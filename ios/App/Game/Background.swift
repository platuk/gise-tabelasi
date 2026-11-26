import SpriteKit
import UIKit
import GameCore

/// Kodla "suluboya" boyayan ressam. 1930'ların çizgi film arka planları elle suluboya boyanırdı;
/// burada o hissi katman katman yarı saydam fırça lekeleri ve kâğıt dokusuyla üretiriz.
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

    static func paperGrain(_ cg: CGContext, size: CGSize, rng: inout SplitMix64, amount: Int) {
        for _ in 0..<amount {
            let x = CGFloat(rng.nextUnit()) * size.width
            let y = CGFloat(rng.nextUnit()) * size.height
            let light = rng.nextUnit() < 0.5
            cg.setFillColor((light ? UIColor.white : UIColor.black).withAlphaComponent(0.05).cgColor)
            cg.fill(CGRect(x: x, y: y, width: 1.2, height: 1.2))
        }
    }
}

