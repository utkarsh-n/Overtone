import AppKit
import CoreGraphics
import Foundation

// Run from the project root: swift Design/make-icon.swift
// The opaque, square artwork lets iOS apply its own icon mask.
let side = 1024
let destination = CommandLine.arguments.dropFirst().first
    ?? "App/Assets.xcassets/AppIcon.appiconset/Icon.png"
let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: side, height: side,
                              bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create icon canvas")
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: alpha)
}
let ink = rgb(0.022, 0.045, 0.053)
let mint = rgb(0.48, 0.95, 0.80)
let ivory = rgb(0.96, 0.945, 0.89)
let charcoal = rgb(0.075, 0.105, 0.115)
let amber = rgb(1, 0.75, 0.39)
let canvas = CGRect(x: 0, y: 0, width: side, height: side)
context.setFillColor(ink)
context.fill(canvas)

let glow = CGGradient(colorsSpace: space,
                      colors: [rgb(0.06, 0.19, 0.17), ink] as CFArray,
                      locations: [0, 1])!
context.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 578), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 578), endRadius: 660,
                           options: [.drawsAfterEndLocation])

// Thin concentric rings carry the resonance motif without becoming a literal
// frequency diagram. Their weights remain visible at home-screen size.
let center = CGPoint(x: 512, y: 585)
for (index, radius) in [92.0, 153.0, 222.0, 296.0].enumerated() {
    context.setStrokeColor(rgb(0.48, 0.95, 0.80, [0.24, 0.21, 0.16, 0.12][index]))
    context.setLineWidth(index == 0 ? 3 : 2.3)
    context.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                    width: radius * 2, height: radius * 2))
}

let wave = CGMutablePath()
let left: CGFloat = 102
let width: CGFloat = 820
for sample in 0...820 {
    let fraction = CGFloat(sample) / 820
    let taper = pow(sin(.pi * fraction), 0.33)
    let y = center.y + sin(fraction * .pi * 4 - .pi / 2) * 82 * taper
    let point = CGPoint(x: left + width * fraction, y: y)
    if sample == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
}
context.setLineCap(.round)
context.setLineJoin(.round)
for (weight, alpha) in [(25.0, 0.025), (14.0, 0.06), (7.0, 0.18)] {
    context.addPath(wave)
    context.setLineWidth(weight)
    context.setStrokeColor(rgb(0.48, 0.95, 0.80, alpha))
    context.strokePath()
}
context.saveGState()
context.setShadow(offset: .zero, blur: 16, color: mint.copy(alpha: 0.40))
context.addPath(wave)
context.setStrokeColor(mint)
context.setLineWidth(4.8)
context.strokePath()
context.restoreGState()

// A restrained three-key fragment makes the instrument recognizable without
// crowding the wave. The central strike uses the same mint as the live trace.
let keyY: CGFloat = 154
let keyHeight: CGFloat = 197
let keyWidth: CGFloat = 101
let gap: CGFloat = 8
let keyboardWidth = keyWidth * 3 + gap * 2
let keyX = (1024 - keyboardWidth) / 2
for index in 0..<3 {
    let rect = CGRect(x: keyX + CGFloat(index) * (keyWidth + gap), y: keyY,
                      width: keyWidth, height: keyHeight)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -4), blur: 12,
                      color: rgb(0, 0, 0, 0.35))
    context.setFillColor(index == 1 ? mint : ivory)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
    context.fillPath()
    context.restoreGState()
    context.setStrokeColor(index == 1 ? rgb(0.75, 1, 0.90, 0.4) : rgb(1, 1, 1, 0.2))
    context.setLineWidth(1.5)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
    context.strokePath()
    context.setFillColor(rgb(0.025, 0.05, 0.055, 0.2))
    context.fill(CGRect(x: rect.minX + 8, y: keyY + 8, width: keyWidth - 16, height: 2))
}
for index in 0..<2 {
    let edge = keyX + CGFloat(index + 1) * (keyWidth + gap) - gap / 2
    let rect = CGRect(x: edge - 28, y: keyY + keyHeight * 0.39,
                      width: 56, height: keyHeight * 0.61)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -3), blur: 5,
                      color: rgb(0, 0, 0, 0.46))
    context.setFillColor(charcoal)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    context.fillPath()
    context.restoreGState()
    context.setFillColor(rgb(0.48, 0.95, 0.80, 0.14))
    context.fill(CGRect(x: rect.minX + 7, y: rect.minY + 6, width: rect.width - 14, height: 2))
}
context.setFillColor(amber)
context.fillEllipse(in: CGRect(x: 508, y: 177, width: 8, height: 8))

guard let cgImage = context.makeImage(),
      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}
let output = URL(fileURLWithPath: destination)
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
try png.write(to: output)
print("Rendered \(side)×\(side) opaque icon: \(output.path)")
