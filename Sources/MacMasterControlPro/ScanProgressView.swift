import SwiftUI
import AppKit

/// Panou de scanare animat — componenta UNICA, folosita si de Analiză Disc,
/// si de Duplicate (2026-09-11). Inspirata din Gemini, dar desenata PROCEDURAL
/// (`Canvas` + `TimelineView`), fara nicio imagine bundle-uita: inelele sunt
/// cateva zeci de arce pe cadru, nu asset-uri de incarcat.
///
/// Doua decizii care conteaza:
///
/// 1. **Arcul se adapteaza la ce stim.** In faza de enumerare nu exista un
///    total (nu stii cate fisiere ai pana nu le numeri pe toate), deci un
///    procent ar fi o minciuna — arcul se roteste continuu. Din momentul in
///    care numarul de candidati e cunoscut, devine procent real. `fraction ==
///    nil` comuta intre cele doua moduri.
/// 2. **Respecta Reduce Motion** (Regula 24): cu animatiile de sistem oprite,
///    inelele si rotatia stau, iar informatia ramane integral vizibila —
///    animatia e decor, nu purtatorul informatiei.
struct ScanProgressView: View {
    let title: String
    let detailPath: String
    let itemsLabel: String
    let totalLabel: String
    /// `nil` = progres necunoscut (arc rotativ), altfel 0...1 (arc procentual).
    let fraction: Double?
    let tint: Color
    /// Calea din care se extrage iconita NATIVA a volumului/folderului.
    let iconPath: String?
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 20) {
            dial
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                if !detailPath.isEmpty {
                    // Trunchiere la MIJLOC: inceputul (volumul) si sfarsitul
                    // (numele fisierului) sunt partile utile; mijlocul nu.
                    Text(detailPath)
                        .font(.caption).monospaced()
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                HStack(spacing: 14) {
                    Label(itemsLabel, systemImage: "doc")
                    Label(totalLabel, systemImage: "internaldrive")
                }
                .font(.caption).foregroundStyle(.secondary)

                Button("Stop", action: onStop)
                    .controlSize(.small)
                    .help("Oprește scanarea acum.")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.35)))
    }

    private var dial: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { ctx, size in
                    drawRipples(ctx: ctx, size: size, time: t)
                    drawProgressArc(ctx: ctx, size: size, time: t)
                }
                icon
            }
        }
        .frame(width: 120, height: 120)
    }

    /// Inele radiale — „valuri" care pleaca din centru si se sting spre margine.
    private func drawRipples(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxR = min(size.width, size.height) / 2
        let ringCount = 4
        for i in 0..<ringCount {
            // Fiecare inel e defazat, ca sa iasa unul dupa altul, nu toate odata.
            let phase = reduceMotion ? Double(i) / Double(ringCount)
                                     : (time * 0.35 + Double(i) / Double(ringCount)).truncatingRemainder(dividingBy: 1)
            let r = maxR * (0.35 + 0.65 * phase)
            // Se sting pe masura ce se departeaza — altfel ar fi patru cercuri
            // fixe, nu un efect de val.
            let opacity = (1 - phase) * 0.28
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)), lineWidth: 1.2)
        }
    }

    private func drawProgressArc(ctx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = min(size.width, size.height) / 2 - 6
        var path = Path()

        if let fraction {
            // Progres REAL cunoscut: arc de la 12 fix, in sensul acelor.
            let end = Angle.degrees(-90 + 360 * min(max(fraction, 0), 1))
            path.addArc(center: center, radius: r, startAngle: .degrees(-90), endAngle: end, clockwise: false)
        } else {
            // Progres necunoscut: un arc de 100 de grade care se roteste. Nu
            // pretinde niciun procent — comunica doar „lucrez".
            let start = Angle.degrees(reduceMotion ? -90 : (time * 120).truncatingRemainder(dividingBy: 360) - 90)
            path.addArc(center: center, radius: r, startAngle: start, endAngle: start + .degrees(100), clockwise: false)
        }

        ctx.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [tint, tint.opacity(0.35)]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            ),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
        )
    }

    /// Iconita REALA a volumului/folderului, luata din sistem — acelasi desen
    /// pe care userul il vede in Finder, nu un simbol generic.
    @ViewBuilder
    private var icon: some View {
        if let iconPath, FileManager.default.fileExists(atPath: iconPath) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: iconPath))
                .resizable().scaledToFit().frame(width: 46, height: 46)
        } else {
            Image(systemName: "internaldrive")
                .font(.system(size: 30))
                .foregroundStyle(tint)
        }
    }
}
