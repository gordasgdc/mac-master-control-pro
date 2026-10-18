import Foundation

/// Port 1:1 al WhatsAppLink.swift din DataMover/GDCVault — numarul de
/// contact reconstruit din bucati, nu ca literal contiguu (evita
/// scanare usoara de crawlere in repo public).
public enum WhatsAppLink {
    private static let parts = ["34", "643", "109", "970"]

    private static var number: String { parts.joined() }

    public static func url(text: String? = nil) -> URL {
        guard let text else { return URL(string: "https://wa.me/\(number)")! }
        return URL(string: "https://wa.me/\(number)?text=\(encode(text))")!
    }

    /// Codificare procentuală completă (UTF-8): doar caracterele nerezervate rămân literale, deci `+`, `&`, `#`, newline și diacriticele ajung intacte.
    public static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")) ?? ""
    }
}
