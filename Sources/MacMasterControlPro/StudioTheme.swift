import SwiftUI
import AppKit
import MacMasterControlProCore

/// Sistemul vizual „Studio Glass”: suprafețe de porțelan (luminos) sau grafit (întunecat), sticlă doar în bara laterală,
/// un singur accent pentru acțiunea principală. Culorile sunt dinamice (urmează aspectul sistemului), niciuna literală pe controale.
enum Studio {
    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
    }
    static let accent = dynamic(light: NSColor(srgbRed: 0.18, green: 0.42, blue: 0.94, alpha: 1), dark: NSColor(srgbRed: 0.35, green: 0.55, blue: 1.0, alpha: 1))
    static let canvasTop = dynamic(light: NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: 1), dark: NSColor(srgbRed: 0.09, green: 0.105, blue: 0.125, alpha: 1))
    static let canvasBottom = dynamic(light: NSColor(srgbRed: 0.955, green: 0.96, blue: 0.97, alpha: 1), dark: NSColor(srgbRed: 0.075, green: 0.085, blue: 0.10, alpha: 1))
    static let card = dynamic(light: .white, dark: NSColor(srgbRed: 0.115, green: 0.135, blue: 0.16, alpha: 1))
    static let line = dynamic(light: NSColor(srgbRed: 0.87, green: 0.885, blue: 0.9, alpha: 1), dark: NSColor(srgbRed: 0.18, green: 0.21, blue: 0.245, alpha: 1))
    static let textMuted = dynamic(light: NSColor(srgbRed: 0.32, green: 0.36, blue: 0.40, alpha: 1), dark: NSColor(srgbRed: 0.62, green: 0.67, blue: 0.72, alpha: 1))
    static let good = dynamic(light: NSColor(srgbRed: 0.07, green: 0.48, blue: 0.33, alpha: 1), dark: NSColor(srgbRed: 0.44, green: 0.88, blue: 0.68, alpha: 1))
    static let goodBG = dynamic(light: NSColor(srgbRed: 0.84, green: 0.94, blue: 0.90, alpha: 1), dark: NSColor(srgbRed: 0.09, green: 0.22, blue: 0.17, alpha: 1))
    static let dupe = dynamic(light: NSColor(srgbRed: 0.36, green: 0.25, blue: 0.77, alpha: 1), dark: NSColor(srgbRed: 0.73, green: 0.66, blue: 1, alpha: 1))
    static let dupeBG = dynamic(light: NSColor(srgbRed: 0.90, green: 0.87, blue: 0.98, alpha: 1), dark: NSColor(srgbRed: 0.17, green: 0.15, blue: 0.34, alpha: 1))
    static let caution = dynamic(light: NSColor(srgbRed: 0.70, green: 0.21, blue: 0.12, alpha: 1), dark: NSColor(srgbRed: 1, green: 0.60, blue: 0.52, alpha: 1))
    static let lock = dynamic(light: NSColor(srgbRed: 0.30, green: 0.35, blue: 0.42, alpha: 1), dark: NSColor(srgbRed: 0.65, green: 0.70, blue: 0.75, alpha: 1))

    /// Perechi (început, sfârșit) de gradient, alese stabil după numele elementului ca să nu se schimbe la navigare.
    static let hues: [(Color, Color)] = [
        (Color(red: 0.49, green: 0.64, blue: 1.0), Color(red: 0.23, green: 0.37, blue: 0.88)),   // cobalt
        (Color(red: 0.31, green: 0.82, blue: 0.77), Color(red: 0.06, green: 0.56, blue: 0.54)),  // lagună
        (Color(red: 1.0, green: 0.77, blue: 0.42), Color(red: 0.91, green: 0.53, blue: 0.12)),   // chihlimbar
        (Color(red: 0.76, green: 0.65, blue: 1.0), Color(red: 0.48, green: 0.32, blue: 0.85)),   // orhidee
        (Color(red: 1.0, green: 0.62, blue: 0.71), Color(red: 0.83, green: 0.29, blue: 0.45)),   // trandafir
        (Color(red: 0.55, green: 0.86, blue: 0.55), Color(red: 0.20, green: 0.62, blue: 0.33)),  // jad
        (Color(red: 0.55, green: 0.80, blue: 1.0), Color(red: 0.15, green: 0.55, blue: 0.85)),   // cer
        (Color(red: 0.72, green: 0.76, blue: 0.82), Color(red: 0.46, green: 0.51, blue: 0.58)),  // ardezie
    ]
    static func hue(for name: String) -> (Color, Color) {
        var h: UInt32 = 5381
        for u in name.unicodeScalars { h = (h &* 33) &+ u.value }
        return hues[Int(h % UInt32(hues.count))]
    }

    static func gb(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Eticheta unei stări: text + pictogramă (forma poartă sensul, nu doar culoarea).
struct FlagChip: View {
    let flag: SpaceFlag
    var body: some View {
        let (icon, text, fg, bg): (String, String, Color, Color) = {
            switch flag {
            case .regenerable: return ("arrow.triangle.2.circlepath", "Regenerabil", Studio.good, Studio.goodBG)
            case .duplicate: return ("doc.on.doc", "Duplicat verificat", Studio.dupe, Studio.dupeBG)
            case .protected: return ("lock.fill", "Protejat", Studio.lock, Studio.line)
            }
        }()
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg, in: flag == .regenerable ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: 5)))
    }
}
