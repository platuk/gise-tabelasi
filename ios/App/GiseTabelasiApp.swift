import SwiftUI

@main
struct CupTowerApp: App {
    init() {
        // Varsayılan ayarlar her şeyden önce: ses motoru ilk açıldığında ses düzeyini doğru okusun.
        GameSettings.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
