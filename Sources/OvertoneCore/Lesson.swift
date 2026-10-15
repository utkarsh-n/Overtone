import Foundation

public enum LessonExercise: Sendable {
    case anyNote
    case sequence([Int])
    case chord([Int])
    case compareTimbres
    case rhythm(count: Int, bpm: Double)
}

public struct Lesson: Identifiable, Sendable {
    public let id: Int
    public let title: String
    public let subtitle: String
    public let body: String
    public let prompt: String
    public let insight: String
    public let exercise: LessonExercise
    public let targetNotes: [Int]

    public init(
        id: Int, title: String, subtitle: String, body: String,
        prompt: String, insight: String, exercise: LessonExercise, targetNotes: [Int]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.prompt = prompt
        self.insight = insight
        self.exercise = exercise
        self.targetNotes = targetNotes
    }

    public static let curriculum: [Lesson] = [
        Lesson(
            id: 0, title: "Sound is motion", subtitle: "Meet one vibration",
            body: "A piano key starts a repeating motion. That motion makes air pressure rise and fall, and your ears hear sound. The moving line shows one possible sound wave. Hertz (Hz) means cycles each second: middle C repeats about 262 times in one second. One cycle takes about 3.8 milliseconds. Your phone's vibration is a separate cue you can feel; it does not reproduce hundreds of pitch cycles per second.",
            prompt: "Touch any key. Listen, watch, and feel its beginning.",
            insight: "A sound has a repeating pattern. Frequency counts how often that pattern repeats.",
            exercise: .anyNote, targetNotes: []
        ),
        Lesson(
            id: 1, title: "Higher means faster", subtitle: "Find pitch with your ears",
            body: "Pitch is how high or low a sound seems. A faster repeating wave usually sounds higher. C4 is middle C, about 261.6 Hz. D4 is about 293.7 Hz. The letter is a note's name; the number says which octave it lives in. Play C4, then D4, and notice that D's cycles fit closer together.",
            prompt: "Play C4, then D4.",
            insight: "A higher note has more cycles per second and a shorter time for each cycle.",
            exercise: .sequence([60, 62]), targetNotes: [60, 62]
        ),
        Lesson(
            id: 2, title: "One small step", subtitle: "White and black keys belong together",
            body: "A semitone, also called a half step, is the distance from one piano key to its nearest neighbor, counting black keys too. C4 → C♯4 → D4 is two half steps. The ♯ symbol says 'sharp': one half step higher. A black key can also have a flat name, meaning one half step lower; C♯ and D♭ name this same key. In this tuning, each half step multiplies frequency by about 1.05946. The gaps in Hz grow as you climb.",
            prompt: "Play C4, C♯4, then D4.",
            insight: "Equal steps on the keyboard are equal frequency ratios, not equal additions of Hz.",
            exercise: .sequence([60, 61, 62]), targetNotes: [60, 61, 62]
        ),
        Lesson(
            id: 3, title: "Twice as fast", subtitle: "Discover the octave",
            body: "Go up twelve half steps from C4 and you arrive at C5. Its frequency is exactly twice as high: about 523.3 Hz. This distance is an octave. The notes sound related, so they share the letter C. The higher C fits two cycles into the time the lower C needs for one. Each octave doubles frequency; moving down an octave halves it.",
            prompt: "Play C4, then C5. Hear their family resemblance.",
            insight: "An octave is a 2:1 frequency ratio, even when the starting note changes.",
            exercise: .sequence([60, 72]), targetNotes: [60, 72]
        ),
        Lesson(
            id: 4, title: "Seven names, one path", subtitle: "Build the C major scale",
            body: "A scale is an ordered set of notes. The C major scale uses C, D, E, F, G, A, B, then the next C—all white keys. Its distances are two, two, one, two, two, two, one half steps. Notice the small gaps at E → F and B → C: there is no black key between them. Start slowly. A phone teaches note locations and listening; an acoustic piano also needs separate practice with posture, touch, and fingering.",
            prompt: "Play C4 D4 E4 F4 G4 A4 B4 C5, in that order.",
            insight: "A scale is a pattern of steps. C major makes that pattern visible on the white keys.",
            exercise: .sequence([60, 62, 64, 65, 67, 69, 71, 72]),
            targetNotes: [60, 62, 64, 65, 67, 69, 71, 72]
        ),
        Lesson(
            id: 5, title: "One pitch, two colors", subtitle: "Hear overtones",
            body: "Two sounds can have the same pitch and still feel different. This sound character is called timbre. Pure sound uses one sine wave. Our piano-like sound adds quieter waves at 2×, 3×, and higher multiples of the fundamental frequency. These are harmonics; the harmonics above the fundamental are overtones. Their strengths shape the waveform and change what you hear. Compare the same key with each sound to keep pitch fixed. This is a synthesized illustration; real piano strings are more complex and their overtones are not perfectly exact multiples.",
            prompt: "Play C4 with Pure sound, then C4 with Piano sound.",
            insight: "Pitch follows the fundamental. The mix of overtones helps give a sound its color.",
            exercise: .compareTimbres, targetNotes: [60]
        ),
        Lesson(
            id: 6, title: "Notes can stack", subtitle: "Make a C major chord",
            body: "A chord is a group of notes sounded together. Hold C4, E4, and G4 to make a C major chord. E is four half steps above C, and G is seven above C. E/C is about 1.260 and G/C about 1.498 in this app's equal temperament. These are close to the simple ratios 5:4 and 3:2, but not exactly equal. Listen to the combined sound and watch each note keep its own frequency.",
            prompt: "Hold C4, E4, and G4 together. Release any extra keys.",
            insight: "A chord combines several pitches at once. Its spacing gives it a recognizable character.",
            exercise: .chord([60, 64, 67]), targetNotes: [60, 64, 67]
        ),
        Lesson(
            id: 7, title: "Change just one note", subtitle: "Major becomes minor",
            body: "Keep C4 and G4, but lower E4 by one half step to E♭4. That black key is also named D♯4 on our keyboard. C, E♭, and G make a C minor chord. The middle note is now three half steps above C instead of four. Many listeners hear a different mood; neither chord must feel happy or sad to everyone. Compare their colors with your own ears.",
            prompt: "Hold C4, D♯4 (E♭4), and G4 together.",
            insight: "Moving one chord tone by one half step changes the relationship between the notes.",
            exercise: .chord([60, 63, 67]), targetNotes: [60, 63, 67]
        ),
        Lesson(
            id: 8, title: "Give sound a heartbeat", subtitle: "Feel a steady pulse",
            body: "Music unfolds in time. A beat is a steady pulse you can follow. Tempo describes how fast that pulse goes, measured in beats per minute (BPM). At 80 BPM there is one beat every 0.75 seconds. Follow the light and optional haptic cue, then tap any key four times with even gaps. Rhythm is the pattern of note starts and lengths around the beat; begin with one note on each beat.",
            prompt: "Tap any key four times, one tap every beat at 80 BPM.",
            insight: "Frequency measures a sound's fast cycles. Tempo measures music's much slower pulse.",
            exercise: .rhythm(count: 4, bpm: 80), targetNotes: [60]
        ),
        Lesson(
            id: 9, title: "A melody you can follow", subtitle: "Play your first phrase",
            body: "A melody is a line of notes played one after another. Try this opening phrase from Beethoven's Ode to Joy: E E F G, G F E D, C C D E, E D D. First learn the note order at your own pace. For a simple practice rhythm, give each note one steady beat and hold the final D for two beats. You have already met the ingredients: vibration, pitch, note names, scales, sound color, chords, and pulse. On a full piano, learn comfortable finger choices with each hand as a separate next step.",
            prompt: "Follow the highlighted notes: E E F G, G F E D, C C D E, E D D.",
            insight: "A melody connects pitch and time. Start with the notes, then add an even pulse.",
            exercise: .sequence([64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62]),
            targetNotes: [64, 64, 65, 67, 67, 65, 64, 62, 60, 60, 62, 64, 64, 62, 62]
        )
    ]
}
