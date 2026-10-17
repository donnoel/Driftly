// Local design review only. No App Store Connect writes.
// swift tools/AppStoreScreenshots/render-review.swift [review-directory]
import AppKit
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Build/AppStoreScreenshotReview")
let fm = FileManager.default
let navy = NSColor(srgbRed: 0.025, green: 0.044, blue: 0.071, alpha: 1)
let white = NSColor(srgbRed: 0.95, green: 0.96, blue: 0.96, alpha: 1)
let muted = NSColor(srgbRed: 0.64, green: 0.72, blue: 0.75, alpha: 1)
let mint = NSColor(srgbRed: 0.52, green: 0.84, blue: 0.79, alpha: 1)

struct Card {
    let key: String
    let title: String
    let subtitle: String
    let label: String
}
let cards = [
    Card(key: "aurora", title: "Light,\nin motion.", subtitle: "Ambient visuals for quieter moments.", label: "AURORA VEIL"),
    Card(key: "glassTides", title: "Change\nthe atmosphere.", subtitle: "Explore the flowing layers of Glass Tides.", label: "GLASS TIDES"),
    Card(key: "lumenVault", title: "Light\ntakes shape.", subtitle: "Discover the sculpted lines of Lumen Vault.", label: "LUMEN VAULT"),
    Card(key: "timer", title: "Set a\nsleep timer.", subtitle: "Choose a duration. Let Driftly wind down.", label: "SLEEP TIMER"),
    Card(key: "clock", title: "Time,\nsoftly lit.", subtitle: "Keep the clock in view as the light drifts.", label: "OPTIONAL CLOCK")
]

func source(_ name: String) throws -> CGImage {
    let url = root.appendingPathComponent("raw/\(name).png")
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(s, 0, nil) else {
        throw NSError(domain: "DriftlyScreenshot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing capture: \(url.path)"])
    }
    return image
}

func canvas(_ width: Int, _ height: Int, _ draw: (CGContext) throws -> Void) throws -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    navy.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    try draw(context)
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

func write(_ image: CGImage, _ relative: String) throws {
    let url = root.appendingPathComponent(relative)
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not export \(relative)") }
}

func text(_ value: String, x: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = white, tracking: CGFloat = 0, leading: CGFloat? = nil, canvasHeight: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    if let leading { paragraph.minimumLineHeight = leading; paragraph.maximumLineHeight = leading }
    paragraph.lineBreakMode = .byWordWrapping
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: tracking, .paragraphStyle: paragraph]
    (value as NSString).draw(in: NSRect(x: x, y: canvasHeight - top - height, width: width, height: height), withAttributes: attributes)
}

func portrait(_ platform: String, width: Int, height: Int, card: Card, index: Int) throws -> CGImage {
    let image = try source("\(platform)-\(card.key)")
    let w = CGFloat(width), h = CGFloat(height)
    let isPad = platform == "ipad"
    let header: CGFloat = isPad ? 620 : 650
    let margin: CGFloat = isPad ? 130 : 92
    return try canvas(width, height) { context in
        // Cropped genuine app captures. Keep simulator-only motion hardware warning
        // outside the composition; never repaint or synthesize app controls.
        let crop: CGRect
        if card.key == "timer" && isPad {
            crop = CGRect(x: 232, y: 550, width: 1600, height: 1640)
        } else if card.key == "timer" {
            crop = CGRect(x: 0, y: header, width: CGFloat(image.width), height: CGFloat(image.height) - header)
        } else {
            crop = CGRect(x: 0, y: CGFloat(image.height) * 0.07, width: CGFloat(image.width), height: CGFloat(image.height) * 0.93)
        }
        let cropped = image.cropping(to: crop.integral)!
        let photo = CGRect(x: 0, y: 0, width: w, height: h - header)
        context.saveGState(); context.clip(to: photo)
        let scale = max(photo.width / CGFloat(cropped.width), photo.height / CGFloat(cropped.height))
        let ih = CGFloat(cropped.height) * scale
        context.draw(cropped, in: CGRect(x: (w - CGFloat(cropped.width) * scale) / 2, y: photo.maxY - ih, width: CGFloat(cropped.width) * scale, height: ih))
        context.restoreGState()
        text("DRIFTLY NIGHT", x: margin, top: 82, width: w - margin * 2, height: 60, size: isPad ? 36 : 32, weight: .medium, color: mint, tracking: 6, canvasHeight: h)
        text(card.title, x: margin - 5, top: 192, width: w - margin * 2 + 10, height: 300, size: isPad ? 140 : 114, weight: .semibold, tracking: -4, leading: isPad ? 142 : 120, canvasHeight: h)
        text(card.subtitle, x: margin, top: isPad ? 518 : 504, width: w - margin * 2, height: 94, size: isPad ? 39 : 36, color: muted, leading: 45, canvasHeight: h)
        // Quiet gallery caption on artwork-only cards; feature UI remains clear.
        if card.key != "timer" {
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [NSColor.black.withAlphaComponent(0.7).cgColor, NSColor.clear.cgColor] as CFArray, locations: [0, 1])!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 260), options: [])
            text(String(format: "%02d", index + 1) + "   /   " + card.label, x: margin, top: h - 102, width: w - margin * 2, height: 50, size: isPad ? 28 : 25, weight: .medium, color: white.withAlphaComponent(0.8), tracking: 3, canvasHeight: h)
        }
    }
}

func television(_ card: Card, index: Int) throws -> CGImage {
    let w: CGFloat = 1920, h: CGFloat = 1080
    let image = try source("tv-\(card.key)")
    let titles = ["Light, in motion.", "Change the atmosphere.", "Light takes shape.", "Set a sleep timer.", "Begin on your Home Screen."]
    return try canvas(Int(w), Int(h)) { context in
        context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let isTimer = card.key == "timer"
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [navy.withAlphaComponent(0.96).cgColor, navy.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: isTimer ? 0 : h), end: CGPoint(x: 0, y: isTimer ? 360 : h - 440), options: [])
        if !isTimer {
            text("DRIFTLY NIGHT", x: 104, top: 66, width: 1700, height: 45, size: 25, weight: .medium, color: mint, tracking: 5, canvasHeight: h)
        }
        text(titles[index], x: 100, top: isTimer ? 853 : 137, width: 1720, height: 110, size: 78, weight: .semibold, tracking: -2.6, canvasHeight: h)
        text(card.subtitle, x: 104, top: isTimer ? 963 : 248, width: 1700, height: 60, size: 30, color: muted, canvasHeight: h)
        if !isTimer && card.key != "top-shelf" {
            text(String(format: "%02d", index + 1) + "   /   " + card.label, x: 104, top: 985, width: 1700, height: 45, size: 23, weight: .medium, color: white.withAlphaComponent(0.8), tracking: 3, canvasHeight: h)
        }
    }
}

var output: [[String: Any]] = []
var rendered: [String: [CGImage]] = [:]
for platform in ["iphone", "ipad", "tv"] {
    rendered[platform] = []
    for index in 0..<5 {
        let card = platform == "tv" && index == 4 ? Card(key: "top-shelf", title: "Begin on your Home Screen.", subtitle: "Open Aurora Veil from Top Shelf.", label: "TOP SHELF") : cards[index]
        let image = try platform == "tv" ? television(card, index: index) : portrait(platform, width: platform == "iphone" ? 1320 : 2064, height: platform == "iphone" ? 2868 : 2752, card: card, index: index)
        let filename = "\(platform)/\(String(format: "%02d", index + 1))-\(card.key).png"
        try write(image, filename)
        rendered[platform]!.append(image)
        output.append(["platform": platform, "file": filename, "source": "raw/\(platform)-\(card.key).png", "title": card.title, "subtitle": card.subtitle, "width": image.width, "height": image.height, "hasAlpha": false])
    }
    let thumbWidth: CGFloat = platform == "tv" ? 480 : platform == "ipad" ? 360 : 286
    let thumbHeight = thumbWidth * CGFloat(rendered[platform]![0].height) / CGFloat(rendered[platform]![0].width)
    let gap: CGFloat = 24, pad: CGFloat = 32, top: CGFloat = 90
    let sw = Int(pad * 2 + thumbWidth * 5 + gap * 4), sh = Int(top + thumbHeight + pad)
    let sheet = try canvas(sw, sh) { context in
        text(platform == "tv" ? "APPLE TV" : platform.uppercased(), x: pad, top: 25, width: 1000, height: 50, size: 25, weight: .medium, color: mint, tracking: 4, canvasHeight: CGFloat(sh))
        for (index, image) in rendered[platform]!.enumerated() {
            context.draw(image, in: CGRect(x: pad + CGFloat(index) * (thumbWidth + gap), y: pad, width: thumbWidth, height: thumbHeight))
        }
    }
    try write(sheet, "\(platform)-sequence.png")
}
try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("manifest.json"))
print("Rendered 15 local review images and 3 sequence sheets in \(root.path)")
