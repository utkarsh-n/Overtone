import AVFoundation
import Foundation
import OvertoneCore
import os

/// Main-thread input is copied only when the render thread can take this lock
/// immediately. A missed copy costs one audio quantum, never a blocked callback.
final class SynthControlMailbox: @unchecked Sendable {
    static let keyCount = 88
    private let lock = UnsafeMutablePointer<os_unfair_lock_s>.allocate(capacity: 1)
    private let keys = UnsafeMutablePointer<SynthKeyState>.allocate(capacity: keyCount)
    private var volume: Double = 0.65
    private var sustain = false
    private var silenceSerial: UInt64 = 0
    private var beatSerial: UInt64 = 0
    private var beatAccent = false

    init() {
        lock.initialize(to: os_unfair_lock_s())
        keys.initialize(repeating: SynthKeyState(), count: Self.keyCount)
    }

    deinit {
        keys.deinitialize(count: Self.keyCount)
        keys.deallocate()
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func noteOn(_ midi: Int, velocity: Double, tone: ToneColor) {
        os_unfair_lock_lock(lock)
        let index = midi - 21
        keys[index].serial &+= 1
        keys[index].held = true
        keys[index].velocity = velocity
        keys[index].tone = tone == .pure ? 1 : 0
        os_unfair_lock_unlock(lock)
    }

    func noteOff(_ midi: Int) {
        os_unfair_lock_lock(lock)
        let index = midi - 21
        keys[index].serial &+= 1
        keys[index].held = false
        os_unfair_lock_unlock(lock)
    }

    func setVolume(_ value: Double) {
        os_unfair_lock_lock(lock)
        volume = value
        os_unfair_lock_unlock(lock)
    }

    func setSustain(_ value: Bool) {
        os_unfair_lock_lock(lock)
        sustain = value
        os_unfair_lock_unlock(lock)
    }

    func clear() {
        os_unfair_lock_lock(lock)
        silenceSerial &+= 1
        for index in 0..<Self.keyCount { keys[index].held = false }
        os_unfair_lock_unlock(lock)
    }

    func beat(accent: Bool) {
        os_unfair_lock_lock(lock)
        beatSerial &+= 1
        beatAccent = accent
        os_unfair_lock_unlock(lock)
    }

    func copyIfAvailable(to snapshot: UnsafeMutablePointer<SynthKeyState>, controls: inout SynthControls) {
        guard os_unfair_lock_trylock(lock) else { return }
        snapshot.update(from: keys, count: Self.keyCount)
        controls.volume = volume
        controls.sustain = sustain
        controls.silenceSerial = silenceSerial
        controls.beatSerial = beatSerial
        controls.beatAccent = beatAccent
        os_unfair_lock_unlock(lock)
    }
}

struct SynthKeyState {
    var serial: UInt64 = 0
    var held = false
    var velocity = 0.75
    var tone: UInt8 = 0
}

struct SynthControls {
    var volume = 0.65
    var sustain = false
    var silenceSerial: UInt64 = 0
    var beatSerial: UInt64 = 0
    var beatAccent = false
}

private struct SynthVoice {
    var active = false
    var midi = 0
    var age: UInt64 = 0
    var envelope = 0.0
    var attackStep = 0.0
    var releaseMultiplier = 1.0
    var releasing = false
    var velocity = 0.75
    var lifetimeFrames = 0
    var piano = true
}

private struct SynthPartial {
    var sine = 0.0
    var cosine = 1.0
    var sineStep = 0.0
    var cosineStep = 1.0
    var amplitude = 0.0
    var decayMultiplier = 1.0
}

/// Bounded, allocation-free additive synthesis. The audio callback exclusively
/// owns voices and oscillators; the only shared object is the input mailbox.
final class PianoSynthKernel: @unchecked Sendable {
    static let maximumVoices = 32
    private static let partialCount = 8
    private let sampleRate: Double
    private let mailbox: SynthControlMailbox
    private let keys = UnsafeMutablePointer<SynthKeyState>.allocate(capacity: SynthControlMailbox.keyCount)
    private let observedSerials = UnsafeMutablePointer<UInt64>.allocate(capacity: SynthControlMailbox.keyCount)
    private let voices = UnsafeMutablePointer<SynthVoice>.allocate(capacity: maximumVoices)
    private let partials = UnsafeMutablePointer<SynthPartial>.allocate(capacity: maximumVoices * partialCount)
    private let pianoAmplitudes = UnsafeMutablePointer<Double>.allocate(capacity: partialCount)
    private var controls = SynthControls()
    private var observedSilenceSerial: UInt64 = 0
    private var previousSustain = false
    private var nextAge: UInt64 = 0
    private var observedBeatSerial: UInt64 = 0
    private var beatSine = 0.0
    private var beatCosine = 1.0
    private var beatSineStep = 0.0
    private var beatCosineStep = 1.0
    private var beatAmplitude = 0.0
    private var beatAttack = 0.0
    private let beatDecay: Double
    private let beatAttackStep: Double
    private var smoothedVolume = 0.65
    private let volumeSmoothing: Double

    init(sampleRate: Double, mailbox: SynthControlMailbox) {
        self.sampleRate = sampleRate
        self.mailbox = mailbox
        volumeSmoothing = 1 - exp(-1 / (0.008 * sampleRate))
        beatDecay = exp(-6.9 / (0.025 * sampleRate))
        beatAttackStep = 1 / (0.002 * sampleRate)
        keys.initialize(repeating: SynthKeyState(), count: SynthControlMailbox.keyCount)
        observedSerials.initialize(repeating: 0, count: SynthControlMailbox.keyCount)
        voices.initialize(repeating: SynthVoice(), count: Self.maximumVoices)
        partials.initialize(repeating: SynthPartial(), count: Self.maximumVoices * Self.partialCount)
        let source = MusicTheory.harmonicAmplitudes(tone: .piano)
        for index in 0..<Self.partialCount {
            pianoAmplitudes.advanced(by: index).initialize(to: index < source.count ? source[index] : 0)
        }
    }

    deinit {
        keys.deinitialize(count: SynthControlMailbox.keyCount)
        keys.deallocate()
        observedSerials.deinitialize(count: SynthControlMailbox.keyCount)
        observedSerials.deallocate()
        voices.deinitialize(count: Self.maximumVoices)
        voices.deallocate()
        partials.deinitialize(count: Self.maximumVoices * Self.partialCount)
        partials.deallocate()
        pianoAmplitudes.deinitialize(count: Self.partialCount)
        pianoAmplitudes.deallocate()
    }

    func render(isSilence: UnsafeMutablePointer<ObjCBool>, frameCount: AVAudioFrameCount,
                audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        mailbox.copyIfAvailable(to: keys, controls: &controls)
        applyCommands()
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        var hasOutput = false

        for frame in 0..<Int(frameCount) {
            smoothedVolume += (controls.volume - smoothedVolume) * volumeSmoothing
            var sample = 0.0
            if beatAmplitude > 0.00001 {
                beatAttack = min(1, beatAttack + beatAttackStep)
                sample += beatSine * beatAmplitude * beatAttack
                let nextSine = beatSine * beatCosineStep + beatCosine * beatSineStep
                beatCosine = beatCosine * beatCosineStep - beatSine * beatSineStep
                beatSine = nextSine
                beatAmplitude *= beatDecay
            }
            for voiceIndex in 0..<Self.maximumVoices where voices[voiceIndex].active {
                var voice = voices[voiceIndex]
                if voice.releasing {
                    voice.envelope *= voice.releaseMultiplier
                } else {
                    voice.envelope = min(1, voice.envelope + voice.attackStep)
                }
                var noteSample = 0.0
                var amplitudeRemaining = 0.0
                let offset = voiceIndex * Self.partialCount
                for partialIndex in 0..<Self.partialCount {
                    var partial = partials[offset + partialIndex]
                    if partial.amplitude > 0.000001 {
                        noteSample += partial.sine * partial.amplitude
                        amplitudeRemaining += partial.amplitude
                        let nextSine = partial.sine * partial.cosineStep + partial.cosine * partial.sineStep
                        partial.cosine = partial.cosine * partial.cosineStep - partial.sine * partial.sineStep
                        partial.sine = nextSine
                        partial.amplitude *= partial.decayMultiplier
                        partials[offset + partialIndex] = partial
                    }
                }
                // Fixed headroom preserves the sine's shape for ordinary playing.
                sample += noteSample * voice.envelope * voice.velocity * 0.11
                voice.lifetimeFrames += 1
                if voice.envelope < 0.0001 && voice.releasing || amplitudeRemaining < 0.00005 {
                    voice.active = false
                } else if voice.piano && !voice.releasing && voice.lifetimeFrames > Int(sampleRate * 16) {
                    release(&voice, seconds: 0.08)
                }
                voices[voiceIndex] = voice
            }
            let output = Float(max(-0.97, min(0.97, sample * smoothedVolume)))
            hasOutput = hasOutput || abs(output) > 0.000001
            for buffer in buffers {
                guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                let channels = Int(buffer.mNumberChannels)
                for channel in 0..<channels { data[frame * channels + channel] = output }
            }
        }
        isSilence.pointee = ObjCBool(!hasOutput)
        return noErr
    }

    private func applyCommands() {
        if observedSilenceSerial != controls.silenceSerial {
            observedSilenceSerial = controls.silenceSerial
            beatAmplitude = 0
            for index in 0..<Self.maximumVoices where voices[index].active {
                release(&voices[index], seconds: 0.012)
            }
        }
        if observedBeatSerial != controls.beatSerial {
            observedBeatSerial = controls.beatSerial
            let step = 2 * Double.pi * (controls.beatAccent ? 1_600 : 1_100) / sampleRate
            beatSine = 0
            beatCosine = 1
            beatSineStep = sin(step)
            beatCosineStep = cos(step)
            beatAmplitude = controls.beatAccent ? 0.25 : 0.16
            beatAttack = 0
        }
        for keyIndex in 0..<SynthControlMailbox.keyCount {
            let key = keys[keyIndex]
            let midi = keyIndex + 21
            if observedSerials[keyIndex] != key.serial {
                observedSerials[keyIndex] = key.serial
                if key.held {
                    for index in 0..<Self.maximumVoices where voices[index].active && voices[index].midi == midi {
                        release(&voices[index], seconds: 0.012)
                    }
                    startVoice(midi: midi, velocity: key.velocity, piano: key.tone == 0)
                } else if !controls.sustain {
                    for index in 0..<Self.maximumVoices where voices[index].active && voices[index].midi == midi {
                        release(&voices[index], seconds: voices[index].piano ? 0.11 : 0.035)
                    }
                }
            }
        }
        if previousSustain && !controls.sustain {
            for index in 0..<Self.maximumVoices where voices[index].active {
                if !keys[voices[index].midi - 21].held {
                    release(&voices[index], seconds: voices[index].piano ? 0.11 : 0.035)
                }
            }
        }
        previousSustain = controls.sustain
    }

    private func startVoice(midi: Int, velocity: Double, piano: Bool) {
        var selected = 0
        var oldestAge = UInt64.max
        for index in 0..<Self.maximumVoices {
            if !voices[index].active { selected = index; break }
            if voices[index].age < oldestAge { selected = index; oldestAge = voices[index].age }
        }
        nextAge &+= 1
        var voice = SynthVoice()
        voice.active = true
        voice.midi = midi
        voice.age = nextAge
        voice.velocity = velocity
        voice.piano = piano
        voice.attackStep = 1 / (sampleRate * 0.004)
        voices[selected] = voice

        let frequency = MusicTheory.frequency(midi: midi)
        var normalization = 0.0
        for index in 0..<Self.partialCount {
            let partialFrequency = frequency * Double(index + 1)
            let amplitude = piano ? pianoAmplitudes[index] : (index == 0 ? 1.0 : 0.0)
            if partialFrequency < sampleRate * 0.45 { normalization += amplitude }
        }
        let offset = selected * Self.partialCount
        for index in 0..<Self.partialCount {
            let partialFrequency = frequency * Double(index + 1)
            let amplitude = piano ? pianoAmplitudes[index] : (index == 0 ? 1.0 : 0.0)
            let phaseStep = 2 * Double.pi * partialFrequency / sampleRate
            var partial = SynthPartial()
            partial.sineStep = sin(phaseStep)
            partial.cosineStep = cos(phaseStep)
            partial.amplitude = partialFrequency < sampleRate * 0.45 ? amplitude / max(0.0001, normalization) : 0
            // Upper partials fade sooner after a strike, as on a piano string.
            // This is a synthesized timbre, not a recording of an acoustic piano.
            let decayRate = (0.65 + Double(midi - 21) / 87 * 1.25) * (1 + Double(index) * 0.48)
            partial.decayMultiplier = piano ? exp(-decayRate / sampleRate) : 1
            partials[offset + index] = partial
        }
    }

    private func release(_ voice: inout SynthVoice, seconds: Double) {
        voice.releasing = true
        voice.releaseMultiplier = exp(-6.9 / (seconds * sampleRate))
    }
}
