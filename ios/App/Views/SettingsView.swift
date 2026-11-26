import SwiftUI

/// Ayarlar: ses düzeyleri, titreşim, ekran sarsıntısı, film efektleri; ana ekrandan açılınca ilerlemeyi sıfırlama ve hakkında.
struct SettingsView: View {
    /// Yalnızca ana ekrandan verilir (oyun içindeki ara menüsünde sıfırlama yok).
    var onReset: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @AppStorage(GameSettings.musicVolumeKey) private var musicVolume = 0.7
    @AppStorage(GameSettings.sfxVolumeKey) private var sfxVolume = 0.85
    @AppStorage(GameSettings.hapticsKey) private var haptics = true
    @AppStorage(GameSettings.screenShakeKey) private var screenShake = true
    @AppStorage(GameSettings.filmEffectsKey) private var filmEffects = true
    @State private var confirmingReset = false

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("settings.title").font(Theme.title(30))
                        Spacer()
                        Button {
                            MenuFeedback.tap()
                            dismiss()
                        } label: {
                            Text("help.done").font(Theme.title(18))
                        }
                    }
                    section("settings.sound") {
                        slider("settings.music", systemImage: "music.note", value: $musicVolume)
                        slider("settings.sfx", systemImage: "speaker.wave.2.fill", value: $sfxVolume)
                    }
                    section("settings.feel") {
                        toggle("settings.haptics", systemImage: "iphone.radiowaves.left.and.right", isOn: $haptics)
                        toggle("settings.shake", systemImage: "waveform.path", isOn: $screenShake)
                        toggle("settings.film", systemImage: "film", isOn: $filmEffects)
                        Text("settings.film.note").font(Theme.title(12)).opacity(0.7)
                    }
                    section("settings.language.title") {
                        Text("settings.language.body").font(Theme.title(14))
                        Button {
                            MenuFeedback.tap()
                            // iOS'un uygulamaya özel dil seçimi: Ayarlar > CupTower > Dil.
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("settings.language.open", systemImage: "globe")
                                .font(Theme.title(16))
                        }
                    }
                    if let onReset {
                        section("settings.progress") {
                            Button(role: .destructive) {
                                MenuFeedback.tap()
                                confirmingReset = true
                            } label: {
                                Label("settings.reset", systemImage: "arrow.counterclockwise")
                                    .font(Theme.title(16))
                            }
                            .confirmationDialog("settings.reset.confirm", isPresented: $confirmingReset, titleVisibility: .visible) {
                                Button("settings.reset.action", role: .destructive) { onReset() }
                            } message: {
                                Text("settings.reset.message")
                            }
                        }
                    }
                    section("settings.about.title") {
                        Text("settings.about.body").font(Theme.title(14))
                        Text("help.privacy.body").font(Theme.title(12)).opacity(0.75)
                    }
                }
                .foregroundStyle(Theme.ink)
                .tint(Theme.marquee)
                .padding(24)
            }
        }
        .onChange(of: musicVolume) { _, _ in SoundEngine.shared.applySettings() }
        .onChange(of: sfxVolume) { _, _ in
            SoundEngine.shared.applySettings()
            SoundEngine.shared.play(.click)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.title(18))
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cream))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink, lineWidth: 2.5))
    }

    private func slider(_ title: LocalizedStringKey, systemImage: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage).font(Theme.title(15))
            Slider(value: value, in: 0...1)
        }
    }

    private func toggle(_ title: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage).font(Theme.title(15))
        }
    }
}
