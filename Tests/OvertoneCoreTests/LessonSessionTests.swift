import XCTest
@testable import OvertoneCore

final class LessonSessionTests: XCTestCase {
    func testCurriculumHasTenUniqueLessonsAndBeginsWithoutPrerequisites() {
        XCTAssertEqual(Lesson.curriculum.count, 10)
        XCTAssertEqual(Set(Lesson.curriculum.map(\.id)).count, 10)
        XCTAssertTrue(Lesson.curriculum.allSatisfy { !$0.body.isEmpty && !$0.prompt.isEmpty && !$0.insight.isEmpty })
        var session = LessonSession(lesson: Lesson.curriculum[0])
        XCTAssertFalse(session.completed)
        session.noteOn(57, held: [57], time: 0)
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.progress, 1)
        XCTAssertEqual(session.message, session.lesson.insight)
    }

    func testSequenceRequiresOrderAndWrongNoteDoesNotAdvance() {
        var session = LessonSession(lesson: Lesson.curriculum[2])
        session.noteOn(62, held: [62], time: 0)
        XCTAssertEqual(session.sequenceIndex, 0)
        XCTAssertEqual(session.progress, 0)
        XCTAssertTrue(session.message.contains("Try C4 next"))
        session.noteOn(60, held: [60], time: 1)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertEqual(session.progress, 1.0 / 3, accuracy: 0.000_001)
        session.noteOn(62, held: [62], time: 2)
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertTrue(session.message.contains("C♯4"))
        session.noteOn(61, held: [61], time: 3)
        session.noteOn(62, held: [62], time: 4)
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.sequenceIndex, 3)
    }

    func testRepeatedMelodyNotesRequireSeparateNoteEvents() {
        var session = LessonSession(lesson: Lesson.curriculum[9])
        session.noteOn(64, held: [64], time: 0)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertTrue(session.message.contains("Next: E4"))
        session.noteOn(65, held: [65], time: 1)
        XCTAssertEqual(session.sequenceIndex, 1)
        let melody = [64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62]
        for (index, note) in melody.enumerated() {
            session.noteOn(note, held: [note], time: Double(index + 2))
        }
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.sequenceIndex, 15)
    }

    func testChordCannotBeCompletedBySequentialReleasedNotes() {
        var session = LessonSession(lesson: Lesson.curriculum[6])
        for (time, note) in [60, 64, 67].enumerated() {
            session.noteOn(note, held: [note], time: Double(time))
        }
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.progress, 1.0 / 3, accuracy: 0.000_001)
        session.noteOn(60, held: [60, 67], time: 3)
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.progress, 2.0 / 3, accuracy: 0.000_001)
        session.noteOn(64, held: [60, 64, 67], time: 4)
        XCTAssertTrue(session.completed)
    }

    func testChordRejectsExtraNotesEvenWhenTargetNotesAreHeld() {
        var session = LessonSession(lesson: Lesson.curriculum[7])
        session.noteOn(67, held: [60, 63, 64, 67], time: 0)
        XCTAssertFalse(session.completed)
        XCTAssertLessThan(session.progress, 1)
        XCTAssertTrue(session.message.contains("Release E4"))
        session.noteOn(63, held: [60, 63, 67], time: 1)
        XCTAssertTrue(session.completed)
    }

    func testReleasingExtraChordKeyCompletesWithoutAnotherKeyPress() {
        var session = LessonSession(lesson: Lesson.curriculum[6])
        session.noteOn(67, held: [60, 64, 65, 67], time: 0)
        XCTAssertFalse(session.completed)
        session.heldNotesChanged([60, 64, 67])
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.progress, 1)
        XCTAssertEqual(session.message, session.lesson.insight)
    }

    func testChordReleaseUpdatesProgressButDoesNotCompleteMissingNotes() {
        var session = LessonSession(lesson: Lesson.curriculum[6])
        session.noteOn(64, held: [60, 64], time: 0)
        XCTAssertEqual(session.progress, 2.0 / 3, accuracy: 0.000_001)
        session.heldNotesChanged([60])
        XCTAssertEqual(session.progress, 1.0 / 3, accuracy: 0.000_001)
        XCTAssertFalse(session.completed)
        session.heldNotesChanged([])
        XCTAssertEqual(session.progress, 0)
        XCTAssertEqual(session.message, session.lesson.prompt)
    }

    func testHeldNoteChangesDoNotAdvanceSequenceOrRhythm() {
        for lessonIndex in [1, 8] {
            var session = LessonSession(lesson: Lesson.curriculum[lessonIndex])
            session.heldNotesChanged([60, 64, 67])
            XCTAssertEqual(session.progress, 0)
            XCTAssertEqual(session.sequenceIndex, 0)
            XCTAssertFalse(session.completed)
        }
    }

    func testTimbreComparisonRequiresHearingBothAndDoesNotCountNoteAlone() {
        var session = LessonSession(lesson: Lesson.curriculum[5])
        session.noteOn(60, held: [60], time: 0)
        XCTAssertEqual(session.progress, 0)
        session.compareTimbre(.pure)
        XCTAssertEqual(session.progress, 0.5)
        session.compareTimbre(.pure)
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.progress, 0.5)
        session.compareTimbre(.piano)
        XCTAssertTrue(session.completed)
        var otherSession = LessonSession(lesson: Lesson.curriculum[0])
        otherSession.compareTimbre(.pure)
        XCTAssertFalse(otherSession.completed)
    }

    func testRhythmCompletesOnlyWithSteadyBeatGaps() {
        var session = LessonSession(lesson: Lesson.curriculum[8])
        for time in [10.0, 10.75, 11.5, 12.25] {
            session.noteOn(60, held: [60], time: time)
        }
        XCTAssertTrue(session.completed)
        XCTAssertEqual(session.sequenceIndex, 4)
        XCTAssertEqual(session.progress, 1)
    }

    func testRhythmMistimingStartsFreshAndGivesUsefulFeedback() {
        var session = LessonSession(lesson: Lesson.curriculum[8])
        session.noteOn(60, held: [60], time: 0)
        session.noteOn(60, held: [60], time: 0.75)
        XCTAssertEqual(session.sequenceIndex, 2)
        session.noteOn(60, held: [60], time: 0.85)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertEqual(session.progress, 0.25)
        XCTAssertFalse(session.completed)
        XCTAssertTrue(session.message.contains("quick"))
        session.noteOn(60, held: [60], time: 2)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertTrue(session.message.contains("slow"))
        for time in [2.73, 3.5, 4.25] {
            session.noteOn(60, held: [60], time: time)
        }
        XCTAssertTrue(session.completed)
    }

    func testRhythmRejectsInvalidTimeAndDuplicateEvents() {
        var session = LessonSession(lesson: Lesson.curriculum[8])
        session.noteOn(60, held: [60], time: .nan)
        XCTAssertEqual(session.sequenceIndex, 0)
        session.noteOn(60, held: [60], time: 1)
        session.noteOn(60, held: [60], time: 1)
        session.noteOn(60, held: [60], time: 0.9)
        XCTAssertEqual(session.sequenceIndex, 1)
        XCTAssertFalse(session.completed)
    }

    func testCompletionIsStableAndResetRestoresInitialState() {
        var session = LessonSession(lesson: Lesson.curriculum[1])
        session.noteOn(60, held: [60], time: 0)
        session.noteOn(62, held: [62], time: 1)
        XCTAssertTrue(session.completed)
        let completedMessage = session.message
        session.noteOn(61, held: [61], time: 2)
        XCTAssertEqual(session.message, completedMessage)
        session.reset()
        XCTAssertFalse(session.completed)
        XCTAssertEqual(session.progress, 0)
        XCTAssertEqual(session.sequenceIndex, 0)
        XCTAssertEqual(session.message, session.lesson.prompt)
    }
}
