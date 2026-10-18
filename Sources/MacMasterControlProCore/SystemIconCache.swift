import AppKit

/// Iconurile NATIVE ale volumelor, folderelor și aplicațiilor (inclusiv iconurile personalizate existente,
/// ex. `.VolumeIcon.icns`), obținute de la sistem prin `NSWorkspace.icon(forFile:)`. Se încarcă pe un
/// thread de fundal și se rețin într-un cache, ca afișarea interfeței să nu aștepte niciodată după disc.
public final class SystemIconCache: @unchecked Sendable {
    public static let shared = SystemIconCache()
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.gordasgdc.macmastercontrolpro.icons", qos: .utility, attributes: .concurrent)
    private init() { cache.countLimit = 600 }

    /// Intoarce imediat iconul din cache, daca exista (pentru redesenari fara salt).
    public func cached(path: String) -> NSImage? { cache.object(forKey: path as NSString) }

    /// Incarca asincron; nu blocheaza thread-ul apelant. Un fisier lipsa primeste iconul generic al tipului.
    public func icon(forPath path: String) async -> NSImage {
        if let hit = cached(path: path) { return hit }
        return await withCheckedContinuation { cont in
            queue.async {
                let img = NSWorkspace.shared.icon(forFile: path)
                self.cache.setObject(img, forKey: path as NSString)
                cont.resume(returning: img)
            }
        }
    }

    public func invalidate(path: String) { cache.removeObject(forKey: path as NSString) }
}
