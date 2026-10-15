import AVFoundation
import Foundation
import OvertoneCore

/// Offline checks exercise the same renderer used by AVAudioSourceNode. They
/// need neither a microphone nor a running output device.
@main
@MainActor
struct AudioCheck {
    static let rate = 48_000.0
    static var passed = 0

    static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError("Audio check failed: \(message)") }
        passed += 1
        print("PASS: \(message)")
    }

    static func render(_ kernel: PianoSynthKernel, seconds: Double) -> [Float] {
        let count = Int(rate * seconds)
        var result: [Float] = []
        result.reserveCapacity(count)
        var block = [Float](repeating: 0, count: 256)
        while result.count < count {
            let remaining = min(256, count - result.count)
            block.withUnsafeMutableBytes { bytes in
                var list = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(
                    mNumberChannels: 1, mDataByteSize: UInt32(remaining * MemoryLayout<Float>.stride), mData: bytes.baseAddress
                ))
                var silent = ObjCBool(false)
                let status = kernel.render(isSilence: &silent, frameCount: AVAudioFrameCount(remaining), audioBufferList: &list)
                precondition(status == noErr)
            }
            result.append(contentsOf: block.prefix(remaining))
        }
        return result
    }

    static func rms(_ samples: ArraySlice<Float>) -> Double {
        sqrt(samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count))
    }

    static func amplitude(_ samples: ArraySlice<Float>, frequency: Double) -> Double {
        var sine = 0.0
        var cosine = 0.0
        for (index, sample) in samples.enumerated() {
            let phase = 2 * Double.pi * frequency * Double(index) / rate
            sine += Double(sample) * sin(phase)
            cosine += Double(sample) * cos(phase)
        }
        return 2 * hypot(sine, cosine) / Double(samples.count)
    }

    static func measuredFrequency(_ samples: [Float]) -> Double {
        var crossings: [Double] = []
        for index in 1..<samples.count where samples[index - 1] < 0 && samples[index] >= 0 {
            let previous = Double(samples[index - 1])
            let current = Double(samples[index])
            crossings.append(Double(index - 1) - previous / (current - previous))
        }
        return Double(crossings.count - 1) * rate / (crossings.last! - crossings.first!)
    }

    static func main() {
        for midi in [21, 60, 69, 108] {
            let input = SynthControlMailbox()
            let kernel = PianoSynthKernel(sampleRate: rate, mailbox: input)
            input.noteOn(midi, velocity: 1, tone: .pure)
            let samples = render(kernel, seconds: 1)
            let expected = MusicTheory.frequency(midi: midi)
            let measured = measuredFrequency(samples)
            check(abs(expected - measured) < 0.03, "MIDI \(midi) produces \(String(format: "%.3f", expected)) Hz (measured \(String(format: "%.3f", measured)))")
            check(samples.allSatisfy { $0.isFinite && abs($0) <= 0.97 }, "MIDI \(midi) stays finite and bounded")
        }

        for tone in ToneColor.allCases {
            let input = SynthControlMailbox()
            let kernel = PianoSynthKernel(sampleRate: rate, mailbox: input)
            input.noteOn(69, velocity: 1, tone: tone)
            let samples = render(kernel, seconds: 0.7)
            let segment = samples[4_800..<28_800]
            let fundamental = amplitude(segment, frequency: 440)
            let second = amplitude(segment, frequency: 880)
            if tone == .pure {
                check(second / fundamental < 0.001, "Pure tone contains negligible second harmonic")
            } else {
                check(second / fundamental > 0.1, "Piano recipe contains audible second harmonic")
                let early = rms(samples[4_800..<9_600])
                let late = rms(samples[28_800..<33_600])
                check(late < early * 0.8, "Piano sound decays after its strike")
            }
        }

        let input = SynthControlMailbox()
        let kernel = PianoSynthKernel(sampleRate: rate, mailbox: input)
        input.setSustain(true)
        input.noteOn(69, velocity: 1, tone: .pure)
        _ = render(kernel, seconds: 0.1)
        input.noteOff(69)
        let sustained = render(kernel, seconds: 0.25)
        check(rms(sustained[...]) > 0.04, "Sustain keeps a released key sounding")
        input.setSustain(false)
        let released = render(kernel, seconds: 0.25)
        check(rms(released[7_200..<12_000]) < 0.00001, "Pedal release silences the held tone")

        input.noteOn(60, velocity: 1, tone: .pure)
        input.noteOn(64, velocity: 1, tone: .pure)
        input.noteOn(67, velocity: 1, tone: .pure)
        let chord = render(kernel, seconds: 1)
        for midi in [60, 64, 67] {
            check(amplitude(chord[4_800..<43_200], frequency: MusicTheory.frequency(midi: midi)) > 0.06,
                  "Polyphonic chord retains MIDI \(midi)")
        }
        input.clear()
        let silence = render(kernel, seconds: 0.1)
        check(rms(silence[2_400..<4_800]) < 0.00001, "All notes off overrides sustain and fades to silence")

        // Reproduce a rapid scene reset followed by a key press before rendering.
        input.clear()
        input.noteOn(69, velocity: 1, tone: .pure)
        let restarted = render(kernel, seconds: 0.1)
        check(rms(restarted[2_400..<4_800]) > 0.04, "A key immediately after silence starts correctly")
        input.beat(accent: true)
        let noteWithBeat = render(kernel, seconds: 0.1)
        check(amplitude(noteWithBeat[2_400..<4_800], frequency: 440) > 0.06,
              "An audible metronome beat preserves the held piano key")
        input.clear()
        for midi in 21...108 { input.noteOn(midi, velocity: 1, tone: .piano) }
        let stress = render(kernel, seconds: 0.2)
        check(stress.allSatisfy { $0.isFinite && abs($0) <= 0.97 }, "88 simultaneous commands remain bounded within the 32-voice limit")

        let beatInput = SynthControlMailbox()
        let beatKernel = PianoSynthKernel(sampleRate: rate, mailbox: beatInput)
        beatInput.beat(accent: false)
        let normalBeat = render(beatKernel, seconds: 0.1)
        beatInput.beat(accent: true)
        let accentedBeat = render(beatKernel, seconds: 0.1)
        let normalBeatLevel = rms(normalBeat[0..<480])
        let accentedBeatLevel = rms(accentedBeat[0..<480])
        check(normalBeatLevel > 0.01, "Metronome emits an audible click independently of touch feedback")
        check(accentedBeatLevel > normalBeatLevel * 1.3, "Bar accent is louder than the intervening beats")
        check(rms(accentedBeat[2_400..<4_800]) < 0.00001, "Metronome click decays completely")

        print("\(passed) offline audio checks passed.")
    }
}
