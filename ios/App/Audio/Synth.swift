import Foundation
import os

/// Sentezleyicideki tek ses: osilatör + zarf + isteğe bağlı süzgeç, perde kayması ve vibrato.
/// Ses iş parçacığında çalışır: bellek ayırmaz, nesne oluşturmaz.
struct Voice {
    var active = false
    /// 0: müzik, 1: efekt.
    var bus: UInt8 = 0
    /// 0 sinüs, 1 kare, 2 testere, 3 üçgen, 4 gürültü, 5 piyano (harmonikli).
    var wave: UInt8 = 0
    var delay: Int32 = 0
    var phase = 0.0
    var freq = 440.0
    var target = 440.0
    var glide = 0.0
    var vibRate = 0.0
    var vibDepth = 0.0
    var vibPhase = 0.0
    var amp = 0.2
    var env = 0.0
    var attackStep = 1.0
    var attacking = true
    var hold: Int32 = 0
    var decay = 0.999
    var lp = 1.0
    var lpEnv = 0.0
    var lpState = 0.0
    var noise: UInt32 = 0x9E37_79B9

    mutating func next(_ invSR: Double) -> Double {
        if delay > 0 {
            delay -= 1
            return 0
        }
        if glide > 0 { freq += (target - freq) * glide }
        var f = freq
        if vibDepth > 0 {
            vibPhase += vibRate * invSR
            if vibPhase >= 1 { vibPhase -= 1 }
            f *= 1 + vibDepth * sin(2 * .pi * vibPhase)
        }
        phase += f * invSR
        if phase >= 1 { phase -= floor(phase) }
        var s: Double
        switch wave {
        case 0: s = sin(2 * .pi * phase)
        case 1: s = phase < 0.5 ? 0.8 : -0.8
        case 2: s = 2 * phase - 1
        case 3: s = 4 * abs(phase - 0.5) - 1
        case 4:
            noise ^= noise << 13
            noise ^= noise >> 17
            noise ^= noise << 5
            s = Double(noise) / Double(UInt32.max) * 2 - 1
        default:
            let p = 2 * .pi * phase
            s = (sin(p) + 0.45 * sin(2 * p) + 0.2 * sin(3 * p) + 0.08 * sin(5 * p)) * 0.6
        }
        if attacking {
            env += attackStep
            if env >= 1 {
                env = 1
                attacking = false
            }
        } else if hold > 0 {
            hold -= 1
        } else {
            env *= decay
            if env < 0.0008 { active = false }
        }
        if lp < 1 {
            let c = min(1, lp + lpEnv * env)
            lpState += (s - lpState) * c
            s = lpState
        }
        return s * env * amp
    }
}

/// Bir notanın insan dostu tarifi; `Voice`'a dönüştürülür.
struct Note {
    var wave: UInt8 = 0
    var freq: Double
    var to: Double? = nil
    var glideTime = 0.05
    var vibRate = 0.0
    var vibDepth = 0.0
    var amp = 0.2
    var attack = 0.004
    var hold = 0.0
    var release = 0.2
    /// Hz; nil: süzgeç yok.
    var cutoff: Double? = nil
    /// Zarf açıkken süzgecin ek açılması (Hz).
    var cutoffEnv = 0.0
    var delay = 0.0
    var bus: UInt8 = 1

    static func midi(_ note: Double) -> Double { 440 * pow(2, (note - 69) / 12) }

    func voice(sampleRate sr: Double, seed: UInt32) -> Voice {
        var v = Voice()
        v.active = true
        v.bus = bus
        v.wave = wave
        v.delay = Int32(delay * sr)
        v.freq = freq
        v.target = to ?? freq
        v.glide = to == nil ? 0 : 1 - exp(-1 / max(0.001, glideTime) / sr)
        v.vibRate = vibRate
        v.vibDepth = vibDepth
        v.amp = amp
        v.attackStep = 1 / max(1, attack * sr)
        v.hold = Int32(hold * sr)
        // Bırakma süresinde ~60 dB söner.
        v.decay = exp(log(0.001) / max(1, release * sr))
        if let cutoff {
            v.lp = 1 - exp(-2 * .pi * cutoff / sr)
            v.lpEnv = cutoffEnv > 0 ? 1 - exp(-2 * .pi * cutoffEnv / sr) : 0
        }
        v.noise = seed | 1
        return v
    }
}

enum MusicMood: Int {
    case menu = 0
    case climb = 1
    case boss = 2
    case off = 3
}

/// Gerçek zamanlı sentezleyici ve müzik sıralayıcısı.
///
/// Müzik: 1930'lar sıcak cazı (ragtime havası): tuba bas, stride piyano, fırçalı davul, klarnet melodisi,
/// kombo büyüdükçe banjo ve trompet eklenir. Boss müziği minör, düz ve hızlı.
/// Melodiler başlangıçta sabit tohumla üretilir: her açılışta aynı akılda kalıcı tema.
/// Müzik "gramofon" süzgecinden geçer (boğuk tını, hafif cızırtı).
final class SynthCore {
    let sampleRate: Double
    private let invSR: Double
    private let voiceCount = 72
    private let voices: UnsafeMutablePointer<Voice>
    private var nextVoice = 0

    // Ana iş parçacığından gelen komutlar.
    private struct Command {
        var kind: UInt8 = 0 // 0 ses, 1 müzik ruhu, 2 yoğunluk, 3 tempo, 4 duraklat, 5 ses düzeyleri
        var voice = Voice()
        var a = 0.0
        var b = 0.0
    }
    private let commandCapacity = 192
    private let commands: UnsafeMutablePointer<Command>
    private var commandCount = 0
    private let lock: os_unfair_lock_t

    // Müzik durumu (yalnızca ses iş parçacığı).
    private var mood = MusicMood.off
    private var intensity = 2
    private var tempoScale = 1.0
    private var samplesToStep = 0.0
    private var stepInBar = 0
    private var bar = 0
    private var paused = false
    private var noiseSeed: UInt32 = 0x1234_5678

    // Besteler: 3 ruh × 8 ölçü.
    private let chordRoot: UnsafeMutablePointer<Int16>
    private let chordKind: UnsafeMutablePointer<Int16>
    /// 3 ruh × 8 ölçü × 8 sekizlik; -1 sus.
    private let melody: UnsafeMutablePointer<Int16>

    // Karıştırıcı
    private var musicVolume = 0.7
    private var sfxVolume = 0.85
    private var musicGain = 0.0
    private var sfxGain = 0.0
    private var duck = 1.0
    private var gramoLP = 0.0
    private var gramoHP = 0.0
    private var crackle = 0.0
    private var hiss = 0.0
    private var sfxLP = 0.0
    private let gramoCoef: Double
    private let hpCoef: Double
    private let sfxCoef: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        invSR = 1 / sampleRate
        voices = .allocate(capacity: 72)
        voices.initialize(repeating: Voice(), count: 72)
        commands = .allocate(capacity: 192)
        commands.initialize(repeating: Command(), count: 192)
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        chordRoot = .allocate(capacity: 24)
        chordKind = .allocate(capacity: 24)
        melody = .allocate(capacity: 3 * 64)
        gramoCoef = 1 - exp(-2 * .pi * 4200 / sampleRate)
        hpCoef = 1 - exp(-2 * .pi * 110 / sampleRate)
        sfxCoef = 1 - exp(-2 * .pi * 9000 / sampleRate)
        compose()
    }

    // MARK: Ana iş parçacığı

    func trigger(_ notes: [Note]) {
        os_unfair_lock_lock(lock)
        for note in notes where commandCount < commandCapacity {
            noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
            commands[commandCount] = Command(kind: 0, voice: note.voice(sampleRate: sampleRate, seed: noiseSeed))
            commandCount += 1
        }
        os_unfair_lock_unlock(lock)
    }

    func send(kind: UInt8, a: Double, b: Double = 0) {
        os_unfair_lock_lock(lock)
        if commandCount < commandCapacity {
            commands[commandCount] = Command(kind: kind, a: a, b: b)
            commandCount += 1
        }
        os_unfair_lock_unlock(lock)
    }

    // MARK: Ses iş parçacığı

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>?) {
        if os_unfair_lock_trylock(lock) {
            for index in 0..<commandCount { apply(commands[index]) }
            commandCount = 0
            os_unfair_lock_unlock(lock)
        }
        for frame in 0..<frames {
            if mood != .off {
                samplesToStep -= 1
                if samplesToStep <= 0 { musicStep() }
            }
            var music = 0.0
            var sfx = 0.0
            for index in 0..<voiceCount where voices[index].active {
                let sample = voices[index].next(invSR)
                if voices[index].bus == 0 { music += sample } else { sfx += sample }
            }
            // Gramofon: boğuk üst, ince alt, hafif cızırtı.
            gramoLP += (music - gramoLP) * gramoCoef
            gramoHP += (gramoLP - gramoHP) * hpCoef
            var m = gramoLP - gramoHP
            if mood != .off {
                noiseSeed ^= noiseSeed << 13
                noiseSeed ^= noiseSeed >> 17
                noiseSeed ^= noiseSeed << 5
                let r = Double(noiseSeed) / Double(UInt32.max)
                if r < 0.00012 { crackle = (r * 8_000 - 0.5) * 0.12 }
                crackle *= 0.93
                hiss += ((r - 0.5) * 0.006 - hiss) * 0.3
                m += crackle + hiss
            }
            sfxLP += (sfx - sfxLP) * sfxCoef

            let targetMusic = musicVolume * duck * (mood == .off ? 0 : 1)
            musicGain += (targetMusic - musicGain) * 0.0004
            sfxGain += (sfxVolume - sfxGain) * 0.002
            let mixed = m * musicGain + sfxLP * sfxGain
            let out = Float(tanh(mixed * 1.2) * 0.9)
            left[frame] = out
            right?[frame] = out
        }
    }

    private func apply(_ command: Command) {
        switch command.kind {
        case 0:
            start(command.voice)
        case 1:
            let newMood = MusicMood(rawValue: Int(command.a)) ?? .off
            if newMood != mood {
                mood = newMood
                stepInBar = 0
                bar = 0
                samplesToStep = 0
            }
        case 2:
            intensity = Int(command.a)
        case 3:
            tempoScale = command.a
        case 4:
            paused = command.a > 0.5
            duck = paused ? 0.3 : 1
        default:
            musicVolume = command.a
            sfxVolume = command.b
        }
    }

    private func start(_ voice: Voice) {
        // Boş ses ara; yoksa sıradakini çal (en eskisi).
        for offset in 0..<voiceCount {
            let index = (nextVoice + offset) % voiceCount
            if !voices[index].active {
                voices[index] = voice
                nextVoice = (index + 1) % voiceCount
                return
            }
        }
        voices[nextVoice] = voice
        nextVoice = (nextVoice + 1) % voiceCount
    }

    private func play(_ note: Note) {
        noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
        start(note.voice(sampleRate: sampleRate, seed: noiseSeed))
    }

    // MARK: Müzik

    private var bpm: Double {
        switch mood {
        case .menu: return 108
        case .boss: return 150 * min(1.08, tempoScale)
        default: return 128 * tempoScale
        }
    }

    private var swing: Double { mood == .boss ? 0.5 : 0.62 }

    private static func interval(kind: Int16, index: Int) -> Int {
        switch (kind, index) {
        case (_, 0): return 0
        case (2, 1), (3, 1): return 3
        case (_, 1): return 4
        case (_, 2): return 7
        default: return kind == 1 || kind == 3 ? 10 : 12
        }
    }

    private func musicStep() {
        let beat = 60 / bpm
        let long = stepInBar % 2 == 0
        samplesToStep += (long ? beat * swing : beat * (1 - swing)) * sampleRate
        let moodIndex = mood.rawValue
        let chordIndex = moodIndex * 8 + bar % 8
        let root = Int(chordRoot[chordIndex])
        let kind = chordKind[chordIndex]
        let e = stepInBar
        let eighth = beat / 2
        let isBoss = mood == .boss

        // Tuba bas: 1. ve 3. vuruşta kök ve beşli (boss'ta tango ritmi).
        let bassHits = isBoss ? (e == 0 || e == 3 || e == 4 || e == 6) : (e == 0 || e == 4)
        if bassHits {
            let pitch = root - 12 + (e == 4 ? 7 : (e == 6 ? 12 : 0))
            play(Note(wave: 2, freq: Note.midi(Double(pitch)), amp: isBoss ? 0.2 : 0.17, attack: 0.012,
                      hold: eighth * 0.6, release: 0.22, cutoff: 380, cutoffEnv: 500, bus: 0))
        }
        // Stride piyano: 2. ve 4. vuruşta akor.
        if e == 2 || e == 6 {
            for index in 0..<4 {
                let pitch = root + 12 + Self.interval(kind: kind, index: index)
                play(Note(wave: 5, freq: Note.midi(Double(pitch)), amp: mood == .menu ? 0.05 : 0.045,
                          attack: 0.003, release: 0.32, bus: 0))
            }
        }
        // Davul (menüde yok): bas davul 1-3, trampet 2-4, fırça her sekizlik.
        if mood != .menu && intensity >= 1 {
            if e == 0 || e == 4 {
                play(Note(wave: 0, freq: 110, to: 45, glideTime: 0.03, amp: 0.32, attack: 0.002, release: 0.14, bus: 0))
            }
            if e == 2 || e == 6 {
                play(Note(wave: 4, freq: 1, amp: 0.10, attack: 0.001, release: 0.1, cutoff: 3200, bus: 0))
                play(Note(wave: 0, freq: 200, to: 170, amp: 0.06, attack: 0.001, release: 0.06, bus: 0))
            }
            play(Note(wave: 4, freq: 1, amp: e % 2 == 1 ? 0.045 : 0.028, attack: 0.001,
                      release: e % 2 == 1 ? 0.05 : 0.03, cutoff: 9000, bus: 0))
        }
        // Klarnet melodisi
        if intensity >= 2 || mood == .menu {
            let base = moodIndex * 64 + (bar % 8) * 8
            let pitch = melody[base + e]
            if pitch >= 0 {
                var length = 1
                while e + length < 8 && melody[base + e + length] < 0 { length += 1 }
                let duration = Double(length) * eighth
                play(Note(wave: 1, freq: Note.midi(Double(pitch)), vibRate: 5.5, vibDepth: 0.007,
                          amp: mood == .menu ? 0.075 : 0.085, attack: 0.02, hold: duration * 0.6, release: 0.14,
                          cutoff: 1500, cutoffEnv: 900, bus: 0))
            }
        }
        // Kombo büyüyünce: banjo vuruşları ve trompet cevapları.
        if intensity >= 3 {
            if e % 2 == 1 {
                for index in 0..<3 {
                    let pitch = root + 24 + Self.interval(kind: kind, index: index)
                    play(Note(wave: 2, freq: Note.midi(Double(pitch)), amp: 0.03, attack: 0.001,
                              release: 0.12, cutoff: 3600, delay: Double(index) * 0.012, bus: 0))
                }
            }
            if bar % 2 == 1 && (e == 3 || e == 5) {
                let pitch = root + 24 + Self.interval(kind: kind, index: e == 3 ? 2 : 1)
                play(Note(wave: 2, freq: Note.midi(Double(pitch)), vibRate: 6, vibDepth: 0.01, amp: 0.07,
                          attack: 0.02, hold: eighth * 1.2, release: 0.18, cutoff: 1200, cutoffEnv: 2600, bus: 0))
            }
        }

        stepInBar += 1
        if stepInBar >= 8 {
            stepInBar = 0
            bar += 1
        }
    }

    /// Üç beste: menü (Fa majör, sakin), tırmanış (Do majör ragtime), boss (La minör, gergin).
    private func compose() {
        // (kök, tür) tür: 0 majör, 1 dominant 7, 2 minör, 3 minör 7
        let progressions: [[(Int16, Int16)]] = [
            [(53, 0), (50, 1), (55, 1), (48, 1), (53, 0), (53, 1), (46, 0), (48, 1)],
            [(48, 0), (45, 1), (50, 1), (43, 1), (48, 0), (48, 1), (53, 0), (43, 1)],
            [(45, 2), (52, 1), (45, 2), (52, 1), (50, 2), (45, 2), (52, 1), (45, 2)],
        ]
        let rhythms: [[Bool]] = [
            [true, false, true, true, false, true, false, false],
            [true, false, false, true, false, false, true, false],
            [true, true, false, true, false, true, true, false],
            [false, true, true, false, true, false, true, false],
            [true, false, true, false, true, false, true, true],
        ]
        let cadence: [Bool] = [true, false, true, false, false, false, false, false]
        var rng: UInt64 = 0x7A5C_0FFE
        func random() -> Double {
            rng = rng &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(rng >> 11) / Double(1 << 53)
        }
        for mood in 0..<3 {
            for bar in 0..<8 {
                chordRoot[mood * 8 + bar] = progressions[mood][bar].0
                chordKind[mood * 8 + bar] = progressions[mood][bar].1
            }
            var barRhythm: [[Bool]] = []
            for bar in 0..<4 { barRhythm.append(rhythms[Int(random() * Double(rhythms.count)) % rhythms.count]) ; _ = bar }
            barRhythm += [barRhythm[0], barRhythm[1], barRhythm[2], cadence]
            var previous = mood == 2 ? 72 : 76
            for bar in 0..<8 {
                let (root, kind) = progressions[mood][bar]
                var tones: [Int] = []
                for octave in 0..<4 {
                    for index in 0..<4 {
                        let tone = Int(root) + 12 * octave + Self.interval(kind: kind, index: index)
                        if tone >= 67 && tone <= 86 { tones.append(tone) }
                    }
                }
                for e in 0..<8 {
                    var pitch = -1
                    if barRhythm[bar][e] {
                        if bar == 7 {
                            // Kapanış: üçlü, sonra kök.
                            let wanted = e == 0 ? Self.interval(kind: kind, index: 1) : 0
                            pitch = tones.filter { (($0 - Int(root)) % 12 + 12) % 12 == wanted }
                                .min(by: { abs($0 - previous) < abs($1 - previous) }) ?? previous
                        } else {
                            var near = tones.filter { abs($0 - previous) <= 5 && $0 != previous }
                            if near.isEmpty { near = tones }
                            pitch = near[Int(random() * Double(near.count)) % near.count]
                            // Ara sıra yarım ses yaklaşma (caz rengi).
                            if e % 2 == 1 && random() < 0.2 { pitch -= 1 }
                        }
                        previous = pitch
                    }
                    melody[mood * 64 + bar * 8 + e] = Int16(pitch)
                }
            }
        }
    }
}
