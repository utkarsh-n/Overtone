import SwiftUI
import UIKit
import OvertoneCore

/// A real multitouch surface: every finger owns its current note, so sliding or
/// releasing one finger cannot silence a note still held by another finger.
struct PianoKeyboard: UIViewRepresentable {
    var octave: Int
    var held: Set<Int>
    var highlighted: Set<Int>
    var showLabels: Bool
    var onDown: (Int) -> Void
    var onUp: (Int) -> Void

    func makeUIView(context: Context) -> PianoKeyboardView {
        let view = PianoKeyboardView()
        view.configure(octave: octave, held: held, highlighted: highlighted,
                       showLabels: showLabels, onDown: onDown, onUp: onUp)
        return view
    }

    func updateUIView(_ view: PianoKeyboardView, context: Context) {
        view.configure(octave: octave, held: held, highlighted: highlighted,
                       showLabels: showLabels, onDown: onDown, onUp: onUp)
    }

    static func dismantleUIView(_ view: PianoKeyboardView, coordinator: ()) {
        view.releaseAllNotes()
    }
}

@MainActor
final class PianoKeyboardView: UIView {
    private struct Key {
        var midi: Int
        var rect: CGRect
        var isBlack: Bool
        var enabled: Bool { (21...108).contains(midi) }
    }

    private static let whiteOffsets = [0, 2, 4, 5, 7, 9, 11, 12]
    private static let blackOffsets = [(1, 0), (3, 1), (6, 3), (8, 4), (10, 5)]
    private static let noteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private static let spokenNames = ["C", "C sharp, also D flat", "D", "D sharp, also E flat", "E", "F", "F sharp, also G flat", "G", "G sharp, also A flat", "A", "A sharp, also B flat", "B"]
    private static let ivory = UIColor(red: 0.94, green: 0.93, blue: 0.88, alpha: 1)
    private static let charcoal = UIColor(red: 0.105, green: 0.12, blue: 0.14, alpha: 1)
    private static let mint = UIColor(red: 0.48, green: 0.94, blue: 0.76, alpha: 1)
    private static let amber = UIColor(red: 1, green: 0.73, blue: 0.35, alpha: 1)
    private static let ink = UIColor(red: 0.10, green: 0.14, blue: 0.15, alpha: 1)

    private var octave = 4
    private var held: Set<Int> = []
    private var highlighted: Set<Int> = []
    private var showLabels = true
    private var onDown: (Int) -> Void = { _ in }
    private var onUp: (Int) -> Void = { _ in }
    private var touchNotes: [ObjectIdentifier: Int] = [:]
    private var accessibilityNotes: [UUID: Int] = [:]
    private var keys: [Key] = []
    private var keyElements: [PianoKeyAccessibilityElement] = []
    private var lastLayoutBounds = CGRect.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = false
        accessibilityIdentifier = "piano-keyboard"
        accessibilityLabel = "Piano keyboard"
        NotificationCenter.default.addObserver(self, selector: #selector(releaseForBackground),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { NotificationCenter.default.removeObserver(self) }

    func configure(octave: Int, held: Set<Int>, highlighted: Set<Int>, showLabels: Bool,
                   onDown: @escaping (Int) -> Void, onUp: @escaping (Int) -> Void) {
        self.onDown = onDown
        self.onUp = onUp
        let safeOctave = min(7, max(0, octave))
        let changedOctave = self.octave != safeOctave
        let changed = changedOctave || self.held != held || self.highlighted != highlighted
            || self.showLabels != showLabels
        if changedOctave { releaseAllNotes() }
        self.octave = safeOctave
        self.held = held
        self.highlighted = highlighted
        self.showLabels = showLabels
        if changedOctave || keys.isEmpty { rebuildKeys() }
        if changed {
            updateAccessibility()
            setNeedsDisplay()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastLayoutBounds else { return }
        lastLayoutBounds = bounds
        rebuildKeys()
        setNeedsDisplay()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil { releaseAllNotes() }
        super.willMove(toWindow: newWindow)
    }

    private var ownedNotes: Set<Int> {
        Set(touchNotes.values).union(accessibilityNotes.values)
    }

    private var displayedHeld: Set<Int> { held.union(ownedNotes) }

    private func rebuildKeys() {
        let area = bounds.insetBy(dx: 3, dy: 3)
        guard area.width > 0, area.height > 0 else {
            keys = []
            keyElements = []
            accessibilityElements = []
            return
        }
        let width = area.width / 8
        let base = (octave + 1) * 12
        var result = Self.whiteOffsets.enumerated().map { index, offset in
            Key(midi: base + offset,
                rect: CGRect(x: area.minX + CGFloat(index) * width + 0.7, y: area.minY,
                             width: width - 1.4, height: area.height), isBlack: false)
        }
        let blackWidth = width * 0.61
        result += Self.blackOffsets.map { offset, leftWhite in
            Key(midi: base + offset,
                rect: CGRect(x: area.minX + CGFloat(leftWhite + 1) * width - blackWidth / 2,
                             y: area.minY, width: blackWidth, height: area.height * 0.62),
                isBlack: true)
        }
        keys = result
        keyElements = result.sorted { $0.midi < $1.midi }.map { key in
            let element = PianoKeyAccessibilityElement(accessibilityContainer: self)
            element.midi = key.midi
            element.keyboard = self
            element.accessibilityIdentifier = "key-\(key.midi)"
            return element
        }
        accessibilityElements = keyElements
        updateAccessibility()
    }

    private func updateAccessibility() {
        let playing = displayedHeld
        for element in keyElements {
            guard let key = keys.first(where: { $0.midi == element.midi }) else { continue }
            let frequency = 440 * pow(2, Double(key.midi - 69) / 12)
            let noteOctave = key.midi / 12 - 1
            let middleC = key.midi == 60 ? ", middle C" : ""
            element.accessibilityLabel = "\(Self.spokenNames[key.midi % 12]) \(noteOctave)\(middleC), \(String(format: "%.2f", frequency)) hertz"
            element.accessibilityFrameInContainerSpace = key.rect
            element.accessibilityTraits = [.button, .playsSound]
            if playing.contains(key.midi) { element.accessibilityTraits.insert(.selected) }
            if !key.enabled { element.accessibilityTraits.insert(.notEnabled) }
            element.accessibilityValue = !key.enabled ? "Outside piano range"
                : highlighted.contains(key.midi) ? "Target note" : playing.contains(key.midi) ? "Playing" : nil
            element.accessibilityHint = key.enabled ? "Double tap to play this note." : nil
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let playing = displayedHeld
        for key in keys where !key.isBlack { draw(key, playing: playing.contains(key.midi), context: context) }
        for key in keys where key.isBlack { draw(key, playing: playing.contains(key.midi), context: context) }
    }

    private func draw(_ key: Key, playing: Bool, context: CGContext) {
        context.saveGState()
        let path = UIBezierPath(roundedRect: key.rect, cornerRadius: key.isBlack ? 5 : 7)
        let base = key.isBlack ? Self.charcoal : Self.ivory
        let fill = !key.enabled ? (key.isBlack ? UIColor(white: 0.13, alpha: 1) : UIColor(white: 0.32, alpha: 1))
            : playing ? Self.mint : base
        context.setShadow(offset: CGSize(width: 0, height: key.isBlack ? 3 : 1),
                          blur: key.isBlack ? 3 : 1, color: UIColor.black.withAlphaComponent(0.42).cgColor)
        fill.setFill()
        path.fill()
        context.setShadow(offset: .zero, blur: 0)
        (playing ? Self.mint.withAlphaComponent(0.9) : UIColor.black.withAlphaComponent(0.24)).setStroke()
        path.lineWidth = 0.8
        path.stroke()

        let lip = CGRect(x: key.rect.minX + 3, y: key.rect.maxY - 4,
                         width: max(0, key.rect.width - 6), height: 1)
        (key.isBlack ? UIColor.white.withAlphaComponent(0.13) : UIColor.black.withAlphaComponent(0.14)).setFill()
        UIBezierPath(roundedRect: lip, cornerRadius: 0.5).fill()

        if key.enabled && highlighted.contains(key.midi) {
            let dot = CGRect(x: key.rect.midX - 3, y: key.rect.maxY - (key.isBlack ? 36 : 46), width: 6, height: 6)
            context.setShadow(offset: .zero, blur: 7, color: Self.amber.withAlphaComponent(0.7).cgColor)
            Self.amber.setFill()
            UIBezierPath(ovalIn: dot).fill()
            context.setShadow(offset: .zero, blur: 0)
        }
        if showLabels {
            let isC = key.midi % 12 == 0
            let label = Self.noteNames[key.midi % 12] + (isC ? "\(key.midi / 12 - 1)" : "")
            let textColor = !key.enabled ? UIColor.white.withAlphaComponent(0.35)
                : key.isBlack && !playing ? UIColor.white.withAlphaComponent(0.87) : Self.ink
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: key.isBlack ? 10 : 12, weight: .semibold),
                .foregroundColor: textColor, .paragraphStyle: style
            ]
            let labelY = key.rect.maxY - (key.midi == 60 ? 33 : 25)
            (label as NSString).draw(in: CGRect(x: key.rect.minX, y: labelY,
                                              width: key.rect.width, height: 17), withAttributes: attributes)
            if key.midi == 60 {
                let secondary: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7.5, weight: .medium),
                    .foregroundColor: textColor.withAlphaComponent(0.68), .paragraphStyle: style
                ]
                ("middle C" as NSString).draw(in: CGRect(x: key.rect.minX, y: key.rect.maxY - 17,
                                                      width: key.rect.width, height: 12), withAttributes: secondary)
            }
        }
        context.restoreGState()
    }

    private func note(at point: CGPoint) -> Int? {
        // Black keys overlap white-key rectangles and must win the hit test.
        let hit = keys.first(where: { $0.isBlack && $0.rect.contains(point) })
            ?? keys.first(where: { !$0.isBlack && $0.rect.contains(point) })
        return hit.flatMap { $0.enabled ? $0.midi : nil }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        transition(touches, ended: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        transition(touches, ended: false)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        transition(touches, ended: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseAllNotes()
    }

    private func transition(_ touches: Set<UITouch>, ended: Bool) {
        let before = ownedNotes
        var changed = false
        for touch in touches {
            let identity = ObjectIdentifier(touch)
            let next = ended ? nil : note(at: touch.location(in: self))
            if touchNotes[identity] != next {
                touchNotes[identity] = next
                changed = true
            }
        }
        guard changed else { return }
        let after = ownedNotes
        updateAccessibility()
        setNeedsDisplay()
        // Commit the complete event first, including simultaneous finger swaps.
        for note in before.subtracting(after).sorted() { onUp(note) }
        for note in after.subtracting(before).sorted() { onDown(note) }
    }

    fileprivate func activate(midi: Int) -> Bool {
        guard (21...108).contains(midi), keys.contains(where: { $0.midi == midi }) else { return false }
        let wasPlaying = ownedNotes.contains(midi)
        let token = UUID()
        accessibilityNotes[token] = midi
        updateAccessibility()
        setNeedsDisplay()
        if !wasPlaying { onDown(midi) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, let note = self.accessibilityNotes.removeValue(forKey: token) else { return }
            self.updateAccessibility()
            self.setNeedsDisplay()
            if !self.ownedNotes.contains(note) { self.onUp(note) }
        }
        return true
    }

    @objc private func releaseForBackground() { releaseAllNotes() }

    func releaseAllNotes() {
        let notes = ownedNotes
        touchNotes.removeAll()
        accessibilityNotes.removeAll()
        guard !notes.isEmpty else { return }
        updateAccessibility()
        setNeedsDisplay()
        for note in notes { onUp(note) }
    }
}

@MainActor
private final class PianoKeyAccessibilityElement: UIAccessibilityElement {
    var midi = 60
    weak var keyboard: PianoKeyboardView?

    override func accessibilityActivate() -> Bool { keyboard?.activate(midi: midi) ?? false }
}
