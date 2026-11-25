import SwiftUI

/// 1930'lar çizgi film afişi paleti: kâğıt, mürekkep, tabela kırmızısı, ampul sarısı.
/// Görseller tamamen özgün olmalı; başka bir oyunun karakteri ya da varlığı kullanılmaz.
enum Theme {
    static let paper = Color(red: 0.96, green: 0.91, blue: 0.80)
    static let ink = Color(red: 0.13, green: 0.10, blue: 0.08)
    static let marquee = Color(red: 0.55, green: 0.12, blue: 0.10)
    static let bulbOn = Color(red: 1.00, green: 0.82, blue: 0.30)
    static let bulbOff = Color(red: 0.45, green: 0.38, blue: 0.30)

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .serif)
    }
}
