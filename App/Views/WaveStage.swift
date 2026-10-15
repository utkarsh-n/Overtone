import SwiftUI
import OvertoneCore

struct WaveStage: View {
    var notes: [Int]
    var tone: ToneColor
    var isPlaying: Bool
    @State private var startedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let colors: [Color] = [Palette.mint, Palette.coral, Palette.amber, .white]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isPlaying)) { context in
            Canvas { canvas, size in
                let time = reduceMotion || !isPlaying ? 0 : context.date.timeIntervalSince(startedAt)
                let waveNotes = notes.isEmpty ? [60] : notes
                let middle = size.height * 0.52
                let amplitude = size.height * 0.22
                let center = CGPoint(x: size.width / 2, y: middle)
                for ring in 1...5 {
                    let radius = CGFloat(ring) * size.height * 0.13
                    let ellipse = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    canvas.stroke(Path(ellipseIn: ellipse), with: .color(Palette.mint.opacity(notes.isEmpty ? 0.04 : 0.08)), lineWidth: 0.6)
                }
                var axis = Path()
                axis.move(to: CGPoint(x: 0, y: middle)); axis.addLine(to: CGPoint(x: size.width, y: middle))
                canvas.stroke(axis, with: .color(Palette.line), style: StrokeStyle(lineWidth: 0.5, dash: [3, 6]))
                for (index, midi) in waveNotes.enumerated() {
                    let f = MusicTheory.frequency(midi: midi)
                    var trace = Path()
                    let count = max(2, Int(size.width * 1.5))
                    for x in 0...count {
                        let fraction = Double(x) / Double(count)
                        let phase = 2 * Double.pi * f * (fraction * 0.01 + time * 0.00015)
                        let y = middle - CGFloat(MusicTheory.sample(phase: phase, tone: tone)) * amplitude
                        let point = CGPoint(x: fraction * size.width, y: y)
                        if x == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
                    }
                    let color = notes.isEmpty ? Palette.muted.opacity(0.3) : colors[index % colors.count]
                    canvas.stroke(trace, with: .color(color.opacity(0.08)), lineWidth: 11)
                    canvas.stroke(trace, with: .color(color.opacity(0.18)), lineWidth: 5)
                    canvas.stroke(trace, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .overlay(alignment: .topLeading) { Eyebrow(text: notes.isEmpty ? "Waiting for your first note" : "Wave model · 10 ms").font(.system(size: 9)) }
        .overlay(alignment: .bottomTrailing) { Text("Slowed for viewing").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Waveform model, a ten millisecond slice, animation slowed for viewing")
        .accessibilityValue(notes.map { PianoNote(midi: $0).accessibleName }.joined(separator: ", "))
    }
}

struct FrequencyReadout: View {
    var model: InstrumentModel
    var body: some View {
        let notes = model.hiddenReference ? [] : model.visualNotes
        if notes.count > 1 {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(notes.enumerated()), id: \.element) { index, midi in
                    readout(midi, color: index == 0 ? Palette.mint : index == 1 ? Palette.coral : Palette.amber, compact: true)
                        .labCard()
                }
            }
        } else {
            readout(notes.first, color: Palette.mint, compact: false)
                .frame(maxWidth: .infinity)
        }
    }
    private func readout(_ midi: Int?, color: Color, compact: Bool) -> some View {
        VStack(alignment: compact ? .leading : .center, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(midi.map { String(format: "%.2f", MusicTheory.frequency(midi: $0)) } ?? "—")
                    .font(.system(size: compact ? 27 : 34, weight: .regular, design: .serif)).monospacedDigit()
                Text("Hz").font(.system(size: compact ? 12 : 18, design: .serif))
            }.foregroundStyle(color).accessibilityIdentifier("frequency-readout")
            Text(midi.map { PianoNote(midi: $0).name + ($0 == 60 ? " · middle C" : "") } ?? (model.hiddenReference ? "Listen with your ear" : "Press any key to begin"))
                .font(.system(size: compact ? 14 : 19, design: .serif)).foregroundStyle(Palette.ivory)
            if !compact {
                Text(midi.map { String(format: "%.2f vibrations each second · %.2f ms per cycle", MusicTheory.frequency(midi: $0), 1000 / MusicTheory.frequency(midi: $0)) } ?? "A sound starts with a repeating vibration.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                if midi != nil && model.held.union(model.latched).union(model.demoNotes).isEmpty {
                    Eyebrow(text: "Last played")
                }
            }
        }.accessibilityElement(children: .combine)
    }
}

struct HarmonicView: View {
    var note: Int
    var tone: ToneColor
    var body: some View {
        let amplitudes = MusicTheory.harmonicAmplitudes(tone: tone)
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Eyebrow(text: "What is inside a note?", color: Palette.amber)
                Spacer()
                Text("MODEL").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<6) { index in
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == 0 ? Palette.mint : Palette.amber)
                            .frame(width: 11, height: max(2, CGFloat(index < amplitudes.count ? amplitudes[index] : 0) * 74))
                        Text("\(index + 1)×").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                    }.frame(maxWidth: .infinity)
                }
            }.frame(height: 96, alignment: .bottom)
            Text("The fundamental is \(String(format: "%.1f", MusicTheory.frequency(midi: note))) Hz. In this model, overtones repeat at multiples of it; their blend gives a sound its texture.")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
            Text("Relative starting weights · upper partials fade faster").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
        }.labCard(tint: Palette.amber.opacity(0.2))
        .accessibilityElement(children: .combine)
    }
}
