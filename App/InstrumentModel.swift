import SwiftUI
import Observation
import OvertoneCore

enum InstrumentTab: String, CaseIterable {
    case learn = "Learn", lab = "Lab", practice = "Practice"
}

@MainActor @Observable
final class InstrumentModel {
    var tab: InstrumentTab = .learn {
        didSet { if tab != oldValue { silence(); sensory.selection() } }
    }
    var octave = 4
    var held: Set<Int> = []
    var latched: Set<Int> = []
    var demoNotes: Set<Int> = []
    var lastNote: Int?
    var keepNotes = false {
        didSet { if !keepNotes { releaseLatched() } }
    }
    var showLabels = true
    var selectedLesson = 0
    var session = LessonSession(lesson: Lesson.curriculum[0])
    var learned: Set<Int>
    var showingJourney = false
    var showingSettings = false
    var showingWhy = false
    var explanationLesson: Lesson?
    var isDemonstrating = false
    var metronomeOn = false
    var bpm = 80.0
    var beatIndex = -1
    var earTarget: Int?
    var earMessage = "Listen to a hidden note, then find it on the keys."
    var earWins = 0
    var earAttempts = 0
    var sensory = PianoSensory()
    @ObservationIgnored private var demoTask: Task<Void, Never>?
    @ObservationIgnored private var beatTask: Task<Void, Never>?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        let storage = CommandLine.arguments.contains("--uitesting") ? UserDefaults(suiteName: "com.utkarsh.overtone.ui-tests")! : defaults
        if CommandLine.arguments.contains("--reset-ui-state") { storage.removePersistentDomain(forName: "com.utkarsh.overtone.ui-tests") }
        self.defaults = storage
        learned = Set(storage.array(forKey: "learnedLessons") as? [Int] ?? [])
        sensory.soundEnabled = storage.object(forKey: "sound") as? Bool ?? true
        sensory.hapticsEnabled = storage.object(forKey: "haptics") as? Bool ?? true
        sensory.hapticStrength = storage.object(forKey: "hapticStrength") as? Double ?? 0.65
        sensory.continuousFeelEnabled = storage.object(forKey: "continuousFeel") as? Bool ?? true
        sensory.volume = storage.object(forKey: "volume") as? Double ?? 0.65
        showLabels = storage.object(forKey: "showLabels") as? Bool ?? true
        let resume = storage.integer(forKey: "lesson")
        selectedLesson = min(max(resume, 0), Lesson.curriculum.count - 1)
        session = LessonSession(lesson: Lesson.curriculum[selectedLesson])
    }

    var lesson: Lesson { Lesson.curriculum[selectedLesson] }
    var visualNotes: [Int] {
        let sounding = held.union(latched).union(demoNotes).sorted()
        if !sounding.isEmpty { return Array(sounding.prefix(4)) }
        return lastNote.map { [$0] } ?? []
    }
    var heldVoiceCount: Int { held.union(latched).union(demoNotes).count }
    var highlights: Set<Int> {
        guard tab == .learn, !session.completed else { return [] }
        if case .sequence(let notes) = lesson.exercise {
            return session.sequenceIndex < notes.count ? [notes[session.sequenceIndex]] : []
        }
        return Set(lesson.targetNotes)
    }
    var hiddenReference: Bool { tab == .practice && isDemonstrating }

    func keyDown(_ midi: Int) {
        guard (21...108).contains(midi) else { return }
        if isDemonstrating { cancelDemo() }
        held.insert(midi)
        if keepNotes && tab == .lab { latched.insert(midi) }
        lastNote = midi
        sensory.noteOn(midi)
        if tab == .learn {
            let wasComplete = session.completed
            session.noteOn(midi, held: held, time: ProcessInfo.processInfo.systemUptime)
            if case .compareTimbres = lesson.exercise, midi == 60 { session.compareTimbre(sensory.tone) }
            recordCompletion(wasComplete: wasComplete)
        } else if tab == .practice, let target = earTarget {
            earAttempts += 1
            if midi == target {
                earWins += 1
                earMessage = "You found \(PianoNote(midi: midi).name). Listen for the next note."
                earTarget = nil
                sensory.success()
            } else {
                earMessage = midi < target ? "Your note is lower. Try a key to the right." : "Your note is higher. Try a key to the left."
            }
        }
    }

    func keyUp(_ midi: Int) {
        held.remove(midi)
        if !latched.contains(midi) { sensory.noteOff(midi) }
        if tab == .learn {
            let wasComplete = session.completed
            session.heldNotesChanged(held)
            recordCompletion(wasComplete: wasComplete)
        }
    }

    func selectLesson(_ index: Int) {
        silence()
        selectedLesson = min(max(index, 0), Lesson.curriculum.count - 1)
        session = LessonSession(lesson: lesson)
        octave = 4
        sensory.sustain = false
        keepNotes = false
        if case .compareTimbres = lesson.exercise { sensory.tone = .pure }
        defaults.set(selectedLesson, forKey: "lesson")
        showingJourney = false
        tab = .learn
        sensory.selection()
    }

    func changeTone(_ tone: ToneColor) {
        silence()
        sensory.tone = tone
        sensory.selection()
    }

    func nextLesson() { selectLesson((selectedLesson + 1) % Lesson.curriculum.count) }
    func retryLesson() { silence(); session.reset() }
    func setOctave(_ value: Int) {
        silence()
        octave = min(7, max(0, value))
        sensory.selection()
    }
    func releaseLatched() {
        for midi in latched where !held.contains(midi) { sensory.noteOff(midi) }
        latched.removeAll()
    }
    func saveSettings() {
        defaults.set(sensory.soundEnabled, forKey: "sound")
        defaults.set(sensory.hapticsEnabled, forKey: "haptics")
        defaults.set(sensory.hapticStrength, forKey: "hapticStrength")
        defaults.set(sensory.continuousFeelEnabled, forKey: "continuousFeel")
        defaults.set(sensory.volume, forKey: "volume")
        defaults.set(showLabels, forKey: "showLabels")
    }
    private func recordCompletion(wasComplete: Bool) {
        guard session.completed, !wasComplete else { return }
        learned.insert(lesson.id)
        defaults.set(Array(learned), forKey: "learnedLessons")
        sensory.success()
    }

    func demonstrateLesson() {
        if case .rhythm(_, let tempo) = lesson.exercise {
            bpm = tempo
            toggleMetronome()
            return
        }
        var notes = lesson.targetNotes
        if notes.isEmpty { notes = [60] }
        let chord: Bool
        if case .chord = lesson.exercise { chord = true } else { chord = false }
        demonstrate(notes, together: chord)
    }

    func demonstrate(_ notes: [Int], together: Bool = false, hidden: Bool = false) {
        cancelDemo()
        sensory.allNotesOff()
        held.removeAll(); latched.removeAll()
        isDemonstrating = true
        demoTask = Task { [weak self] in
            guard let self else { return }
            if together {
                if !hidden { demoNotes = Set(notes); lastNote = notes.first }
                for note in notes { sensory.noteOn(note) }
                try? await Task.sleep(for: .seconds(1.3))
                if !Task.isCancelled { for note in notes { sensory.noteOff(note) } }
            } else {
                for note in notes {
                    if Task.isCancelled { break }
                    if !hidden { demoNotes = [note]; lastNote = note }
                    sensory.noteOn(note)
                    try? await Task.sleep(for: .seconds(0.42))
                    if Task.isCancelled { break }
                    sensory.noteOff(note)
                    demoNotes.removeAll()
                    try? await Task.sleep(for: .seconds(0.12))
                }
            }
            if !Task.isCancelled { demoNotes.removeAll(); isDemonstrating = false }
        }
    }

    func newEarChallenge() {
        silence()
        octave = 4
        earTarget = [60,62,64,65,67].randomElement()!
        earMessage = "Find the note you just heard. Start anywhere; follow your ear."
        demonstrate([earTarget!], hidden: true)
    }
    func replayEar() {
        guard let target = earTarget else { newEarChallenge(); return }
        demonstrate([target], hidden: true)
    }
    func toggleMetronome() {
        if metronomeOn { stopMetronome(); return }
        metronomeOn = true
        beatTask = Task { [weak self] in
            guard let self else { return }
            var next = ProcessInfo.processInfo.systemUptime
            beatIndex = -1
            while !Task.isCancelled {
                beatIndex = (beatIndex + 1) % 4
                sensory.beat(accent: beatIndex == 0)
                next += 60 / bpm
                let delay = max(0.001, next - ProcessInfo.processInfo.systemUptime)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }
    func stopMetronome() {
        beatTask?.cancel(); beatTask = nil
        metronomeOn = false; beatIndex = -1
    }
    func cancelDemo() {
        demoTask?.cancel(); demoTask = nil
        for note in demoNotes { sensory.noteOff(note) }
        // A hidden reference has no visual notes.
        if isDemonstrating { sensory.allNotesOff() }
        demoNotes.removeAll(); isDemonstrating = false
    }
    func silence() {
        cancelDemo(); stopMetronome()
        held.removeAll(); latched.removeAll()
        sensory.allNotesOff()
    }
    func suspend() { silence(); sensory.suspend() }
}
