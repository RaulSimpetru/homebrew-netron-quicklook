// Renders native/icon/*.svg into native/AppIcon.icns.
// Run after editing the SVGs: xcrun swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let sources = root.appendingPathComponent("native/icon")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// Small sizes use simplified artwork so the mark stays legible.
let entries: [(name: String, pixels: Int, svg: String)] = [
    ("icon_16x16", 16, "AppIcon-16"), ("icon_16x16@2x", 32, "AppIcon-32"),
    ("icon_32x32", 32, "AppIcon-32"), ("icon_32x32@2x", 64, "AppIcon"),
    ("icon_128x128", 128, "AppIcon"), ("icon_128x128@2x", 256, "AppIcon"),
    ("icon_256x256", 256, "AppIcon"), ("icon_256x256@2x", 512, "AppIcon"),
    ("icon_512x512", 512, "AppIcon"), ("icon_512x512@2x", 1024, "AppIcon"),
]

for entry in entries {
    guard let image = NSImage(contentsOf: sources.appendingPathComponent("\(entry.svg).svg")) else {
        fatalError("cannot load \(entry.svg).svg")
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: entry.pixels, pixelsHigh: entry.pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: entry.pixels, height: entry.pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: entry.pixels, height: entry.pixels))
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent("\(entry.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("native/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote native/AppIcon.icns")
