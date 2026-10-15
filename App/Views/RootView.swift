import SwiftUI
import OvertoneCore

struct RootView: View {
    @Bindable var model: InstrumentModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Overtone").editorialTitle(33)
                    Eyebrow(text: "Sound, made visible")
                }
                Spacer()
                Button { model.showingSettings = true; model.sensory.selection() } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                }
                .buttonStyle(.glass).accessibilityLabel("Sound and touch settings")
                .accessibilityIdentifier("settings")
            }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)

            TabView(selection: $model.tab) {
                Tab("Learn", systemImage: "book.closed", value: .learn) {
                    LearnView(model: model).safeAreaInset(edge: .bottom, spacing: 0) { InstrumentDock(model: model) }
                }
                Tab("Lab", systemImage: "waveform.path", value: .lab) {
                    LabView(model: model).safeAreaInset(edge: .bottom, spacing: 0) { InstrumentDock(model: model) }
                }
                Tab("Practice", systemImage: "ear", value: .practice) {
                    PracticeView(model: model).safeAreaInset(edge: .bottom, spacing: 0) { InstrumentDock(model: model) }
                }
            }
        }
        .background(Palette.ink)
        .sheet(isPresented: $model.showingJourney) { JourneyView(model: model) }
        .sheet(isPresented: $model.showingSettings) { SettingsView(model: model) }
        .sheet(isPresented: $model.showingWhy) { WhyView() }
        .sheet(item: $model.explanationLesson) { LessonDetailView(lesson: $0) }
        .onChange(of: model.sensory.soundEnabled) { _, _ in model.saveSettings() }
        .onChange(of: model.sensory.hapticsEnabled) { _, _ in model.saveSettings() }
        .onChange(of: model.sensory.volume) { _, _ in model.saveSettings() }
        .onChange(of: model.showLabels) { _, _ in model.saveSettings() }
        .onChange(of: model.sensory.hapticStrength) { _, _ in model.saveSettings() }
        .onChange(of: model.sensory.continuousFeelEnabled) { _, _ in model.saveSettings() }
        .onChange(of: model.showingJourney) { _, value in if value { model.silence() } }
        .onChange(of: model.showingSettings) { _, value in if value { model.silence() } }
        .onChange(of: model.showingWhy) { _, value in if value { model.silence() } }
    }
}

struct LearnView: View {
    @Bindable var model: InstrumentModel
    private var introduction: String {
        [
            "A key starts a vibrating sound. Hz means vibrations each second. Touch one and see what changes.",
            "Faster vibration sounds higher. C sits just left of two black keys. Try C, then D, the next white key.",
            "The very next key is a half-step, whether it is white or black. A sharp (♯) means one step higher.",
            "Double a note's frequency and its name repeats. This distance is called an octave.",
            "A scale is a path through notes. Start on C and play the white keys to the next C.",
            "The same pitch can have different textures. Keep C fixed and change the waves inside its sound.",
            "One note is a pitch. Several at once make a chord. Stack C, E, and G with three fingers.",
            "Change one chord note by one small step. Listen to how a new relationship changes the sound.",
            "Pitch tells us which sound. Rhythm tells us when. Hear, see, and feel a pulse, then join it.",
            "A melody is a line of notes. Follow the amber key at your own pace; add rhythm once it feels familiar."
        ][model.selectedLesson]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "Experiment \(String(format: "%02d", model.selectedLesson + 1)) / 10", color: Palette.mint)
                    Spacer()
                    Button { model.showingJourney = true } label: {
                        HStack(spacing: 5) { Text("Journey"); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 12, weight: .medium))
                    }.accessibilityIdentifier("journey")
                }
                VStack(alignment: .leading, spacing: 9) {
                    Text(model.lesson.title).editorialTitle(30)
                        .accessibilityIdentifier("lesson-title")
                    Text(introduction).font(.system(size: 13)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Understand this →") { model.explanationLesson = model.lesson; model.silence() }
                        .font(.system(size: 12)).foregroundStyle(Palette.mint)
                }
                WaveStage(notes: model.visualNotes, tone: model.sensory.tone, isPlaying: !model.held.isEmpty || model.isDemonstrating)
                    .frame(height: 80)
                FrequencyReadout(model: model)
                if model.session.completed {
                    Text(model.lesson.insight).font(.system(size: 14, design: .serif)).foregroundStyle(Palette.mint).labCard(tint: Palette.mint.opacity(0.25))
                }
                if case .compareTimbres = model.lesson.exercise { TonePicker(model: model) }
                if case .rhythm = model.lesson.exercise { BeatControls(model: model) }
                if case .sequence(let notes) = model.lesson.exercise {
                    NoteSequence(notes: notes, index: model.session.sequenceIndex)
                }
                HStack(spacing: 12) {
                    Button { model.demonstrateLesson() } label: {
                        Label(model.isDemonstrating ? "Playing…" : "Hear an example", systemImage: "play.fill")
                    }.buttonStyle(.glass).disabled(model.isDemonstrating)
                        .accessibilityIdentifier("lesson-example")
                    Spacer()
                    Button("Why?") { model.showingWhy = true }.font(.system(size: 13))
                }
                Text(model.lesson.subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24)
        }.background(Palette.ink).scrollIndicators(.hidden)
    }
}

struct MissionCard: View {
    @Bindable var model: InstrumentModel
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: model.session.completed ? "checkmark.circle.fill" : "hand.tap")
                Eyebrow(text: model.session.completed ? "Discovered" : "Your turn", color: model.session.completed ? Palette.mint : Palette.amber)
                Spacer()
                Text("\(Int(model.session.progress * 100))%").font(.system(size: 11, design: .monospaced))
            }.foregroundStyle(model.session.completed ? Palette.mint : Palette.amber)
            Text(model.session.completed ? model.lesson.insight : model.lesson.prompt)
                .font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.session.message).font(.system(size: 12)).foregroundStyle(Palette.muted)
                .accessibilityIdentifier("lesson-feedback")
            ProgressView(value: model.session.progress).tint(model.session.completed ? Palette.mint : Palette.amber)
            if model.session.completed {
                HStack {
                    Button(model.selectedLesson == 9 ? "Revisit from the start" : "Next discovery") { model.nextLesson() }
                        .buttonStyle(.glassProminent).accessibilityIdentifier("next-lesson")
                    Spacer()
                    Button("Again") { model.retryLesson() }.font(.system(size: 12))
                }
            }
        }.labCard(tint: (model.session.completed ? Palette.mint : Palette.amber).opacity(0.4))
    }
}

struct NoteSequence: View {
    var notes: [Int]
    var index: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: "Follow the notes · one at a time")
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(notes.enumerated()), id: \.offset) { offset, midi in
                        VStack(spacing: 5) {
                            Text(PianoNote(midi: midi).letter).font(.system(size: 17, weight: .medium, design: .serif))
                            Image(systemName: offset < index ? "checkmark" : offset == index ? "arrow.down" : "circle.fill")
                                .font(.system(size: 8))
                        }.frame(width: 33, height: 48)
                            .foregroundStyle(offset == index ? Palette.ink : offset < index ? Palette.mint : Palette.muted)
                            .background(offset == index ? Palette.amber : Palette.panel, in: .rect(cornerRadius: 9))
                    }
                }
            }.scrollIndicators(.hidden)
        }
    }
}

struct InstrumentDock: View {
    @Bindable var model: InstrumentModel
    var body: some View {
        VStack(spacing: 10) {
            if model.tab == .learn {
                HStack(spacing: 10) {
                    Image(systemName: model.session.completed ? "checkmark.circle.fill" : "hand.tap")
                        .foregroundStyle(model.session.completed ? Palette.mint : Palette.amber)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.session.message).font(.system(size: 12)).foregroundStyle(Palette.ivory)
                            .accessibilityIdentifier("lesson-feedback")
                        if !model.session.completed { ProgressView(value: model.session.progress).tint(Palette.amber) }
                    }
                    Spacer(minLength: 0)
                    if model.session.completed {
                        Button(model.selectedLesson == 9 ? "Revisit" : "Next") { model.nextLesson() }
                            .buttonStyle(.glassProminent).accessibilityLabel("Next discovery").accessibilityIdentifier("next-lesson")
                    }
                }.padding(.horizontal, 20)
            }
            HStack {
                Button { model.setOctave(model.octave - 1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 32) }
                    .buttonStyle(.glass).disabled(model.octave == 0).accessibilityLabel("Lower octave")
                VStack(spacing: 2) {
                    Text("C\(model.octave) – C\(model.octave + 1)").font(.system(size: 12, weight: .medium, design: .monospaced))
                    if model.octave == 4 { Text("C4 is middle C").font(.system(size: 9)).foregroundStyle(Palette.muted) }
                }.frame(minWidth: 92)
                Button { model.setOctave(model.octave + 1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 32) }
                    .buttonStyle(.glass).disabled(model.octave == 7).accessibilityLabel("Higher octave")
                Spacer(minLength: 4)
                if model.tab == .lab {
                    Button { model.keepNotes.toggle(); model.sensory.selection() } label: {
                        Label("Keep notes", systemImage: model.keepNotes ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                    }.buttonStyle(.glass).tint(model.keepNotes ? Palette.amber : Palette.mint)
                        .accessibilityValue(model.keepNotes ? "On" : "Off")
                } else {
                    Image(systemName: model.sensory.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                        .foregroundStyle(Palette.muted).font(.system(size: 12))
                    Image(systemName: "hand.point.up.left").foregroundStyle(model.sensory.hapticsEnabled ? Palette.mint : Palette.muted)
                        .font(.system(size: 12))
                }
            }.padding(.horizontal, 20)
            PianoKeyboard(octave: model.octave, held: model.held.union(model.latched).union(model.demoNotes),
                          highlighted: model.highlights, showLabels: model.showLabels,
                          onDown: model.keyDown, onUp: model.keyUp)
                .frame(height: 168).padding(.horizontal, 10)
            if let status = model.sensory.statusMessage {
                Text(status).font(.system(size: 10)).foregroundStyle(Palette.amber).padding(.horizontal)
            }
        }.padding(.top, 11).padding(.bottom, 9)
            .background(Palette.ink)
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

struct LabView: View {
    @Bindable var model: InstrumentModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "The living instrument", color: Palette.mint)
                Text(model.visualNotes.count > 1 ? "A relationship you can hear." : "Every key is a frequency.").editorialTitle(33)
                Text("Play freely. Turn on Keep notes to layer sounds with one finger.")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
                WaveStage(notes: model.visualNotes, tone: model.sensory.tone, isPlaying: !model.held.union(model.latched).isEmpty)
                    .frame(height: 170)
                FrequencyReadout(model: model)
                if model.visualNotes.count >= 2 { IntervalCard(notes: model.visualNotes) }
                if model.heldVoiceCount > 4 {
                    Eyebrow(text: "Showing 4 of \(model.heldVoiceCount) held notes")
                }
                TonePicker(model: model)
                HarmonicView(note: model.visualNotes.first ?? 60, tone: model.sensory.tone)
                HStack {
                    Button { model.silence() } label: { Label("Release all", systemImage: "stop.fill") }.buttonStyle(.glass)
                    Spacer()
                    Toggle("Sustain", isOn: $model.sensory.sustain).font(.system(size: 12)).fixedSize()
                }
                Button { model.showingWhy = true } label: { Label("What am I seeing and feeling?", systemImage: "info.circle") }
                    .font(.system(size: 13))
            }.padding(24)
        }.background(Palette.ink).scrollIndicators(.hidden)
    }
}

struct IntervalCard: View {
    var notes: [Int]
    var body: some View {
        let low = notes.min() ?? 60
        let high = notes.max() ?? 60
        VStack(alignment: .leading, spacing: 9) {
            Eyebrow(text: notes.count > 2 ? "\(notes.count) notes together · a chord" : "Distance between two notes", color: Palette.coral)
            Text(MusicTheory.intervalName(semitones: high - low)).editorialTitle(25)
            HStack {
                Text("\(high - low) half-steps")
                Spacer()
                Text(String(format: "%.4f : 1", MusicTheory.ratio(from: low, to: high)))
                    .monospacedDigit()
            }.font(.system(size: 13)).foregroundStyle(Palette.muted)
            Text(high - low == 12 ? "The higher note vibrates exactly twice as fast." : "The ratio compares the higher frequency with the lower one.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }.labCard(tint: Palette.coral.opacity(0.3))
    }
}

struct TonePicker: View {
    var model: InstrumentModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Same pitch · a different texture")
            Picker("Sound texture", selection: Binding(get: { model.sensory.tone }, set: { model.changeTone($0) })) {
                Text("Pure wave").tag(ToneColor.pure)
                Text("Piano-like").tag(ToneColor.piano)
            }.pickerStyle(.segmented).accessibilityIdentifier("timbre-picker")
            Text("Pure wave has one frequency. Piano-like adds overtones that fade after a strike.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
        }
    }
}

struct PracticeView: View {
    @Bindable var model: InstrumentModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Eyebrow(text: "Let your ear lead", color: Palette.coral)
                Text("Listen. Then find it.").editorialTitle(35)
                Text("Five white keys: C, D, E, F, G. The sound comes first; its name stays hidden until you find it.")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
                VStack(spacing: 14) {
                    Image(systemName: model.isDemonstrating ? "waveform" : "ear")
                        .font(.system(size: 42, weight: .ultraLight)).foregroundStyle(Palette.mint)
                        .frame(height: 58)
                    Text(model.earMessage).font(.system(size: 16, design: .serif)).multilineTextAlignment(.center)
                        .accessibilityIdentifier("ear-feedback")
                    HStack {
                        Button { model.newEarChallenge() } label: { Label("New note", systemImage: "play.fill") }
                            .buttonStyle(.glassProminent).accessibilityIdentifier("ear-new")
                        Button { model.replayEar() } label: { Label("Listen again", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(.glass).disabled(model.isDemonstrating)
                    }
                    Eyebrow(text: "\(model.earWins) found · \(model.earAttempts) keys tried")
                }.frame(maxWidth: .infinity).labCard(tint: Palette.mint.opacity(0.3))
                FrequencyReadout(model: model)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Feel a steady pulse.").editorialTitle(26)
                    Text("A beat is a point in time. BPM is beats per minute; Hz is vibrations per second. Play any key along with the pulse.")
                        .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    BeatControls(model: model)
                }.labCard()
                Button { model.showingJourney = true } label: { Label("Learn a scale, a chord, or your first melody", systemImage: "book.closed") }
                    .font(.system(size: 13))
            }.padding(24)
        }.background(Palette.ink).scrollIndicators(.hidden)
    }
}

struct BeatControls: View {
    @Bindable var model: InstrumentModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                ForEach(0..<4) { beat in
                    Text("\(beat + 1)").font(.system(size: 17, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .foregroundStyle(model.beatIndex == beat ? Palette.ink : Palette.muted)
                        .background(model.beatIndex == beat ? (beat == 0 ? Palette.amber : Palette.mint) : Palette.panel, in: .capsule)
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel("Four beat pulse")
                .accessibilityValue(model.metronomeOn ? "Playing at \(Int(model.bpm)) beats per minute" : "Stopped")
            HStack {
                Button { model.toggleMetronome() } label: {
                    Label(model.metronomeOn ? "Stop pulse" : "Start pulse", systemImage: model.metronomeOn ? "stop.fill" : "play.fill")
                }.buttonStyle(.glass).accessibilityIdentifier("metronome")
                Spacer()
                Stepper("\(Int(model.bpm)) BPM", value: $model.bpm, in: 40...160, step: 5)
                    .font(.system(size: 12, design: .monospaced)).fixedSize().disabled(model.tab == .learn)
            }
        }
    }
}

struct JourneyView: View {
    var model: InstrumentModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("From vibration to your first melody.").editorialTitle(37)
                    Text("Ten small experiments. No music knowledge needed. Revisit any of them whenever you like.")
                        .font(.system(size: 14)).foregroundStyle(Palette.muted)
                    Eyebrow(text: "\(model.learned.count) / 10 discoveries", color: Palette.mint)
                    VStack(spacing: 10) {
                        ForEach(Array(Lesson.curriculum.enumerated()), id: \.element.id) { index, lesson in
                            Button { model.selectLesson(index); dismiss() } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle().stroke(model.learned.contains(lesson.id) ? Palette.mint : Palette.line).frame(width: 35, height: 35)
                                        if model.learned.contains(lesson.id) { Image(systemName: "checkmark").foregroundStyle(Palette.mint) }
                                        else { Text(String(format: "%02d", index + 1)).font(.system(size: 12, design: .monospaced)).foregroundStyle(Palette.muted) }
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(lesson.title).font(.system(size: 17, design: .serif)).foregroundStyle(Palette.ivory)
                                        Text(lesson.subtitle).font(.system(size: 11)).foregroundStyle(Palette.muted)
                                    }
                                    Spacer(minLength: 5)
                                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.muted)
                                }.labCard(tint: index == model.selectedLesson ? Palette.mint.opacity(0.4) : Palette.line)
                            }.buttonStyle(.plain).accessibilityIdentifier("lesson-\(index)")
                        }
                    }
                }.padding(24)
            }.background(Palette.ink)
                .navigationTitle("Your journey").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

struct SettingsView: View {
    @Bindable var model: InstrumentModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Sound") {
                    Toggle("Sound on", isOn: $model.sensory.soundEnabled)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Volume").font(.system(size: 14))
                        Slider(value: $model.sensory.volume, in: 0...1).accessibilityLabel("Volume")
                    }
                    Text("Start at a comfortable volume. Sound plays through your current speaker or headphones, including when the silent switch is on.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Touch and light") {
                    Toggle("Haptics", isOn: $model.sensory.hapticsEnabled)
                    Toggle("Feel the decay", isOn: $model.sensory.continuousFeelEnabled)
                        .disabled(!model.sensory.hapticsEnabled)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Touch strength").font(.system(size: 14))
                        Slider(value: $model.sensory.hapticStrength, in: 0...1).accessibilityLabel("Touch strength")
                            .disabled(!model.sensory.hapticsEnabled)
                    }
                    Toggle("Show key names", isOn: $model.showLabels)
                    Text(model.sensory.supportsHaptics ? "Feel a key's strike and short decay. Higher notes have a crisper feel. Touch represents the sound's shape, while your speaker produces its pitch." : "This device has no Core Haptics motor. Sound and visuals still explain every concept; touch feedback is available on supported iPhones.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Overtone follows the system Reduce Motion setting and gives every piano key a spoken note name and frequency.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Learning") {
                    Text("Your discoveries are saved on this device. Try an experiment as often as you like; completion comes from playing it.")
                    Text("The touchscreen teaches listening, pitch, note patterns, and rhythm. For real piano technique, transfer these patterns to physical keys: relaxed hands, curved fingers, and a comfortable wrist.")
                }.font(.system(size: 14))
            }.navigationTitle("Sound & touch").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { model.saveSettings(); dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

struct WhyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("One sound. Three ways to understand it.").editorialTitle(34)
                    explanation("Hear the frequency", "A repeating vibration has a frequency. 440 Hz means 440 repetitions each second. Faster vibration usually sounds higher. This keyboard uses equal temperament: twelve equal frequency ratios make an octave.")
                    explanation("See a model of the wave", "The plot shows a calculated 10-millisecond slice of each voice's starting waveform, slowed for viewing. More cycles in the same width means higher frequency. It is a model, rather than a microphone measurement. The bars show relative starting harmonic weights; the actual sound's upper partials fade as a note rings.")
                    explanation("Feel the shape", "The haptic motor gives you a strike and a short decaying touch. A higher register maps to a sharper sensation. It does not reproduce the note's frequency. The beat pulse represents musical timing.")
                    explanation("Why a piano has black keys", "Letters A through G repeat. Black keys fill the gaps between some neighboring letters. C sits immediately to the left of a group of two black keys. A sharp (♯) raises a note one half-step; a flat (♭) lowers it one. D♯ and E♭ share a key in this tuning.")
                    explanation("From a phone to a piano", "Start C–D–E–F–G on a real piano with your right thumb, index, middle, ring, and little finger. Play slowly with relaxed hands. This app is a listening and concept instrument; physical keys add touch, posture, and technique.")
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Explore the sources", color: Palette.mint)
                        Link("UNSW · Notes and frequencies", destination: URL(string: "https://www.phys.unsw.edu.au/music/notes.html")!)
                        Link("UNSW · Sound, waveforms, and spectra", destination: URL(string: "https://www.phys.unsw.edu.au/jw/sound.spectrum.html")!)
                        Link("Apple · Haptic sharpness", destination: URL(string: "https://developer.apple.com/documentation/corehaptics/chhapticevent/parameterid/hapticsharpness")!)
                    }.font(.system(size: 13))
                }.padding(24)
            }.background(Palette.ink).navigationTitle("Behind the instrument").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
    private func explanation(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 21, design: .serif)).foregroundStyle(Palette.ivory)
            Text(body).font(.system(size: 14)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview { RootView(model: InstrumentModel()) }

struct LessonDetailView: View {
    var lesson: Lesson
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Eyebrow(text: "Experiment \(lesson.id + 1)", color: Palette.mint)
                    Text(lesson.title).editorialTitle(37)
                    Text(lesson.body).font(.system(size: 17)).lineSpacing(6).foregroundStyle(Palette.muted)
                    Text(lesson.prompt).font(.system(size: 19, design: .serif)).foregroundStyle(Palette.amber).labCard(tint: Palette.amber.opacity(0.3))
                }.padding(24)
            }.background(Palette.ink).navigationTitle("Understand the idea").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Back to playing") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}
