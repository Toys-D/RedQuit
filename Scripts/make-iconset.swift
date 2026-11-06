import AppKit

/// Рисует из SVG все PNG, которые нужны для .icns (каждый размер — прямо из вектора).
///
///     swift Scripts/make-iconset.swift Resources/Icon/RedQuit.svg build/AppIcon.iconset
///
/// AppKit понимает SVG сам. Иконка RedQuit не использует ни CSS, ни фильтры,
/// поэтому WebKit для отрисовки не нужен.

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: make-iconset.swift <icon.svg> <output.iconset>\n".utf8))
    exit(2)
}
let svg = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

guard let image = NSImage(contentsOf: svg) else {
    FileHandle.standardError.write(Data("cannot read \(svg.path)\n".utf8))
    exit(1)
}

/// Отрисовка в PNG заданного размера в пикселях, с прозрачностью.
func png(_ image: NSImage, pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try? FileManager.default.removeItem(at: output)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

// Имя и число пикселей — вместе: 32 px — это и icon_32x32, и icon_16x16@2x.
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try png(image, pixels: points * scale).write(to: output.appendingPathComponent(name))
    }
}

// Отдельно — для README и GitHub.
if arguments.count == 3, let extra = ProcessInfo.processInfo.environment["EXTRA_PNG"] {
    for item in extra.split(separator: ",") {
        let parts = item.split(separator: ":")
        guard parts.count == 2, let pixels = Int(parts[1]) else { continue }
        try png(image, pixels: pixels).write(to: URL(fileURLWithPath: String(parts[0])))
    }
}
print("iconset → \(output.path)")
