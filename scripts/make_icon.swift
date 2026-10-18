// Generator procedural al iconului „Studio Glass” (fără resurse terțe). Uz: swift scripts/make_icon.swift <folder-iesire>
// Produce AppIcon.iconset (PNG) + master 1024 + icon.ico (PNG-uri incluse) — același desen vectorial la fiecare dimensiune.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func squircle(_ r: CGRect, n: Double = 5.0) -> CGPath {
    let p = CGMutablePath(); let steps = 360
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = r.midX + CGFloat(copysign(pow(abs(c), 2 / n), c)) * r.width / 2
        let y = r.midY + CGFloat(copysign(pow(abs(s), 2 / n), s)) * r.height / 2
        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
    }
    p.closeSubpath(); return p
}
func col(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func grad(_ cs: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient { CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cs as CFArray, locations: locs)! }

func sector(_ c: CGPoint, r0: CGFloat, r1: CGFloat, a0: Double, a1: Double) -> CGPath {
    let p = CGMutablePath(); let steps = max(8, Int((a1 - a0) / (.pi / 120)))
    for i in 0...steps { let t = a0 + (a1 - a0) * Double(i) / Double(steps); let pt = CGPoint(x: c.x + r1 * CGFloat(cos(t)), y: c.y + r1 * CGFloat(sin(t))); i == 0 ? p.move(to: pt) : p.addLine(to: pt) }
    for i in stride(from: steps, through: 0, by: -1) { let t = a0 + (a1 - a0) * Double(i) / Double(steps); p.addLine(to: CGPoint(x: c.x + r0 * CGFloat(cos(t)), y: c.y + r0 * CGFloat(sin(t)))) }
    p.closeSubpath(); return p
}

func render(size: Int) -> CGImage {
    let S = CGFloat(size), k = S / 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: k, y: k)
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(body)
    // umbră
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: col(0, 0, 0.05, 0.45)); ctx.addPath(shape); ctx.setFillColor(col(0.07, 0.10, 0.22)); ctx.fillPath(); ctx.restoreGState()
    // corp: sticlă de cobalt închis
    ctx.saveGState(); ctx.addPath(shape); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.20, 0.30, 0.62), col(0.07, 0.10, 0.26)]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // lumină controlată: strălucire largă sus
    ctx.drawRadialGradient(grad([col(1, 1, 1, 0.28), col(1, 1, 1, 0)]), startCenter: CGPoint(x: 400, y: 860), startRadius: 0, endCenter: CGPoint(x: 400, y: 860), endRadius: 520, options: [])
    // glifa: hartă radială, un sector ridicat (selecția)
    let c = CGPoint(x: 512, y: 500)
    let hues: [(CGColor, CGColor)] = [
        (col(0.55, 0.72, 1.0), col(0.22, 0.40, 0.92)),   // cobalt
        (col(0.36, 0.86, 0.80), col(0.05, 0.55, 0.55)),  // lagună
        (col(1.0, 0.80, 0.42), col(0.93, 0.55, 0.12)),   // chihlimbar (selectat)
        (col(0.78, 0.66, 1.0), col(0.46, 0.30, 0.86)),   // orhidee
        (col(1.0, 0.62, 0.72), col(0.84, 0.28, 0.46)),   // trandafir
    ]
    let sweeps: [Double] = [0.31, 0.24, 0.20, 0.15, 0.10]
    var a = -Double.pi / 2 - 0.2
    for (i, sw) in sweeps.enumerated() {
        let a0 = a + 0.025, a1 = a + sw * 2 * .pi - 0.025
        let mid = (a0 + a1) / 2
        let lift: CGFloat = i == 2 ? 30 : 0
        ctx.saveGState(); ctx.translateBy(x: lift * CGFloat(cos(mid)), y: lift * CGFloat(sin(mid)))
        let ring1 = sector(c, r0: 120, r1: 262, a0: a0, a1: a1)
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: col(0, 0, 0.1, 0.35))
        ctx.addPath(ring1); ctx.clip()
        ctx.drawLinearGradient(grad([hues[i].0, hues[i].1]), start: CGPoint(x: c.x - 260, y: c.y + 260), end: CGPoint(x: c.x + 260, y: c.y - 260), options: [])
        ctx.resetClip(); ctx.addPath(shape); ctx.clip()
        if i == 2 { ctx.addPath(ring1); ctx.setStrokeColor(col(1, 1, 1, 0.95)); ctx.setLineWidth(7); ctx.strokePath() }
        // inel exterior subțire (conținutul sectorului)
        if i < 3 { let ring2 = sector(c, r0: 276, r1: 330, a0: a0, a1: a0 + (a1 - a0) * (i == 1 ? 0.55 : 0.8)); ctx.addPath(ring2); ctx.clip(); ctx.drawLinearGradient(grad([hues[i].0, hues[i].1]), start: CGPoint(x: c.x - 330, y: c.y + 330), end: CGPoint(x: c.x + 330, y: c.y - 330), options: []); ctx.resetClip(); ctx.addPath(shape); ctx.clip() }
        ctx.restoreGState()
        a += sw * 2 * .pi
    }
    // gaura centrală de sticlă
    ctx.drawRadialGradient(grad([col(1, 1, 1, 0.55), col(0.82, 0.88, 1, 0.18)]), startCenter: CGPoint(x: c.x - 20, y: c.y + 30), startRadius: 0, endCenter: c, endRadius: 108, options: [])
    ctx.restoreGState()
    // muchie de sticlă
    ctx.addPath(shape); ctx.setStrokeColor(col(1, 1, 1, 0.22)); ctx.setLineWidth(3); ctx.strokePath()
    return ctx.makeImage()!
}

func write(_ img: CGImage, to url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-out", isDirectory: true)
let set = out.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
let names: [(String, Int)] = [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128), ("icon_128x128@2x", 256),
                              ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024)]
for (n, s) in names { write(render(size: s), to: set.appendingPathComponent(n + ".png")) }
write(render(size: 1024), to: out.appendingPathComponent("master-1024.png"))
// ICO cu PNG-uri incluse (Windows Vista+)
let ico = [16, 24, 32, 48, 64, 128, 256]
var entries = Data(); var blobs = [Data]()
for s in ico {
    let tmp = out.appendingPathComponent("ico-\(s).png"); write(render(size: s), to: tmp); blobs.append(try! Data(contentsOf: tmp)); try? FileManager.default.removeItem(at: tmp)
}
var header = Data([0, 0, 1, 0]); header.append(contentsOf: withUnsafeBytes(of: UInt16(ico.count).littleEndian) { Array($0) })
var offset = 6 + 16 * ico.count
for (i, s) in ico.enumerated() {
    entries.append(UInt8(s == 256 ? 0 : s)); entries.append(UInt8(s == 256 ? 0 : s)); entries.append(contentsOf: [0, 0, 1, 0, 32, 0])
    entries.append(contentsOf: withUnsafeBytes(of: UInt32(blobs[i].count).littleEndian) { Array($0) })
    entries.append(contentsOf: withUnsafeBytes(of: UInt32(offset).littleEndian) { Array($0) }); offset += blobs[i].count
}
try! (header + entries + blobs.reduce(Data(), +)).write(to: out.appendingPathComponent("icon.ico"))
print("ok")
