import Foundation

/// Port 1:1 al WhatsAppLink.swift din DataMover/GDCVault — numarul de
/// contact reconstruit din bucati, nu ca literal contiguu (evita
/// scanare usoara de crawlere in repo public).
public enum WhatsAppLink {
    private static let parts = ["34", "643", "109", "970"]

    private static var number: String { parts.joined() }

    public static func url(text: String? = nil) -> URL {
        var comps = URLComponents(string: "https://wa.me/\(number)")!
        if let text {
            comps.queryItems = [URLQueryItem(name: "text", value: text)]
        }
        return comps.url!
    }
}
