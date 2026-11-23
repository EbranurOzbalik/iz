// Run from the repository root: swift tool/render_brand_assets.swift
// A vector wordmark based on the app's existing Georgia typography.
import AppKit
import CoreText

let purple = NSColor(srgbRed: 117/255, green: 83/255, blue: 151/255, alpha: 1)
let cream = NSColor(srgbRed: 250/255, green: 248/255, blue: 245/255, alpha: 1)
let font = CTFontCreateWithName("Georgia" as CFString, 64, nil)
let characters: [UniChar] = Array("iz".utf16)
var glyphs = [CGGlyph](repeating: 0, count: characters.count)
CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
var advances = [CGSize](repeating: .zero, count: glyphs.count)
CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
let raw = CGMutablePath()
var cursor: CGFloat = 0
for (index, glyph) in glyphs.enumerated() {
    if let path = CTFontCreatePathForGlyph(font, glyph, nil) {
        raw.addPath(path, transform: CGAffineTransform(translationX: cursor, y: 0))
    }
    cursor += advances[index].width
}
let bounds = raw.boundingBoxOfPath
let scale = 48 / max(bounds.width, bounds.height)
var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
    tx: 54 - bounds.midX * scale, ty: 54 + bounds.midY * scale)
let mark = raw.copy(using: &transform)!
func number(_ value: CGFloat) -> String { String(format: "%.3f", Double(value)) }
var commands: [String] = []
mark.applyWithBlock { pointer in
    let e = pointer.pointee
    func point(_ i: Int) -> String { "\(number(e.points[i].x)),\(number(e.points[i].y))" }
    switch e.type {
    case .moveToPoint: commands.append("M\(point(0))")
    case .addLineToPoint: commands.append("L\(point(0))")
    case .addQuadCurveToPoint: commands.append("Q\(point(0)) \(point(1))")
    case .addCurveToPoint: commands.append("C\(point(0)) \(point(1)) \(point(2))")
    case .closeSubpath: commands.append("Z")
    @unknown default: fatalError("Unknown path element")
    }
}
let pathData = commands.joined(separator: " ")
func write(_ text: String, _ path: String) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
    try text.write(toFile: path, atomically: true, encoding: .utf8)
}
func png(_ path: String, width: Int, height: Int, draw: (CGContext) -> Void) throws {
    try FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
        withIntermediateDirectories: true)
    let context = CGContext(data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    draw(graphics.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
func icon(_ path: String, _ size: Int) throws {
    try png(path, width: size, height: size) { context in
        context.setFillColor(purple.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        context.translateBy(x: 0, y: CGFloat(size))
        context.scaleBy(x: CGFloat(size)/108, y: -CGFloat(size)/108)
        context.setFillColor(cream.cgColor)
        context.addPath(mark)
        context.fillPath()
    }
}
try write("""
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
<rect width="108" height="108" fill="#755397"/>
<path fill="#faf8f5" d="\(pathData)"/>
</svg>
""", "assets/brand/iz-icon.svg")
try write("""
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#FAF8F5" android:pathData="\(pathData)" />
</vector>
""", "android/app/src/main/res/drawable/ic_launcher_foreground.xml")
try write("""
<resources><color name="launcher_background">#755397</color></resources>
""", "android/app/src/main/res/values/launcher_colors.xml")
try write("""
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
""", "android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml")
try write("""
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
""", "android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml")
for (density, size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
    try icon("android/app/src/main/res/mipmap-\(density)/ic_launcher.png", size)
}
try icon("store/google-play/graphics/icon-512.png", 512)
try png("store/google-play/graphics/feature-1024x500.png", width: 1024, height: 500) { context in
    context.setFillColor(cream.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 500))
    func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, serif: Bool = false) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: serif ? NSFont(name: "Georgia", size: size)! : NSFont.systemFont(ofSize: size),
            .foregroundColor: purple
        ])
    }
    text("Hikâyeler geçer,", 64, 300, 52, serif: true)
    text("izleri kalır.", 64, 236, 52, serif: true)
    text("Kişisel kültür günlüğün", 66, 160, 26)
    text("Kitap · Film · Dizi · Tiyatro", 66, 115, 21)
    for (i, alpha) in [0.25, 0.50, 1.0].enumerated() {
        let rect = CGRect(x: 690 + i * 36, y: 95 + i * 26, width: 142, height: 242)
        context.setFillColor(purple.withAlphaComponent(alpha).cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        context.fillPath()
    }
    context.saveGState()
    context.translateBy(x: 778, y: 326)
    context.scaleBy(x: 1.03, y: -1.03)
    context.setFillColor(cream.cgColor)
    context.addPath(mark)
    context.fillPath()
    context.restoreGState()
}
print("Android icons, vector source and Play Store graphics generated.")
