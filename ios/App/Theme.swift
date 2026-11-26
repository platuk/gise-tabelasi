import SwiftUI

/// 1930'lar çizgi film afişi paleti (SwiftUI tarafı). SpriteKit tarafı: `Palette`.
/// Görseller tamamen özgün olmalı; başka bir oyunun karakteri ya da varlığı kullanılmaz.
enum Theme {
    static let paper = Color(red: 0.95, green: 0.89, blue: 0.75)
    static let cream = Color(red: 0.98, green: 0.94, blue: 0.84)
    static let ink = Color(red: 0.12, green: 0.09, blue: 0.07)
    static let marquee = Color(red: 0.62, green: 0.16, blue: 0.11)
    static let bulb = Color(red: 1.00, green: 0.82, blue: 0.30)

    static func title(_ size: CGFloat) -> Font {
        .custom(Palette.fontName, size: size)
    }
}
