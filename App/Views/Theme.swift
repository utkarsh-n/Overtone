import SwiftUI

enum Palette {
    static let ink = Color(red: 0.035, green: 0.059, blue: 0.075)
    static let panel = Color(red: 0.065, green: 0.091, blue: 0.106)
    static let mint = Color(red: 0.51, green: 0.96, blue: 0.83)
    static let amber = Color(red: 0.96, green: 0.74, blue: 0.45)
    static let coral = Color(red: 1, green: 0.55, blue: 0.51)
    static let ivory = Color(red: 0.96, green: 0.95, blue: 0.89)
    static let muted = Color(red: 0.61, green: 0.69, blue: 0.71)
    static let line = Color.white.opacity(0.13)
}

struct Eyebrow: View {
    var text: String
    var color: Color = Palette.muted
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.8).foregroundStyle(color)
    }
}

extension View {
    func labCard(tint: Color = Palette.line) -> some View {
        padding(16).background(Palette.panel, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint, lineWidth: 1))
    }
    func editorialTitle(_ size: CGFloat = 36) -> some View {
        font(.system(size: size, weight: .regular, design: .serif)).foregroundStyle(Palette.ivory)
    }
}
