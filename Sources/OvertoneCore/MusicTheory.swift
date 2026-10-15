import Foundation

/// The app's two sound recipes. Both use the same fundamental pitch.
public enum ToneColor: String, CaseIterable, Sendable {
    case piano
    case pure
}

/// A piano key described by its MIDI number, using A4 = 440 Hz tuning.
public struct PianoNote: Identifiable, Hashable, Sendable {
    public let midi: Int

    public init(midi: Int) {
        self.midi = midi
    }

    public var id: Int { midi }
    public var octave: Int { Int(floor(Double(midi) / 12)) - 1 }
    public var frequency: Double { MusicTheory.frequency(midi: midi) }

    private var pitchClass: Int { ((midi % 12) + 12) % 12 }

    public var letter: String {
        ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"][pitchClass]
    }

    public var name: String { "\(letter)\(octave)" }

    public var isBlack: Bool { [1, 3, 6, 8, 10].contains(pitchClass) }

    public var accessibleName: String {
        let spokenLetter = letter.replacingOccurrences(of: "♯", with: " sharp")
        return "\(spokenLetter), octave \(octave), \(String(format: "%.1f", frequency)) hertz"
    }
}

public enum MusicTheory {
    /// The equal-tempered fundamental frequency. Each semitone multiplies Hz by 2^(1/12).
    public static func frequency(midi: Int) -> Double {
        440 * pow(2, (Double(midi) - 69) / 12)
    }

    /// The destination's frequency divided by the starting frequency.
    public static func ratio(from: Int, to: Int) -> Double {
        pow(2, (Double(to) - Double(from)) / 12)
    }

    public static func intervalName(semitones: Int) -> String {
        let distance = semitones == Int.min ? Int.max : abs(semitones)
        let names = [
            "unison", "minor second", "major second", "minor third",
            "major third", "perfect fourth", "tritone", "perfect fifth",
            "minor sixth", "major sixth", "minor seventh", "major seventh",
            "octave", "minor ninth", "major ninth", "minor tenth",
            "major tenth", "perfect eleventh", "augmented eleventh", "perfect twelfth",
            "minor thirteenth", "major thirteenth", "minor fourteenth", "major fourteenth"
        ]
        if distance < names.count { return names[distance] }
        if distance % 12 == 0 { return "\(distance / 12) octaves" }
        return "\(distance) semitones"
    }

    /// The seven white keys in an octave, followed by the C at the next octave.
    public static func whiteNotes(octave: Int) -> [PianoNote] {
        let c = (octave + 1) * 12
        return [0, 2, 4, 5, 7, 9, 11, 12].map { PianoNote(midi: c + $0) }
    }

    /// Relative harmonic strengths; index zero is the fundamental, then 2×, 3×, and so on.
    /// The piano recipe is an illustrative synthesized tone, not an acoustic piano recording.
    public static func harmonicAmplitudes(tone: ToneColor) -> [Double] {
        switch tone {
        case .pure: return [1]
        case .piano: return [1, 0.43, 0.22, 0.12, 0.065, 0.038, 0.019, 0.01]
        }
    }

    /// A normalized additive waveform. Phase is in radians; one cycle is 2π.
    /// The caller supplies the envelope and omits harmonics above the playback Nyquist frequency.
    public static func sample(phase: Double, tone: ToneColor) -> Double {
        guard phase.isFinite else { return 0 }
        let wrappedPhase = phase.truncatingRemainder(dividingBy: 2 * .pi)
        let amplitudes = harmonicAmplitudes(tone: tone)
        let total = amplitudes.reduce(0, +)
        return amplitudes.enumerated().reduce(0) { result, entry in
            result + entry.element * sin(wrappedPhase * Double(entry.offset + 1))
        } / total
    }
}
