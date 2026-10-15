import XCTest
@testable import OvertoneCore

final class MusicTheoryTests: XCTestCase {
    func testConcertPitchAndMiddleC() {
        XCTAssertEqual(MusicTheory.frequency(midi: 69), 440, accuracy: 0.000_001)
        XCTAssertEqual(MusicTheory.frequency(midi: 60), 261.625_565, accuracy: 0.000_001)
        XCTAssertEqual(1 / MusicTheory.frequency(midi: 60), 0.003_822_256, accuracy: 0.000_001)
    }

    func testOctavesDoubleAndHalfStepsHaveEqualRatios() {
        for midi in 21...108 {
            XCTAssertEqual(MusicTheory.frequency(midi: midi + 12), 2 * MusicTheory.frequency(midi: midi), accuracy: 0.000_001)
            XCTAssertEqual(MusicTheory.ratio(from: midi, to: midi + 1), pow(2, 1.0 / 12), accuracy: 0.000_001)
        }
        XCTAssertEqual(MusicTheory.ratio(from: 72, to: 60), 0.5, accuracy: 0.000_001)
        XCTAssertNotEqual(MusicTheory.frequency(midi: 61) - MusicTheory.frequency(midi: 60), MusicTheory.frequency(midi: 73) - MusicTheory.frequency(midi: 72))
    }

    func testEqualTemperedChordIsCloseToButDifferentFromSimpleRatios() {
        let third = MusicTheory.ratio(from: 60, to: 64)
        let fifth = MusicTheory.ratio(from: 60, to: 67)
        XCTAssertEqual(third, 1.259_921, accuracy: 0.000_001)
        XCTAssertEqual(fifth, 1.498_307, accuracy: 0.000_001)
        XCTAssertGreaterThan(abs(third - 1.25), 0.001)
        XCTAssertGreaterThan(abs(fifth - 1.5), 0.001)
    }

    func testPianoKeyNamesOctavesAndColor() {
        let middleC = PianoNote(midi: 60)
        XCTAssertEqual(middleC.name, "C4")
        XCTAssertEqual(middleC.letter, "C")
        XCTAssertEqual(middleC.octave, 4)
        XCTAssertEqual(middleC.id, 60)
        XCTAssertFalse(middleC.isBlack)
        XCTAssertEqual(PianoNote(midi: 61).name, "C♯4")
        XCTAssertTrue(PianoNote(midi: 61).isBlack)
        XCTAssertEqual(PianoNote(midi: 59).name, "B3")
        XCTAssertEqual(PianoNote(midi: 0).name, "C-1")
        XCTAssertEqual(PianoNote(midi: -1).name, "B-2")
        XCTAssertTrue(PianoNote(midi: 61).accessibleName.contains("C sharp"))
        XCTAssertTrue(middleC.accessibleName.contains("261.6 hertz"))
    }

    func testWhiteNotesIncludeNextCAndScaleStepPattern() {
        let notes = MusicTheory.whiteNotes(octave: 4)
        XCTAssertEqual(notes.map(\.midi), [60, 62, 64, 65, 67, 69, 71, 72])
        XCTAssertTrue(notes.allSatisfy { !$0.isBlack })
        XCTAssertEqual(zip(notes, notes.dropFirst()).map { $1.midi - $0.midi }, [2, 2, 1, 2, 2, 2, 1])
    }

    func testIntervalNamesIncludingDescendingAndCompoundIntervals() {
        XCTAssertEqual(MusicTheory.intervalName(semitones: 0), "unison")
        XCTAssertEqual(MusicTheory.intervalName(semitones: 4), "major third")
        XCTAssertEqual(MusicTheory.intervalName(semitones: -7), "perfect fifth")
        XCTAssertEqual(MusicTheory.intervalName(semitones: 12), "octave")
        XCTAssertEqual(MusicTheory.intervalName(semitones: 24), "2 octaves")
        XCTAssertEqual(MusicTheory.intervalName(semitones: 25), "25 semitones")
    }

    func testWaveformsAreFiniteBoundedPeriodicAndDistinct() {
        for tone in ToneColor.allCases {
            for step in -2000...2000 {
                let phase = Double(step) * 0.037
                let sample = MusicTheory.sample(phase: phase, tone: tone)
                XCTAssertTrue(sample.isFinite)
                XCTAssertLessThanOrEqual(abs(sample), 1.000_001)
                XCTAssertEqual(sample, MusicTheory.sample(phase: phase + 2 * .pi, tone: tone), accuracy: 0.000_001)
            }
            XCTAssertEqual(MusicTheory.sample(phase: .infinity, tone: tone), 0)
            XCTAssertEqual(MusicTheory.sample(phase: .nan, tone: tone), 0)
            XCTAssertTrue(MusicTheory.sample(phase: Double.greatestFiniteMagnitude, tone: tone).isFinite)
        }
        XCTAssertEqual(MusicTheory.sample(phase: .pi / 2, tone: .pure), 1, accuracy: 0.000_001)
        XCTAssertNotEqual(MusicTheory.sample(phase: .pi / 4, tone: .pure), MusicTheory.sample(phase: .pi / 4, tone: .piano))
        XCTAssertEqual(MusicTheory.harmonicAmplitudes(tone: .pure), [1])
        XCTAssertGreaterThan(MusicTheory.harmonicAmplitudes(tone: .piano).count, 1)
    }
}
