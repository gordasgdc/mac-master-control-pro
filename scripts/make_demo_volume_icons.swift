// Pictograme PROPRII pentru volumele demonstrative (nu imită iconuri terțe). Uz: swift make_demo_volume_icons.swift <folder> -> ssd.icns, raid.icns
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }
func render(_ size: Int, kind: String) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let k = CGFloat(size) / 1024; ctx.scaleBy(x: k, y: k)
    func grad(_ a: CGColor, _ b: CGColor) -> CGGradient { CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [a, b] as CFArray, locations: nil)! }
    let body = CGRect(x: 90, y: 250, width: 844, height: 520)
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 40, color: col(0, 0, 0, 0.4))
    ctx.addPath(rr(body, 120)); ctx.setFillColor(kind == "ssd" ? col(0.95, 0.52, 0.12) : col(0.16, 0.18, 0.22)); ctx.fillPath(); ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(rr(body, 120)); ctx.clip()
    if kind == "ssd" {
        ctx.drawLinearGradient(grad(col(1.0, 0.68, 0.30), col(0.90, 0.42, 0.06)), start: CGPoint(x: 512, y: 770), end: CGPoint(x: 512, y: 250), options: [])
        let inner = body.insetBy(dx: 64, dy: 64)
        ctx.addPath(rr(inner, 70)); ctx.clip()
        ctx.drawLinearGradient(grad(col(0.96, 0.97, 0.98), col(0.68, 0.72, 0.78)), start: CGPoint(x: 512, y: inner.maxY), end: CGPoint(x: 512, y: inner.minY), options: [])
        ctx.setFillColor(col(0.45, 0.50, 0.58)); ctx.move(to: CGPoint(x: 540, y: 640)); ctx.addLine(to: CGPoint(x: 470, y: 520)); ctx.addLine(to: CGPoint(x: 524, y: 520)); ctx.addLine(to: CGPoint(x: 490, y: 400)); ctx.addLine(to: CGPoint(x: 590, y: 540)); ctx.addLine(to: CGPoint(x: 534, y: 540)); ctx.closePath(); ctx.fillPath()
    } else {
        ctx.drawLinearGradient(grad(col(0.30, 0.33, 0.39), col(0.10, 0.11, 0.14)), start: CGPoint(x: 512, y: 770), end: CGPoint(x: 512, y: 250), options: [])
        for i in 0..<4 { let y = CGFloat(330 + i * 100); ctx.addPath(rr(CGRect(x: 150, y: y, width: 560, height: 56), 22)); ctx.setFillColor(col(0.07, 0.08, 0.10)); ctx.fillPath()
            ctx.addEllipse(in: CGRect(x: 790, y: y + 14, width: 28, height: 28)); ctx.setFillColor(i == 1 ? col(0.2, 0.85, 1.0) : col(0.3, 0.34, 0.4)); ctx.fillPath() }
    }
    ctx.restoreGState()
    ctx.addPath(rr(body, 120)); ctx.setStrokeColor(col(1, 1, 1, 0.3)); ctx.setLineWidth(5); ctx.strokePath()
    return ctx.makeImage()!
}
let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for kind in ["ssd", "raid"] {
    let set = out.appendingPathComponent("\(kind).iconset", isDirectory: true); try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
    for (n, s) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
        let d = CGImageDestinationCreateWithURL(set.appendingPathComponent(n + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, render(s, kind: kind), nil); CGImageDestinationFinalize(d)
    }
}
print("ok")
