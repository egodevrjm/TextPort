import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = root.appendingPathComponent("Packaging/AppIcon.iconset", isDirectory: true)
let assetsURL = root.appendingPathComponent("Assets", isDirectory: true)

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)

let outputs: [(filename: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for output in outputs {
    let image = drawIcon(pixels: output.pixels)
    try writePNG(image, to: iconsetURL.appendingPathComponent(output.filename))

    if output.pixels == 1024 {
        try writePNG(image, to: assetsURL.appendingPathComponent("TextPortIcon.png"))
    }
}

try writeICNS(
    from: iconsetURL,
    to: root.appendingPathComponent("Packaging/TextPort.icns")
)

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap.")
    }

    bitmap.size = NSSize(width: pixels, height: pixels)

    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create drawing context.")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    let context = graphicsContext.cgContext
    let size = CGFloat(pixels)

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let scale = size / 1024

    func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
    }

    func roundedPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius * scale, cornerHeight: radius * scale, transform: nil)
    }

    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let tileRect = rect(72, 72, 880, 880)
    let tilePath = roundedPath(tileRect, radius: 196)
    let tileGradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color(72, 136, 174).copy(alpha: 1)!,
            color(46, 90, 137).copy(alpha: 1)!
        ] as CFArray,
        locations: [0, 1]
    )!

    context.saveGState()
    context.addPath(tilePath)
    context.clip()
    context.drawLinearGradient(
        tileGradient,
        start: CGPoint(x: tileRect.minX, y: tileRect.maxY),
        end: CGPoint(x: tileRect.maxX, y: tileRect.minY),
        options: []
    )

    context.setFillColor(color(255, 255, 255, 0.13))
    context.fillEllipse(in: rect(88, 610, 360, 360))
    context.fillEllipse(in: rect(638, 92, 250, 250))
    context.restoreGState()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -28 * scale), blur: 44 * scale, color: color(16, 36, 62, 0.34))

    let pageRect = rect(257, 162, 510, 700)
    let pagePath = roundedPath(pageRect, radius: 54)
    context.addPath(pagePath)
    context.setFillColor(color(250, 253, 255))
    context.fillPath()
    context.restoreGState()

    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: 651 * scale, y: 862 * scale))
    foldPath.addLine(to: CGPoint(x: 767 * scale, y: 746 * scale))
    foldPath.addLine(to: CGPoint(x: 651 * scale, y: 746 * scale))
    foldPath.closeSubpath()

    context.addPath(foldPath)
    context.setFillColor(color(217, 232, 241))
    context.fillPath()

    let foldHighlightPath = CGMutablePath()
    foldHighlightPath.move(to: CGPoint(x: 651 * scale, y: 862 * scale))
    foldHighlightPath.addLine(to: CGPoint(x: 767 * scale, y: 746 * scale))
    foldHighlightPath.addLine(to: CGPoint(x: 705 * scale, y: 756 * scale))
    foldHighlightPath.addLine(to: CGPoint(x: 651 * scale, y: 810 * scale))
    foldHighlightPath.closeSubpath()

    context.addPath(foldHighlightPath)
    context.setFillColor(color(255, 255, 255, 0.52))
    context.fillPath()

    context.setStrokeColor(color(203, 220, 231))
    context.setLineWidth(4 * scale)
    context.addPath(pagePath)
    context.strokePath()

    let lines: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = [
        (335, 657, 250, 22),
        (335, 579, 354, 22),
        (335, 501, 298, 22),
        (335, 423, 346, 22),
        (335, 345, 218, 22)
    ]

    for (index, line) in lines.enumerated() {
        let lineRect = rect(line.x, line.y, line.width, line.height)
        let path = roundedPath(lineRect, radius: 11)
        context.addPath(path)
        context.setFillColor(index == 0 ? color(47, 96, 138) : color(91, 126, 154))
        context.fillPath()
    }

    let cursorRect = rect(610, 313, 16, 96)
    context.addPath(roundedPath(cursorRect, radius: 8))
    context.setFillColor(color(41, 88, 128))
    context.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ image: NSBitmapImageRep, to url: URL) throws {
    guard let pngData = image.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try pngData.write(to: url, options: .atomic)
}

func writeICNS(from iconsetURL: URL, to outputURL: URL) throws {
    let entries: [(type: String, filename: String)] = [
        ("icp4", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp5", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var payload = Data()

    for entry in entries {
        let pngURL = iconsetURL.appendingPathComponent(entry.filename)
        let pngData = try Data(contentsOf: pngURL)
        payload.append(ascii: entry.type)
        payload.append(bigEndianUInt32: UInt32(pngData.count + 8))
        payload.append(pngData)
    }

    var icns = Data()
    icns.append(ascii: "icns")
    icns.append(bigEndianUInt32: UInt32(payload.count + 8))
    icns.append(payload)

    try icns.write(to: outputURL, options: .atomic)
}

extension Data {
    mutating func append(ascii string: String) {
        precondition(string.utf8.count == 4)
        append(contentsOf: string.utf8)
    }

    mutating func append(bigEndianUInt32 value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}
