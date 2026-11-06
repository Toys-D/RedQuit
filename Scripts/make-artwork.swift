import AppKit

/// Картинки для GitHub: баннер, обложка для соцсетей и схема двух режимов на каждом языке.
///
///     swift Scripts/make-artwork.swift
///
/// Берёт иконку (Resources/Icon/RedQuit-1024.png), скриншоты из .github/screenshots
/// и названия режимов из Resources/Localization/<язык>.lproj/Localizable.strings.

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
func path(_ relative: String) -> URL { root.appendingPathComponent(relative) }
func load(_ relative: String) -> NSImage {
    guard let image = NSImage(contentsOf: path(relative)) else { fatalError("cannot load \(relative)") }
    return image
}

// MARK: - Рисование

func render(width: Int, height: Int, to relative: String, draw: (CGRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    let url = path(relative)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
    print("→ \(relative)")
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func text(_ string: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor,
          at point: CGPoint, maxWidth: CGFloat = 10_000, alignment: NSTextAlignment = .left, lineHeight: CGFloat? = nil) {
    let style = NSMutableParagraphStyle()
    style.alignment = alignment
    if let lineHeight { style.minimumLineHeight = lineHeight; style.maximumLineHeight = lineHeight }
    let attributed = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style,
    ])
    let bounds = attributed.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesLineFragmentOrigin])
    let x = alignment == .center ? point.x - maxWidth / 2 : point.x
    attributed.draw(with: CGRect(x: x, y: point.y - bounds.height, width: maxWidth, height: bounds.height),
                    options: [.usesLineFragmentOrigin])
}

func background(_ rect: CGRect) {
    NSGradient(colors: [color(0x2B303A), color(0x16181D)])!.draw(in: rect, angle: -90)
}

func shadowed(_ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = 40
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let icon = load("Resources/Icon/RedQuit-1024.png")
let settings = load(".github/screenshots/settings-dark.png")
let menu = load(".github/screenshots/menu.png")
let green = color(0x8FD18A)

// MARK: - Баннер 1800×900

render(width: 1800, height: 900, to: ".github/banner.png") { rect in
    background(rect)
    icon.draw(in: CGRect(x: 80, y: 520, width: 300, height: 300))
    text("RedQuit", size: 150, weight: .bold, color: .white, at: CGPoint(x: 112, y: 520))
    text("Close the window,\nquit the app.", size: 64, color: color(0xD9DDE4), at: CGPoint(x: 116, y: 320), lineHeight: 78)
    text("Free · 16 languages · macOS 14+", size: 40, weight: .medium, color: green, at: CGPoint(x: 116, y: 128))

    // Скриншоты уже с тенью и прозрачными полями (как их снимает screencapture).
    let settingsHeight: CGFloat = 960
    let settingsWidth = settingsHeight * settings.size.width / settings.size.height
    settings.draw(in: CGRect(x: 1800 - settingsWidth - 30, y: -50, width: settingsWidth, height: settingsHeight))
    let menuWidth: CGFloat = 470
    let menuHeight = menuWidth * menu.size.height / menu.size.width
    menu.draw(in: CGRect(x: 1800 - settingsWidth - 250, y: 470, width: menuWidth, height: menuHeight))
}

// MARK: - Обложка для соцсетей 1280×640 (загружается вручную: Settings ▸ Social preview)

render(width: 1280, height: 640, to: ".github/social-preview.png") { rect in
    background(rect)
    icon.draw(in: CGRect(x: 70, y: 310, width: 250, height: 250))
    text("RedQuit", size: 120, weight: .bold, color: .white, at: CGPoint(x: 340, y: 520))
    text("Close the window, quit the app.", size: 50, color: color(0xD9DDE4), at: CGPoint(x: 346, y: 370))
    text("The red button on your Mac works the way it does on Windows.", size: 32, color: color(0xA9B0BC),
         at: CGPoint(x: 96, y: 230), maxWidth: 1100)
    text("Free · 16 languages · macOS 14+ · github.com/Toys-D/RedQuit", size: 30, weight: .medium, color: green,
         at: CGPoint(x: 96, y: 120))
}

// MARK: - Схема режимов, по картинке на язык

/// Окно в стиле macOS: заголовок со светофором. `highlight` — красная кнопка крупнее, с курсором.
func window(_ frame: CGRect, highlight: Bool) {
    shadowed {
        color(0xFFFFFF).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14).fill()
    }
    color(0xE9EBEF).setFill()
    let title = CGRect(x: frame.minX, y: frame.maxY - 34, width: frame.width, height: 34)
    let titlePath = NSBezierPath(roundedRect: title, xRadius: 14, yRadius: 14)
    titlePath.append(NSBezierPath(rect: CGRect(x: title.minX, y: title.minY, width: title.width, height: 14)))
    titlePath.fill()
    let lights: [(UInt32, CGFloat)] = [(0xFF5F57, 0), (0xFEBC2E, 22), (0x28C840, 44)]
    for (hex, dx) in lights {
        color(hex).setFill()
        let r: CGFloat = 7
        NSBezierPath(ovalIn: CGRect(x: title.minX + 18 + dx - r, y: title.midY - r, width: r * 2, height: r * 2)).fill()
    }
    if highlight {
        // Подсветка нажатой красной кнопки и курсор.
        color(0xFF5F57, 0.35).setFill()
        NSBezierPath(ovalIn: CGRect(x: title.minX + 18 - 15, y: title.midY - 15, width: 30, height: 30)).fill()
        let tip = CGPoint(x: title.minX + 22, y: title.midY - 4)
        let cursor = NSBezierPath()
        cursor.move(to: tip)
        cursor.line(to: CGPoint(x: tip.x, y: tip.y - 30))
        cursor.line(to: CGPoint(x: tip.x + 8, y: tip.y - 23))
        cursor.line(to: CGPoint(x: tip.x + 14, y: tip.y - 35))
        cursor.line(to: CGPoint(x: tip.x + 19, y: tip.y - 32))
        cursor.line(to: CGPoint(x: tip.x + 13, y: tip.y - 21))
        cursor.line(to: CGPoint(x: tip.x + 23, y: tip.y - 21))
        cursor.close()
        NSColor.black.setFill(); cursor.fill()
        NSColor.white.setStroke(); cursor.lineWidth = 2; cursor.stroke()
    }
    // Строки «текста» в окне.
    color(0xD5D8DE).setFill()
    for (i, w) in [0.7, 0.85, 0.55].enumerated() {
        NSBezierPath(roundedRect: CGRect(x: frame.minX + 22, y: frame.maxY - 66 - CGFloat(i) * 22,
                                         width: (frame.width - 44) * w, height: 9), xRadius: 4.5, yRadius: 4.5).fill()
    }
}

func arrow(from: CGPoint, to: CGPoint) {
    color(0x8A919C).setStroke()
    let line = NSBezierPath()
    line.move(to: from); line.line(to: CGPoint(x: to.x - 14, y: to.y))
    line.lineWidth = 6; line.lineCapStyle = .round; line.stroke()
    color(0x8A919C).setFill()
    let head = NSBezierPath()
    head.move(to: to); head.line(to: CGPoint(x: to.x - 22, y: to.y + 15)); head.line(to: CGPoint(x: to.x - 22, y: to.y - 15)); head.close()
    head.fill()
}

/// Итог: программа работает (зелёная галочка) или завершена (красный «выключатель»).
func outcome(at center: CGPoint, quits: Bool) {
    let r: CGFloat = 46
    shadowed {
        color(quits ? 0xE5483F : 0x34C759).setFill()
        NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)).fill()
    }
    NSColor.white.setStroke()
    let mark = NSBezierPath()
    mark.lineWidth = 8; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
    if quits {
        mark.appendArc(withCenter: CGPoint(x: center.x, y: center.y - 3), radius: 21, startAngle: 130, endAngle: 50, clockwise: false)
        mark.move(to: CGPoint(x: center.x, y: center.y + 22)); mark.line(to: CGPoint(x: center.x, y: center.y + 2))
    } else {
        mark.move(to: CGPoint(x: center.x - 20, y: center.y)); mark.line(to: CGPoint(x: center.x - 6, y: center.y - 15))
        mark.line(to: CGPoint(x: center.x + 21, y: center.y + 16))
    }
    mark.stroke()
}

func strings(_ language: String) -> [String: String] {
    (NSDictionary(contentsOf: path("Resources/Localization/\(language).lproj/Localizable.strings")) as? [String: String]) ?? [:]
}

let languages = ((try? FileManager.default.contentsOfDirectory(atPath: path("Resources/Localization").path)) ?? [])
    .filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }.sorted()

for language in languages {
    let s = strings(language)
    let titles = [s["mode.lastWindow.title"] ?? "Last window", s["mode.anyWindow.title"] ?? "Any window"]
    let rtl = language == "ar"
    render(width: 1600, height: 640, to: ".github/modes/\(language).png") { rect in
        color(0xF4F5F7).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 36, yRadius: 36).fill()
        // Колонки идут справа налево для арабского.
        for column in 0..<2 {
            let originX: CGFloat = rtl ? (column == 0 ? 800 : 0) : (column == 0 ? 0 : 800)
            if column == 1 {
                color(0xDADDE3).setFill()
                NSRect(x: 799, y: 40, width: 2, height: 560).fill()
            }
            text(titles[column], size: 44, weight: .bold, color: color(0x1F2228),
                 at: CGPoint(x: originX + 400, y: 600), maxWidth: 720, alignment: .center)
            // Ряд 1: закрываем одно из двух окон. Ряд 2: закрываем последнее окно.
            let rows: [(windows: Int, quits: Bool)] = column == 0 ? [(2, false), (1, true)] : [(2, true), (1, true)]
            for (rowIndex, row) in rows.enumerated() {
                let baseY: CGFloat = rowIndex == 0 ? 330 : 80
                if row.windows == 2 {
                    window(CGRect(x: originX + 150, y: baseY + 40, width: 230, height: 150), highlight: false)
                }
                window(CGRect(x: originX + 120, y: baseY + 10, width: 230, height: 150), highlight: true)
                arrow(from: CGPoint(x: originX + 420, y: baseY + 95), to: CGPoint(x: originX + 545, y: baseY + 95))
                outcome(at: CGPoint(x: originX + 620, y: baseY + 95), quits: row.quits)
            }
        }
    }
}
