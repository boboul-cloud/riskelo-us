//
//  Sounds.swift
//  Riskelo US
//
//  The sounds, written rather than recorded.
//
//  Few signals, and each one for a moment you cannot miss: the troop laid
//  down, the exchange won, the exchange lost, the app opening, and the end of
//  the game — from one side or the other. A game that comments on every tap
//  quickly becomes a game you play with the sound off.
//
//  They are computed on first need, sample by sample, the way the icon is
//  drawn in code. The reason is the same: no file to carry, no license to
//  check, and a note is tuned by changing a number rather than by reopening
//  an editor. Three quarters of a second of sound fits in twenty lines of
//  score.
//
//  The timbre is not a bare sine wave — that sounds like a hearing test. Two
//  harmonics above the fundamental, a short attack and a soft decay: enough
//  to suggest a wooden piece being set down.
//
//  Each note sets its own brightness on top, which is to say what those
//  harmonics weigh. Wood for the whole game, brass for the victory fanfare
//  alone: a trumpet and a mallet do not differ in their notes, they differ
//  there.
//

import AVFoundation

@MainActor
final class Sounds {

    static let shared = Sounds()

    /// The option, kept from one game to the next. The setting lives in the
    /// system preferences and not in the game: it holds for the whole app,
    /// not for one game in particular.
    static let key = "riskelo.us.sounds"

    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    enum Signal: Hashable {
        /// A troop laid on the board: one short, muted note.
        case place
        /// The exchange goes my way: three notes rising.
        case won
        /// It goes against me: three notes falling.
        case lost
        /// The opening: the two sides meeting, then the chord.
        case opening
        /// The game is won: the opening carried through to the end, and the
        /// chord that remains.
        case victory
        /// It is lost: the same gesture turned over, falling and fading.
        case defeat
    }

    private let engine = AVAudioEngine()
    private let voice = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    /// A sound failure must never get in the way of the game: we note it once
    /// and never come back to it.
    private var broken = false
    private var buffers: [Signal: AVAudioPCMBuffer] = [:]

    private init() {
        guard let format else { broken = true; return }
        engine.attach(voice)
        engine.connect(voice, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.85
    }

    func play(_ signal: Signal) {
        guard Sounds.enabled, !broken, let buffer = buffer(signal) else { return }
        start()
        guard engine.isRunning else { return }
        // `interrupts`: a second verdict landing quickly cuts the first
        // rather than sounding over it.
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { voice.play() }
    }

    /// The sound as it will be played, rendered outside the app.
    ///
    /// Open for "outils/ecoute.swift", which writes the files you listen to
    /// before deciding. Without it the tool would copy out the scores, and
    /// you would pick on headphones a sound the app does not play.
    func render(_ signal: Signal) -> AVAudioPCMBuffer? { buffer(signal) }

    private func start() {
        guard !engine.isRunning, !broken else { return }
        #if os(iOS)
        // An "ambient" session: the game does not cut off the music of
        // someone playing while listening to their own, and the iPhone's
        // silent switch mutes it — which is what you expect of a sound
        // effect, not of a player.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
        do { try engine.start() } catch { broken = true }
    }

    // MARK: - The scores

    /// A note: its pitch, its entry, its length, and what it weighs in the
    /// mix. All of it in seconds and hertz — nothing in samples, which do not
    /// read back.
    private struct Note {
        let pitch: Double
        let start: Double
        let length: Double
        let level: Double
        /// The brass: what the harmonics above the fundamental weigh. At 1,
        /// the wooden timbre of the whole game. Above that, the note shines
        /// and starts to sound like a trumpet — that is what separates a
        /// piece being set down from a fanfare, far more than the pitch of
        /// the notes.
        var brightness: Double = 1
    }

    private func score(_ signal: Signal) -> [Note] {
        switch signal {
        case .place:
            // A wooden piece being set down: short, muted, and three times
            // more discreet than the rest. It lands up to ten times running
            // at the start of a turn — which is what dictates its restraint.
            // The octave above is not heard as a note: it gives grain to the
            // attack, and nothing more.
            return [
                Note(pitch: 392.00, start: 0, length: 0.13, level: 0.22),  // G
                Note(pitch: 784.00, start: 0, length: 0.09, level: 0.09),  // its octave
            ]
        case .won:
            // A major chord rising, up to the octave. Short: it lands several
            // times a turn.
            return [
                Note(pitch: 440.00, start: 0.000, length: 0.30, level: 0.42),  // A
                Note(pitch: 554.37, start: 0.075, length: 0.30, level: 0.42),  // C sharp
                Note(pitch: 659.25, start: 0.150, length: 0.34, level: 0.45),  // E
                Note(pitch: 880.00, start: 0.225, length: 0.46, level: 0.39),  // A
            ]
        case .lost:
            // The same gesture turned over: a minor chord falling, slower and
            // lower. It does not growl — you lose a troop, not the game.
            return [
                Note(pitch: 349.23, start: 0.00, length: 0.34, level: 0.39),   // F
                Note(pitch: 293.66, start: 0.11, length: 0.40, level: 0.36),   // D
                Note(pitch: 220.00, start: 0.22, length: 0.60, level: 0.42),   // A
            ]
        case .opening:
            // What the screen shows at the same moment: two voices setting
            // out from the two edges and meeting — one rising, one falling —
            // and the chord closing as the two halves touch.
            var notes: [Note] = []
            let rising = [261.63, 329.63, 392.00]     // C, E, G
            let falling = [783.99, 659.25, 523.25]    // G, E, C
            for (i, (low, high)) in zip(rising, falling).enumerated() {
                let t = Double(i) * 0.17
                notes.append(Note(pitch: low, start: t, length: 0.28, level: 0.20))
                notes.append(Note(pitch: high, start: t, length: 0.28, level: 0.18))
            }
            for pitch in [261.63, 329.63, 392.00, 523.25] {
                notes.append(Note(pitch: pitch, start: 0.55, length: 1.50, level: 0.17))
            }
            return notes
        case .victory:
            // The end, for whoever wins. A bugle call, not an arpeggio: what
            // makes it military is not the pitch of the notes, it is three
            // things — the dotted rhythm, the brass, and two trumpets instead
            // of one.
            //
            // It sounds once a game: that is what earns it its three seconds
            // and its swagger, where the won exchange, landing ten times a
            // turn, has to be forgettable.
            var notes: [Note] = []

            /// The two trumpets, on the same figure.
            ///
            /// The second follows the first a third below, and sits lower in
            /// volume: two equal voices do not make two trumpets, they make
            /// one thick trumpet.
            ///
            /// The lower note is written out each time rather than computed.
            /// Under the C, the third would be A — and A sounds a minor right
            /// in the middle of a fanfare: we put the fourth there instead. A
            /// rule with two exceptions out of five is no longer a rule, it
            /// is a table.
            func trumpets(_ high: Double, _ low: Double,
                          _ start: Double, _ length: Double, _ level: Double) {
                notes.append(Note(pitch: high, start: start, length: length,
                                  level: level, brightness: 2.4))
                notes.append(Note(pitch: low, start: start, length: length,
                                  level: level * 0.66, brightness: 2.2))
            }

            // The call. Dotted rhythm — one long, one short, and again: that
            // is the figure of every military bugle call, and what separates
            // it from a scale played in even time. The same cell twice, then
            // the held note: a call is recognizable because it repeats, never
            // because it moves on.
            trumpets(392.00, 329.63, 0.000, 0.175, 0.52)   // G · E
            trumpets(392.00, 329.63, 0.195, 0.055, 0.52)
            trumpets(523.25, 392.00, 0.260, 0.175, 0.55)   // C · G
            trumpets(523.25, 392.00, 0.455, 0.055, 0.55)
            trumpets(659.25, 523.25, 0.520, 0.240, 0.58)   // E · C, held

            // The charge. The same dotted cell, up a step each time, to the
            // octave above. The bugle's notes and no others — C, E, G, C:
            // the ones a valveless brass can give, which is the very reason
            // for their sound.
            trumpets(523.25, 392.00, 0.780, 0.175, 0.55)
            trumpets(659.25, 523.25, 0.975, 0.055, 0.55)
            trumpets(783.99, 659.25, 1.040, 0.175, 0.58)
            trumpets(783.99, 659.25, 1.235, 0.055, 0.58)
            trumpets(1046.50, 783.99, 1.300, 0.420, 0.60)  // the summit

            // The chord, wide across two octaves, and held. It settles while
            // the summit is still sounding, or the call would drop into a
            // hole before closing.
            //
            // Each voice in it is quiet: five notes together add up, and it
            // is the sum that clips, never the note taken on its own. They
            // shine less than the call — a held chord that is too brassy
            // stops being a chord and becomes a car horn.
            for pitch in [261.63, 329.63, 392.00, 523.25, 783.99] {
                notes.append(Note(pitch: pitch, start: 1.62, length: 1.55,
                                  level: 0.20, brightness: 1.5))
            }
            return notes
        case .defeat:
            // The same moment, from the other side. It falls instead of
            // rising and fades instead of holding — but it does not growl:
            // you lose a game, you start another.
            //
            // Nothing goes below this low G. A phone speaker gives back
            // almost nothing under it, and a defeat you cannot hear is a
            // defeat with no sound.
            var notes: [Note] = []
            let descent = [293.66, 233.08, 196.00]   // D, B flat, G
            for (i, pitch) in descent.enumerated() {
                notes.append(Note(pitch: pitch, start: Double(i) * 0.16,
                                  length: 0.42, level: 0.30))
            }
            // Lower than victory's rise, and shorter: the sound that consoles
            // does not assert itself as much as the one that congratulates.
            for pitch in [196.00, 233.08, 293.66] {
                notes.append(Note(pitch: pitch, start: 0.55, length: 1.60, level: 0.14))
            }
            return notes
        }
    }

    // MARK: - The workshop

    private func buffer(_ signal: Signal) -> AVAudioPCMBuffer? {
        if let already = buffers[signal] { return already }
        guard let format else { return nil }
        let notes = score(signal)
        let seconds = (notes.map { $0.start + $0.length }.max() ?? 0) + 0.05
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        for i in 0 ..< Int(frames) { channel[i] = 0 }

        let rate = format.sampleRate
        for note in notes {
            let begin = Int(note.start * rate)
            for k in 0 ..< Int(note.length * rate) {
                let i = begin + k
                guard i < Int(frames) else { break }
                let t = Double(k) / rate
                let phase = 2 * Double.pi * note.pitch * t
                // The harmonics carry the note's brightness, and the sum is
                // brought back to 1: otherwise a bright note would also be a
                // louder note, and you would think you were setting the
                // timbre while setting the volume.
                let h2 = 0.30 * note.brightness
                let h3 = 0.12 * note.brightness
                let h4 = 0.05 * max(0, note.brightness - 1)
                let wave = (sin(phase) + h2 * sin(2 * phase) + h3 * sin(3 * phase)
                            + h4 * sin(4 * phase)) / (1 + h2 + h3 + h4)
                channel[i] += Float(note.level * envelope(t, length: note.length) * wave)
            }
        }
        buffers[signal] = buffer
        return buffer
    }

    /// Short attack, soft decay, and a fade at the end. Both ends count as
    /// much as the middle: a note that starts or stops all at once clicks,
    /// and that click is heard more than the note.
    private func envelope(_ t: Double, length: Double) -> Double {
        let rise = min(1, t / 0.008)
        let decay = exp(-3.2 * t / length)
        let fadeOut = max(0, min(1, (length - t) / 0.03))
        return rise * decay * fadeOut
    }
}
