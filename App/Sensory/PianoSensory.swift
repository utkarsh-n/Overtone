import AVFoundation
import CoreHaptics
import Foundation
import Observation
import OvertoneCore
import UIKit

/// Audio conveys actual pitch; touch conveys the strike's envelope and register.
/// An iPhone's haptic actuator does not vibrate at the note's audio frequency.
@MainActor
@Observable
final class PianoSensory {
    var soundEnabled = true {
        didSet { if !soundEnabled { stopAudio() } }
    }
    var hapticsEnabled = true {
        didSet { if !hapticsEnabled { stopHaptics() } }
    }
    var hapticStrength = 0.65
    var continuousFeelEnabled = true {
        didSet {
            if !continuousFeelEnabled {
                try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
                hapticPlayer = nil
            }
        }
    }
    var volume = 0.65 {
        didSet { mailbox.setVolume(volume.isFinite ? min(1, max(0, volume)) : 0.65) }
    }
    var sustain = false {
        didSet { mailbox.setSustain(sustain) }
    }
    var tone: ToneColor = .piano
    var statusMessage: String?
    let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    @ObservationIgnored private let mailbox = SynthControlMailbox()
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var audioSource: AVAudioSourceNode?
    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private var hapticEngineID: UUID?
    @ObservationIgnored private var hapticPlayer: (any CHHapticPatternPlayer)?
    @ObservationIgnored private var ownsAudioSession = false
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastTouchTime = -Double.infinity
    @ObservationIgnored private let selectionGenerator = UISelectionFeedbackGenerator()
    @ObservationIgnored private let strikeGenerator = UIImpactFeedbackGenerator(style: .soft)
    @ObservationIgnored private let beatGenerator = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let successGenerator = UINotificationFeedbackGenerator()

    init() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil,
                               using: Self.interruptionHandler(for: self)),
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil,
                               using: Self.routeChangeHandler(for: self)),
            center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: nil,
                               using: Self.mediaResetHandler(for: self)),
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil,
                               using: Self.backgroundHandler(for: self)),
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil,
                               using: Self.audioConfigurationHandler(for: self)),
        ]
    }

    isolated deinit {
        audioEngine?.stop()
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticEngine?.stop(completionHandler: nil)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func noteOn(_ midi: Int, velocity: Double = 0.75) {
        guard canPlay, (21...108).contains(midi), velocity.isFinite else { return }
        let strength = min(1, max(0.05, velocity))
        if soundEnabled, prepareAudio() {
            mailbox.noteOn(midi, velocity: strength, tone: tone)
        }
        strikeHaptic(midi: midi, velocity: strength)
    }

    func noteOff(_ midi: Int) {
        guard (21...108).contains(midi) else { return }
        mailbox.noteOff(midi)
    }

    /// Silences sustained notes too, with a short fade to avoid a discontinuity.
    func allNotesOff() {
        mailbox.clear()
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticPlayer = nil
    }

    func selection() {
        guard admitTouch(minimumGap: 0.045) else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    func success() {
        guard admitTouch(minimumGap: 0) else { return }
        successGenerator.notificationOccurred(.success)
        successGenerator.prepare()
    }

    func beat(accent: Bool) {
        guard canPlay else { return }
        if soundEnabled, prepareAudio() { mailbox.beat(accent: accent) }
        if admitTouch(minimumGap: 0.04) {
            beatGenerator.impactOccurred(intensity: (accent ? 0.85 : 0.35) * touchStrength)
            beatGenerator.prepare()
        }
    }

    /// Backgrounding and interruptions discard held notes. Playback resumes
    /// only after the learner presses a key again.
    func suspend() {
        allNotesOff()
        stopAudio()
        stopHaptics()
        lastTouchTime = -Double.infinity
    }

    private var canPlay: Bool { UIApplication.shared.applicationState == .active }

    private func prepareAudio() -> Bool {
        if audioEngine?.isRunning == true { return true }
        // A stopped graph must not carry formerly held notes into a new route.
        if audioEngine != nil { stopAudio() }
        do {
            let session = AVAudioSession.sharedInstance()
            // Deliberately playing an instrument remains audible in silent mode.
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            ownsAudioSession = true

            let sampleRate = session.sampleRate > 0 ? session.sampleRate : 48_000
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
                throw SensoryError.audioFormatUnavailable
            }
            let engine = AVAudioEngine()
            let kernel = PianoSynthKernel(sampleRate: sampleRate, mailbox: mailbox)
            let source = AVAudioSourceNode(format: format) { isSilence, _, count, buffers in
                kernel.render(isSilence: isSilence, frameCount: count, audioBufferList: buffers)
            }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.prepare()
            audioEngine = engine
            audioSource = source
            try engine.start()
            statusMessage = nil
            return true
        } catch {
            stopAudio()
            statusMessage = "Sound is unavailable. Your light and learning cues still work."
            return false
        }
    }

    private func stopAudio() {
        mailbox.clear()
        audioEngine?.stop()
        audioSource = nil
        audioEngine = nil
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }

    private func admitTouch(minimumGap: Double) -> Bool {
        guard hapticsEnabled, touchStrength > 0, canPlay else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastTouchTime >= minimumGap else { return false }
        lastTouchTime = now
        return true
    }

    private var touchStrength: Double {
        hapticStrength.isFinite ? min(1, max(0, hapticStrength)) : 0.65
    }

    private func strikeHaptic(midi: Int, velocity: Double) {
        guard admitTouch(minimumGap: 0.025) else { return }
        guard supportsHaptics else { return }
        do {
            let engine = try prepareHapticEngine()
            try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
            let sharpness = Float(0.12 + Double(midi - 21) / 87 * 0.72)
            let transient = CHHapticEvent(eventType: .hapticTransient, parameters: [
                .init(parameterID: .hapticIntensity, value: Float((0.32 + 0.45 * velocity) * touchStrength)),
                .init(parameterID: .hapticSharpness, value: sharpness),
            ], relativeTime: 0)
            let tail = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                .init(parameterID: .hapticIntensity, value: Float(0.26 * velocity * touchStrength)),
                .init(parameterID: .hapticSharpness, value: sharpness * 0.7),
            ], relativeTime: 0.008, duration: 0.12)
            let envelope = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                .init(relativeTime: 0, value: 1),
                .init(relativeTime: 0.022, value: 0.65),
                .init(relativeTime: 0.07, value: 0.20),
                .init(relativeTime: 0.12, value: 0),
            ], relativeTime: 0.008)
            let pattern = try CHHapticPattern(
                events: continuousFeelEnabled ? [transient, tail] : [transient],
                parameterCurves: continuousFeelEnabled ? [envelope] : []
            )
            let player = try engine.makePlayer(with: pattern)
            hapticPlayer = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            stopHaptics()
            strikeGenerator.impactOccurred(intensity: (0.4 + 0.3 * velocity) * touchStrength)
            strikeGenerator.prepare()
            statusMessage = "Detailed touch feedback is unavailable. Key lights still show each strike."
        }
    }

    private func prepareHapticEngine() throws -> CHHapticEngine {
        if let hapticEngine {
            try hapticEngine.start()
            return hapticEngine
        }
        let engine = try CHHapticEngine()
        let engineID = UUID()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = Self.hapticResetHandler(for: self, engineID: engineID)
        engine.stoppedHandler = Self.hapticStoppedHandler(for: self, engineID: engineID)
        hapticEngine = engine
        hapticEngineID = engineID
        try engine.start()
        return engine
    }

    private func stopHaptics() {
        try? hapticPlayer?.stop(atTime: CHHapticTimeImmediate)
        hapticPlayer = nil
        hapticEngine?.stop(completionHandler: nil)
        hapticEngine = nil
        hapticEngineID = nil
    }

    private enum SensoryError: Error { case audioFormatUnavailable }

    nonisolated private static func interruptionHandler(for owner: PianoSensory) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  rawType == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor [weak owner] in
                owner?.suspend()
                owner?.statusMessage = "Playback paused. Press a key when you are ready."
            }
        }
    }

    nonisolated private static func routeChangeHandler(for owner: PianoSensory) -> @Sendable (Notification) -> Void {
        { [weak owner] notification in
            guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  rawReason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                  rawReason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue ||
                  rawReason == AVAudioSession.RouteChangeReason.routeConfigurationChange.rawValue else { return }
            Task { @MainActor [weak owner] in
                owner?.suspend()
                owner?.statusMessage = "Audio output changed. Press a key to play again."
            }
        }
    }

    nonisolated private static func mediaResetHandler(for owner: PianoSensory) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in owner?.suspend() }
        }
    }

    nonisolated private static func backgroundHandler(for owner: PianoSensory) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in owner?.suspend() }
        }
    }

    nonisolated private static func audioConfigurationHandler(for owner: PianoSensory) -> @Sendable (Notification) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                guard let owner, let engine = owner.audioEngine, !engine.isRunning else { return }
                owner.suspend()
                owner.statusMessage = "Audio output changed. Press a key to play again."
            }
        }
    }

    nonisolated private static func hapticResetHandler(for owner: PianoSensory, engineID: UUID) -> @Sendable () -> Void {
        { [weak owner] in
            Task { @MainActor [weak owner] in
                guard let owner, owner.hapticEngineID == engineID else { return }
                owner.stopHaptics()
            }
        }
    }

    nonisolated private static func hapticStoppedHandler(for owner: PianoSensory, engineID: UUID)
        -> @Sendable (CHHapticEngine.StoppedReason) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                guard let owner, owner.hapticEngineID == engineID else { return }
                owner.hapticPlayer = nil
            }
        }
    }
}
