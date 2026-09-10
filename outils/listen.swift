//
//  listen.swift
//  Riskelo US — tool, outside the app
//
//  The sounds, written out to files so they can be listened to.
//
//  A score reads, it does not sound: "an arpeggio rising over an octave and a
//  half" says nothing about what the speaker will make of it. This tool
//  renders the six signals as they are and drops them on disk, enough to
//  decide by ear before deciding in the code.
//
//  It copies out no notes: it calls `Sounds.render`, which is to say the same
//  computation the app uses. A sound approved here is the sound you will hear
//  while playing.
//
//  It also measures the peak of each mix. Several notes sounding together add
//  up, and past 1 the sound stops rising: it clips, and that clipping is
//  heard more than the chord. Better read here than in the listening.
//
//      swiftc -O -parse-as-library -o /tmp/listen Sources/UI/Sounds.swift outils/listen.swift && /tmp/listen
//

import AVFoundation

@main
enum Listen {

    static let signals: [(String, Sounds.Signal)] = [
        ("1-opening", .opening),
        ("2-place", .place),
        ("3-exchange-won", .won),
        ("4-exchange-lost", .lost),
        ("5-VICTORY", .victory),
        ("6-DEFEAT", .defeat),
    ]

    @MainActor
    static func main() {
        let folder = URL(fileURLWithPath: "/tmp/riskelo-us-sounds")
        try? FileManager.default.createDirectory(at: folder,
                                                 withIntermediateDirectories: true)
        for (name, signal) in signals {
            guard let buffer = Sounds.shared.render(signal) else {
                print("  \(name) — could not render"); continue
            }
            let url = folder.appendingPathComponent("\(name).wav")
            try? FileManager.default.removeItem(at: url)
            do {
                let file = try AVAudioFile(forWriting: url, settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: 44_100.0,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false,
                ])
                try file.write(from: buffer)
            } catch {
                print("  \(name) — could not write: \(error)"); continue
            }
            let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
            let top = peak(buffer)
            let column = name.padding(toLength: 18, withPad: " ", startingAt: 0)
            print(String(format: "  %@%5.2f s   peak %.2f %@", column, seconds,
                         top, top >= 1 ? "⚠️ clipped" : ""))
        }
        print("\nIn \(folder.path)")
    }

    /// The loudest sample in the mix, in absolute value.
    static func peak(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        var top: Float = 0
        for i in 0 ..< Int(buffer.frameLength) { top = max(top, abs(channel[i])) }
        return top
    }
}
