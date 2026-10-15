import Foundation

/// A lesson's interaction state. It is independent of audio, UI, and device haptics.
public struct LessonSession: Sendable {
    public let lesson: Lesson
    public private(set) var progress: Double = 0
    public private(set) var completed = false
    public private(set) var message: String
    public private(set) var sequenceIndex = 0

    private var heardTimbres: Set<ToneColor> = []
    private var lastBeatTime: Double?

    public init(lesson: Lesson) {
        self.lesson = lesson
        message = lesson.prompt
    }

    public mutating func reset() {
        progress = 0
        completed = false
        sequenceIndex = 0
        heardTimbres = []
        lastBeatTime = nil
        message = lesson.prompt
    }

    /// `held` is the set of sounding keys including this newly pressed key.
    /// `time` is a monotonic timestamp in seconds, used only for rhythmic exercises.
    public mutating func noteOn(_ midi: Int, held: Set<Int>, time: Double) {
        guard !completed else { return }
        switch lesson.exercise {
        case .anyNote:
            finish()

        case let .sequence(notes):
            guard !notes.isEmpty else { finish(); return }
            guard sequenceIndex < notes.count else { return }
            let expected = notes[sequenceIndex]
            guard midi == expected else {
                message = "You played \(PianoNote(midi: midi).name). Try \(PianoNote(midi: expected).name) next. Take your time."
                return
            }
            sequenceIndex += 1
            progress = Double(sequenceIndex) / Double(notes.count)
            if sequenceIndex == notes.count {
                finish()
            } else {
                message = "Heard \(PianoNote(midi: midi).name). Next: \(PianoNote(midi: notes[sequenceIndex]).name)."
            }

        case .chord:
            heldNotesChanged(held)

        case .compareTimbres:
            message = heardTimbres.isEmpty
                ? "Play a key with each sound color: Pure and Piano."
                : "Now switch sound color and play a key to compare."

        case let .rhythm(count, bpm):
            receiveBeat(time: time, count: count, bpm: bpm)
        }
    }

    /// Reevaluate a chord after keys are pressed or released. Other exercise types ignore this.
    public mutating func heldNotesChanged(_ held: Set<Int>) {
        guard !completed, case let .chord(notes) = lesson.exercise else { return }
        let target = Set(notes)
        guard !target.isEmpty else { finish(); return }
        let matching = held.intersection(target)
        progress = Double(matching.count) / Double(target.count)
        if held == target {
            sequenceIndex = target.count
            finish()
        } else if !held.subtracting(target).isEmpty {
            // Keep progress below completion until only the intended chord sounds.
            progress = min(progress, 0.99)
            let extras = held.subtracting(target).sorted().map { PianoNote(midi: $0).name }.joined(separator: ", ")
            message = "Release \(extras). Hold just \(noteList(notes)) together."
        } else if held.isEmpty {
            message = lesson.prompt
        } else {
            let missing = target.subtracting(held).sorted().map { PianoNote(midi: $0).name }.joined(separator: " and ")
            message = "Keep those keys held. Add \(missing) to sound the chord together."
        }
    }

    /// Call after a note is sounded with this timbre; merely changing a setting should not count.
    public mutating func compareTimbre(_ tone: ToneColor) {
        guard !completed, case .compareTimbres = lesson.exercise else { return }
        heardTimbres.insert(tone)
        progress = Double(heardTimbres.count) / Double(ToneColor.allCases.count)
        sequenceIndex = heardTimbres.count
        if heardTimbres.count == ToneColor.allCases.count {
            finish()
        } else {
            let next = tone == .pure ? "Piano" : "Pure"
            message = "Heard \(tone == .pure ? "Pure" : "Piano"). Switch to \(next) and play a key."
        }
    }

    private mutating func receiveBeat(time: Double, count: Int, bpm: Double) {
        guard count > 0, bpm.isFinite, bpm > 0, time.isFinite else {
            message = "A steady pulse needs a positive tempo and a valid time."
            return
        }
        let beatDuration = 60 / bpm
        let tolerance = min(beatDuration * 0.22, 0.18)
        if let previous = lastBeatTime {
            let gap = time - previous
            guard gap > 0 else { return }
            if abs(gap - beatDuration) > tolerance {
                sequenceIndex = 1
                progress = 1 / Double(count)
                lastBeatTime = time
                message = gap < beatDuration
                    ? "A little quick. This tap starts again: leave one full beat before the next."
                    : "A little slow. This tap starts again: tap once on each beat."
                return
            }
        }
        lastBeatTime = time
        sequenceIndex += 1
        progress = min(1, Double(sequenceIndex) / Double(count))
        if sequenceIndex >= count {
            finish()
        } else {
            message = "Beat \(sequenceIndex) of \(count). Keep the same steady gap."
        }
    }

    private mutating func finish() {
        completed = true
        progress = 1
        message = lesson.insight
    }

    private func noteList(_ notes: [Int]) -> String {
        notes.map { PianoNote(midi: $0).name }.joined(separator: ", ")
    }
}
