import SwiftUI
import AppKit
import MacMasterControlProCore

/// Icon de sistem pentru o cale (volum, folder, aplicatie). Marcajul de loc ramane vizibil pana soseste iconul.
struct SystemIconView: View {
    let path: String
    var size: CGFloat = 40
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().interpolation(.high) }
            else { RoundedRectangle(cornerRadius: size * 0.2).fill(.quaternary) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: path) {
            if let hit = SystemIconCache.shared.cached(path: path) { image = hit; return }
            image = await SystemIconCache.shared.icon(forPath: path)
        }
    }
}
