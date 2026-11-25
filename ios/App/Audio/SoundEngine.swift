import AVFoundation
import UIKit

/// Oyundaki ses efektleri. Hepsi kodla sentezlenir (dosya, lisans yok); 1930'lar çizgi filmi ses dünyası:
/// kaydırmalı düdük, tahta blok, yay "boing"i, trombon "vah vah", zil, fanfar.
enum SFX {
    case jump(power: Double)
    case land(big: Bool)
    case wallBounce
    case wallKick
    case bubble
    case powerUp
    case boost
    case trophy
    case milestone
    case comboUp(level: Int)
    case comboCash
    case burnStart
    case shieldSaved
    case died
    case respawn
    case bossIntro
    case bossWarning
    case bossAttack
    case bossHit
    case playerShot
    case playerHit
    case bossDefeated
    case click
    case countdown
    case go
    case unlock
}

/// Ses motoru: tek bir sentezleyici düğümü; müzik ve efektler aynı yerde karışır.
final class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var core: SynthCore?
    private var source: AVAudioSourceNode?
    private var mood = MusicMood.off
    private var lastShot = 0.0

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(restart),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restart),
                                               name: .AVAudioEngineConfigurationChange, object: engine)
    }

    /// İlk kullanımda kurulur. Sessize alma düğmesine uyar ve başka uygulamaların sesiyle karışır.
    func start() {
        guard core == nil else {
            restart()
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        var rate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        if rate <= 0 { rate = 44_100 }
        let core = SynthCore(sampleRate: rate)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else { return }
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let left = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let right = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
            core.render(frames: Int(frameCount), left: left, right: right)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.core = core
        source = node
        applySettings()
        try? engine.start()
    }

    @objc private func restart() {
        guard core != nil, !engine.isRunning else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
        restart()
    }

    func applySettings() {
        core?.send(kind: 5, a: GameSettings.musicVolume * 0.9, b: GameSettings.sfxVolume)
    }

    func setMood(_ newMood: MusicMood) {
        guard newMood != mood else { return }
        mood = newMood
        core?.send(kind: 1, a: Double(newMood.rawValue))
    }

    /// 1: davul ve bas; 2: + melodi; 3: + banjo ve trompet (büyük kombo).
    func setIntensity(_ level: Int) {
        core?.send(kind: 2, a: Double(level))
    }

    /// Oyunun temposuna göre müzik hızı (0.8 → 1.12).
    func setTempo(_ scale: Double) {
        core?.send(kind: 3, a: min(1.15, max(0.85, 0.9 + (scale - 0.8) * 0.6)))
    }

    /// Duraklatmada müzik kısılır.
    func setPaused(_ paused: Bool) {
        core?.send(kind: 4, a: paused ? 1 : 0)
    }

    // MARK: Efektler

    func play(_ sound: SFX) {
        guard let core else { return }
        core.trigger(Self.notes(for: sound, shotGate: &lastShot))
    }

    private static func notes(for sound: SFX, shotGate: inout Double) -> [Note] {
        let m = Note.midi
        switch sound {
        case .jump(let power):
            // Kaydırmalı düdük: hızlı zıplayış daha tiz.
            let top = 700 + 700 * power
            return [Note(wave: 3, freq: 380, to: top, glideTime: 0.05, amp: 0.13, attack: 0.004, hold: 0.05, release: 0.09)]
        case .land(let big):
            return [
                Note(wave: 0, freq: big ? 150 : 130, to: 55, glideTime: 0.03, amp: big ? 0.3 : 0.2, attack: 0.002, release: 0.09),
                Note(wave: 4, freq: 1, amp: 0.06, attack: 0.001, release: 0.04, cutoff: 1400),
            ]
        case .wallBounce:
            // Tahta blok "tok".
            return [
                Note(wave: 0, freq: 820, to: 700, glideTime: 0.02, amp: 0.16, attack: 0.001, release: 0.05),
                Note(wave: 3, freq: 1240, amp: 0.05, attack: 0.001, release: 0.03),
            ]
        case .wallKick:
            // Yay: "boing".
            return [Note(wave: 0, freq: 200, to: 330, glideTime: 0.08, vibRate: 17, vibDepth: 0.16, amp: 0.2, attack: 0.003, hold: 0.05, release: 0.32)]
        case .bubble:
            return [
                Note(wave: 0, freq: 600, to: 1500, glideTime: 0.015, amp: 0.16, attack: 0.001, release: 0.06),
                Note(wave: 0, freq: 900, to: 2000, glideTime: 0.015, amp: 0.1, attack: 0.001, release: 0.05, delay: 0.05),
            ]
        case .powerUp:
            return arpeggio([84, 88, 91, 96], wave: 3, step: 0.05, amp: 0.12, release: 0.14)
        case .boost:
            return [Note(wave: 2, freq: 90, to: 700, glideTime: 0.45, amp: 0.09, attack: 0.05, hold: 0.6, release: 0.7, cutoff: 900, cutoffEnv: 1200)]
                + arpeggio([79, 84, 88, 91, 96], wave: 3, step: 0.06, amp: 0.1, release: 0.14)
        case .trophy:
            return fanfare([67, 72, 76, 79], last: 84)
        case .milestone:
            return [Note(wave: 5, freq: m(91), amp: 0.1, attack: 0.002, release: 0.5),
                    Note(wave: 5, freq: m(96), amp: 0.07, attack: 0.002, release: 0.6, delay: 0.08)]
        case .comboUp(let level):
            // Her kombo adımında bir ses yükselen zil.
            let pitch = Double(min(96, 74 + level * 2))
            return [Note(wave: 5, freq: m(pitch), amp: 0.11, attack: 0.002, release: 0.35),
                    Note(wave: 0, freq: m(pitch + 19), amp: 0.03, attack: 0.002, release: 0.25)]
        case .comboCash:
            // Yazar kasa: "ka-çing".
            return [
                Note(wave: 4, freq: 1, amp: 0.08, attack: 0.001, release: 0.05, cutoff: 5000),
                Note(wave: 5, freq: m(93), amp: 0.11, attack: 0.002, release: 0.5, delay: 0.06),
                Note(wave: 5, freq: m(100), amp: 0.09, attack: 0.002, release: 0.7, delay: 0.12),
            ]
        case .burnStart:
            return [
                Note(wave: 4, freq: 1, amp: 0.2, attack: 0.15, hold: 0.4, release: 0.6, cutoff: 220),
                Note(wave: 0, freq: 70, to: 50, glideTime: 0.6, amp: 0.2, attack: 0.1, hold: 0.3, release: 0.5),
            ]
        case .shieldSaved:
            return [Note(wave: 0, freq: 1320, amp: 0.1, attack: 0.002, release: 0.5),
                    Note(wave: 0, freq: 1980, amp: 0.06, attack: 0.002, release: 0.4),
                    Note(wave: 3, freq: 660, to: 990, glideTime: 0.05, amp: 0.08, attack: 0.003, release: 0.2)]
        case .died:
            // Trombon: "vah vah vah vaaah".
            var notes: [Note] = []
            for (index, pitch) in [55.0, 54, 53].enumerated() {
                notes.append(Note(wave: 2, freq: m(pitch), to: m(pitch - 0.4), glideTime: 0.3, amp: 0.14, attack: 0.03,
                                  hold: 0.25, release: 0.12, cutoff: 700, cutoffEnv: 1100, delay: Double(index) * 0.42))
            }
            notes.append(Note(wave: 2, freq: m(52), to: m(51), glideTime: 1.0, vibRate: 7, vibDepth: 0.03, amp: 0.15,
                              attack: 0.03, hold: 0.9, release: 0.3, cutoff: 700, cutoffEnv: 1100, delay: 1.26))
            return notes
        case .respawn:
            // Arp glisandosu yukarı.
            return arpeggio([72, 74, 76, 79, 81, 84, 86, 88, 91, 96], wave: 3, step: 0.035, amp: 0.08, release: 0.3)
        case .bossIntro:
            // Trampet tremolosu ve zil.
            var notes: [Note] = []
            for index in 0..<16 {
                notes.append(Note(wave: 4, freq: 1, amp: 0.05 + Double(index) * 0.006, attack: 0.001, release: 0.04,
                                  cutoff: 3000, delay: Double(index) * 0.045))
            }
            notes.append(Note(wave: 4, freq: 1, amp: 0.2, attack: 0.002, release: 1.2, cutoff: 7000, delay: 0.75))
            notes.append(Note(wave: 2, freq: m(40), amp: 0.18, attack: 0.02, hold: 0.4, release: 0.5, cutoff: 500, cutoffEnv: 700, delay: 0.75))
            return notes
        case .bossWarning:
            // Uğursuz boru.
            return [
                Note(wave: 2, freq: m(47), vibRate: 6, vibDepth: 0.012, amp: 0.12, attack: 0.03, hold: 0.18, release: 0.15, cutoff: 500, cutoffEnv: 900),
                Note(wave: 2, freq: m(46), vibRate: 6, vibDepth: 0.012, amp: 0.12, attack: 0.03, hold: 0.25, release: 0.2, cutoff: 500, cutoffEnv: 900, delay: 0.22),
            ]
        case .bossAttack:
            return [Note(wave: 4, freq: 1, amp: 0.12, attack: 0.04, release: 0.22, cutoff: 1800)]
        case .bossHit:
            return [Note(wave: 1, freq: 1100, to: 800, glideTime: 0.01, amp: 0.035, attack: 0.001, release: 0.025, cutoff: 3000)]
        case .playerShot:
            // Sık ateş edildiği için kısık ve seyreltilmiş.
            let now = CACurrentMediaTime()
            guard now - shotGate > 0.18 else { return [] }
            shotGate = now
            return [Note(wave: 3, freq: 1500, to: 900, glideTime: 0.02, amp: 0.025, attack: 0.001, release: 0.03)]
        case .playerHit:
            return [
                Note(wave: 1, freq: 190, to: 110, glideTime: 0.1, amp: 0.13, attack: 0.001, release: 0.25, cutoff: 1500),
                Note(wave: 4, freq: 1, amp: 0.1, attack: 0.001, release: 0.1, cutoff: 2500),
            ]
        case .bossDefeated:
            return [Note(wave: 4, freq: 1, amp: 0.3, attack: 0.002, release: 1.0, cutoff: 900),
                    Note(wave: 0, freq: 90, to: 35, glideTime: 0.5, amp: 0.3, attack: 0.002, release: 0.8)]
                + fanfare([72, 76, 79, 84], last: 88, delay: 0.5)
        case .click:
            return [Note(wave: 0, freq: 1050, to: 900, glideTime: 0.01, amp: 0.13, attack: 0.001, release: 0.035)]
        case .countdown:
            return [Note(wave: 3, freq: 880, amp: 0.12, attack: 0.002, hold: 0.05, release: 0.1)]
        case .go:
            return [Note(wave: 3, freq: 1320, amp: 0.13, attack: 0.002, hold: 0.12, release: 0.2),
                    Note(wave: 3, freq: 1760, amp: 0.06, attack: 0.002, hold: 0.12, release: 0.2)]
        case .unlock:
            return fanfare([72, 79], last: 84)
        }
    }

    private static func arpeggio(_ pitches: [Double], wave: UInt8, step: Double, amp: Double, release: Double) -> [Note] {
        pitches.enumerated().map { index, pitch in
            Note(wave: wave, freq: Note.midi(pitch), amp: amp, attack: 0.002, release: release, delay: Double(index) * step)
        }
    }

    /// Bando fanfarı: kısa notalar, son nota uzun ve titrek.
    private static func fanfare(_ pitches: [Double], last: Double, delay: Double = 0) -> [Note] {
        var notes: [Note] = []
        for (index, pitch) in pitches.enumerated() {
            notes.append(Note(wave: 2, freq: Note.midi(pitch), amp: 0.09, attack: 0.01, hold: 0.06, release: 0.08,
                              cutoff: 1400, cutoffEnv: 2600, delay: delay + Double(index) * 0.1))
        }
        let end = delay + Double(pitches.count) * 0.1
        notes.append(Note(wave: 2, freq: Note.midi(last), vibRate: 6, vibDepth: 0.012, amp: 0.1, attack: 0.02, hold: 0.45,
                          release: 0.35, cutoff: 1400, cutoffEnv: 2600, delay: end))
        notes.append(Note(wave: 2, freq: Note.midi(last - 12), amp: 0.06, attack: 0.02, hold: 0.45, release: 0.35,
                          cutoff: 900, cutoffEnv: 1500, delay: end))
        return notes
    }
}
