import SwiftUI
import MacMasterControlProCore

/// Hartă radială: sectoare proporționale cu mărimea reală. Inel interior = elementele folderului curent, inel exterior = conținutul lor.
/// Sectoarele sub 0,4° nu se desenează individual: suma lor apare ca un singur sector „rest”, deci totalul rămâne exact.
struct SunburstView: View {
    let root: DiskTreeNode
    let selection: [UUID: DiskTreeNode]
    @Binding var hover: UUID?
    let onTap: (DiskTreeNode) -> Void
    let onDrill: (DiskTreeNode) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Arc: Identifiable {
        let id: UUID
        let node: DiskTreeNode?
        let ring: Int
        let start: Double, end: Double
        let colors: (Color, Color)
    }

    private var arcs: [Arc] { Self.layout(root: root) }

    static func layout(root: DiskTreeNode) -> [Arc] {
        let total = Double(max(root.sizeBytes, 1))
        var out: [Arc] = []
        var a = -Double.pi / 2
        for k in root.sortedChildren where k.sizeBytes > 0 {
            let sweep = Double(k.sizeBytes) / total * 2 * .pi
            let hue = Studio.hue(for: k.name)
            out.append(Arc(id: k.id, node: k, ring: 1, start: a, end: a + sweep, colors: hue))
            var b = a
            var rest: Int64 = 0
            for c in k.sortedChildren where c.sizeBytes > 0 {
                let cs = Double(c.sizeBytes) / Double(max(k.sizeBytes, 1)) * sweep
                if cs < 0.007 { rest += c.sizeBytes; continue }
                out.append(Arc(id: c.id, node: c, ring: 2, start: b, end: b + cs, colors: hue))
                b += cs
            }
            if rest > 0 {
                let cs = Double(rest) / Double(max(k.sizeBytes, 1)) * sweep
                out.append(Arc(id: UUID(), node: nil, ring: 2, start: b, end: b + cs, colors: (Studio.line, Studio.line)))
            }
            a += sweep
        }
        return out
    }

    private func radii(_ size: CGSize) -> (hole: CGFloat, r1: CGFloat, r2a: CGFloat, r2b: CGFloat) {
        let R = min(size.width, size.height) / 2 - 10
        return (R * 0.36, R * 0.70, R * 0.73, R)
    }

    private func path(center: CGPoint, r0: CGFloat, r1: CGFloat, a0: Double, a1: Double, gap: Double) -> Path {
        let s = a0 + gap, e = max(a1 - gap, s + 0.0005)
        let steps = max(2, Int(((e - s) / (.pi / 90)).rounded(.up)))
        var p = Path()
        for i in 0...steps {
            let t = s + (e - s) * Double(i) / Double(steps)
            let pt = CGPoint(x: center.x + r1 * cos(t), y: center.y + r1 * sin(t))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let t = s + (e - s) * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: center.x + r0 * cos(t), y: center.y + r0 * sin(t)))
        }
        p.closeSubpath()
        return p
    }

    private func isSel(_ n: DiskTreeNode?) -> Bool {
        guard let n else { return false }
        if selection[n.id] != nil { return true }
        // elementul face parte dintr-un părinte selectat
        var cur = (n.path as NSString).deletingLastPathComponent
        let paths = Set(selection.values.map(\.path))
        while cur.count > 1 { if paths.contains(cur) { return true }; cur = (cur as NSString).deletingLastPathComponent }
        return false
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let rr = radii(geo.size)
            let list = arcs
            ZStack {
                Canvas { ctx, size in
                    for arc in list {
                        let r0 = arc.ring == 1 ? rr.hole : rr.r2a
                        let r1 = arc.ring == 1 ? rr.r1 : rr.r2b
                        let selected = isSel(arc.node)
                        let mid = (arc.start + arc.end) / 2
                        let off: CGFloat = selected ? 7 : 0
                        var c = ctx
                        c.translateBy(x: cos(mid) * off, y: sin(mid) * off)
                        let p = path(center: center, r0: r0, r1: r1, a0: arc.start, a1: arc.end, gap: min(0.006, (arc.end - arc.start) / 4))
                        let dim = hover != nil && hover != arc.id && arc.node != nil
                        c.opacity = dim ? 0.5 : (arc.ring == 2 ? 0.82 : 1)
                        c.fill(p, with: .linearGradient(Gradient(colors: [arc.colors.0, arc.colors.1]),
                                                        startPoint: CGPoint(x: center.x - r1, y: center.y - r1),
                                                        endPoint: CGPoint(x: center.x + r1, y: center.y + r1)))
                        if selected { c.stroke(p, with: .color(.primary), lineWidth: 2.5) }
                        else if hover == arc.id { c.stroke(p, with: .color(.white.opacity(0.9)), lineWidth: 2) }
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: hover)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc): hover = hit(loc, center: center, rr: rr, list: list)?.node?.id
                    case .ended: hover = nil
                    }
                }
                .gesture(SpatialTapGesture(count: 2).onEnded { v in
                    if let n = hit(v.location, center: center, rr: rr, list: list)?.node { onDrill(n) }
                }.exclusively(before: SpatialTapGesture(count: 1).onEnded { v in
                    if let n = hit(v.location, center: center, rr: rr, list: list)?.node { onTap(n) }
                }))

                // Centru: nume + dimensiune (hover → elementul pe care ești)
                VStack(spacing: 2) {
                    let n = hover.flatMap { id in list.first { $0.id == id }?.node } ?? root
                    Text(n.name).font(.callout.weight(.semibold)).lineLimit(1).truncationMode(.middle)
                    Text(Studio.gb(n.sizeBytes)).font(.system(size: max(20, rr.hole * 0.36), weight: .bold, design: .rounded))
                    Text(n === root ? L.x("în acest folder", "in this folder", "en esta carpeta") : ByteCountFormatter.string(fromByteCount: n.sizeBytes, countStyle: .file) == "" ? "" : percent(n))
                        .font(.caption).foregroundStyle(Studio.textMuted)
                }
                .frame(width: rr.hole * 1.7)
                .allowsHitTesting(false)
            }
        }
        .accessibilityRepresentation {
            List(root.sortedChildren) { n in
                Button("\(n.name), \(Studio.gb(n.sizeBytes))") { onTap(n) }
            }
        }
    }

    private func percent(_ n: DiskTreeNode) -> String {
        let p = Double(n.sizeBytes) / Double(max(root.sizeBytes, 1)) * 100
        return String(format: p < 10 ? L.x("%.1f%% din folder", "%.1f%% of folder", "%.1f%% de la carpeta") : L.x("%.0f%% din folder", "%.0f%% of folder", "%.0f%% de la carpeta"), p).replacingOccurrences(of: ".", with: L.decimalSeparator)
    }

    private func hit(_ loc: CGPoint, center: CGPoint, rr: (hole: CGFloat, r1: CGFloat, r2a: CGFloat, r2b: CGFloat), list: [Arc]) -> Arc? {
        let dx = loc.x - center.x, dy = loc.y - center.y
        let r = (dx * dx + dy * dy).squareRoot()
        var t = atan2(dy, dx)
        if t < -.pi / 2 { t += 2 * .pi }
        let ring: Int
        if r >= rr.hole && r <= rr.r1 { ring = 1 } else if r >= rr.r2a && r <= rr.r2b { ring = 2 } else { return nil }
        return list.first { $0.ring == ring && t >= $0.start && t < $0.end }
    }
}
