import SwiftUI
import AppKit

/// Ilustrații „Studio Glass” de prezentare (sticlă, metal, lumină). Se încarcă asincron din pachet, o singură dată, pe un fir de fundal;
/// lipsa fișierului ascunde pur și simplu ilustrația. Nu stau niciodată în spatele informației de citit și sunt ascunse de accesibilitate.
enum StudioArt {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(_ name: String) async -> NSImage? {
        if let c = cache.object(forKey: name as NSString) { return c }
        let img = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let u = Bundle.main.url(forResource: name, withExtension: "jpg") else { return nil }
            return NSImage(contentsOf: u)
        }.value
        if let img { cache.setObject(img, forKey: name as NSString) }
        return img
    }
}

struct StudioArtView: View {
    let name: String
    var width: CGFloat
    var height: CGFloat
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: width, height: height).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Studio.line))
                    .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
        .task { image = await StudioArt.image(name) }
    }
}


/// Ilustrație care umple spațiul oferit (în hero-ul de pe Acasă): decupată, cu margine stângă estompată; textul nu stă niciodată peste ea.
struct StudioArtFill: View {
    let name: String
    @State private var image: NSImage?
    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.30), .init(color: .black, location: 1)], startPoint: .leading, endPoint: .trailing))
                    .transition(.opacity)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .task { image = await StudioArt.image(name) }
    }
}
