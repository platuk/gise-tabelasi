import Foundation
import GameCore
import SwiftUI

/// Uygulama durumu: seçili bulmaca dili, o dilin bölümleri ve ilerleme.
/// Bulmaca dili, cihazın arayüz dilinden bağımsız seçilebilir; her dilin ilerlemesi ayrı tutulur.
@MainActor
final class AppModel: ObservableObject {
    static let supportedLanguages = ["tr", "en"]
    private static let languageKey = "puzzleLanguage"

    @Published private(set) var language: String
    @Published private(set) var pack: LevelPack? = nil
    @Published private(set) var progress = PlayerProgress()
    @Published private(set) var loadError: String? = nil

    private let defaults: UserDefaults
    private let progressStore: ProgressStore

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.progressStore = ProgressStore(store: UserDefaultsStore(defaults: defaults))

        let saved = defaults.string(forKey: Self.languageKey)
        let device = Locale.preferredLanguages.first
            .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        let initial: String
        if let saved, Self.supportedLanguages.contains(saved) {
            initial = saved
        } else if Self.supportedLanguages.contains(device) {
            initial = device
        } else {
            initial = "en"
        }
        self.language = initial
        load(language: initial)
    }

    func setLanguage(_ newValue: String) {
        guard newValue != language, Self.supportedLanguages.contains(newValue) else { return }
        defaults.set(newValue, forKey: Self.languageKey)
        language = newValue
        load(language: newValue)
    }

    func isUnlocked(_ level: Level) -> Bool {
        guard let pack else { return false }
        return progress.isUnlocked(level, in: pack)
    }

    func markCompleted(_ level: Level) {
        guard !progress.isCompleted(level.id) else { return }
        progress.completedLevelIDs.insert(level.id)
        progressStore.save(progress, language: language)
    }

    private func load(language: String) {
        progress = progressStore.load(language: language)
        guard let url = Bundle.main.url(forResource: language, withExtension: "json") else {
            pack = nil
            loadError = String(localized: "error.loadLevels")
            return
        }
        do {
            let decoded = try LevelPack.decode(from: Data(contentsOf: url))
            // Geçersiz bölüm oyunu çökertmesin; derleme öncesi doğrulayıcı bunu zaten engeller.
            let valid = decoded.levels.filter { (try? GameState.validate($0)) != nil }
            assert(valid.count == decoded.levels.count, "Geçersiz bölüm var: node tools/validate-levels.mjs çalıştırın")
            pack = LevelPack(language: decoded.language, levels: valid)
            loadError = nil
        } catch {
            pack = nil
            loadError = String(localized: "error.loadLevels")
        }
    }
}
