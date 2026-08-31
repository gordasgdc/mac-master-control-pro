import Foundation
import AppKit
import ApplicationServices

/// Poziția/dimensiunea salvată a UNEI ferestre, identificată după titlu +
/// indexul ei printre ferestrele cu același titlu (Accessibility API nu
/// oferă un ID STABIL de fereastră între relansări ale aplicației).
public struct SavedWindowFrame: Codable, Hashable {
    public let title: String
    public let titleIndex: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct WindowLayoutProfile: Codable, Identifiable, Hashable {
    public var id: String { name }
    public let name: String
    public let appBundleID: String
    public let frames: [SavedWindowFrame]
    public let savedAt: Date
}

/// Profile de layout multi-monitor (2026-08-31, Nivel 3 #8) - salvează și
/// restaurează pozițiile ferestrelor unei aplicații (DaVinci Resolve, sau
/// oricare alta) - util pentru clienți care schimbă frecvent între
/// configurații de monitoare (ex. "acasă" vs "la client") sau între
/// pagini/layout-uri diferite de lucru în Resolve.
public enum WindowLayoutService {
    private static let storeKey = "MacMasterControlPro.windowLayoutProfiles"

    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Deschide promptul nativ macOS de cerere a permisiunii de
    /// Accesibilitate (o singură dată - macOS reține alegerea).
    public static func requestAccessibilityIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func runningApps() -> [(name: String, bundleID: String, pid: pid_t)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let name = app.localizedName, let bundleID = app.bundleIdentifier else { return nil }
                return (name, bundleID, app.processIdentifier)
            }
            .sorted { $0.name < $1.name }
    }

    /// Salvează pozițiile TUTUROR ferestrelor vizibile ale aplicației date.
    public static func saveLayout(name: String, appBundleID: String, pid: pid_t) -> Bool {
        guard isAccessibilityTrusted else { return false }
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement], !windows.isEmpty
        else { return false }

        var titleCounts: [String: Int] = [:]
        var frames: [SavedWindowFrame] = []
        for window in windows {
            let title = windowTitle(window) ?? "Fereastră"
            let index = titleCounts[title, default: 0]
            titleCounts[title] = index + 1
            guard let (x, y) = windowPosition(window), let (w, h) = windowSize(window) else { continue }
            frames.append(SavedWindowFrame(title: title, titleIndex: index, x: x, y: y, width: w, height: h))
        }
        guard !frames.isEmpty else { return false }

        var profiles = allProfiles().filter { $0.name != name }
        profiles.append(WindowLayoutProfile(name: name, appBundleID: appBundleID, frames: frames, savedAt: Date()))
        persist(profiles)
        return true
    }

    /// Restaurează un profil salvat - potrivește ferestrele curente ale
    /// aplicației după (titlu, index), ignoră ferestrele care nu se mai
    /// potrivesc (aplicația poate avea acum mai puține/mai multe ferestre).
    @discardableResult
    public static func restoreLayout(_ profile: WindowLayoutProfile, pid: pid_t) -> Int {
        guard isAccessibilityTrusted else { return 0 }
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return 0 }

        var titleCounts: [String: Int] = [:]
        var restored = 0
        for window in windows {
            let title = windowTitle(window) ?? "Fereastră"
            let index = titleCounts[title, default: 0]
            titleCounts[title] = index + 1
            guard let frame = profile.frames.first(where: { $0.title == title && $0.titleIndex == index }) else { continue }
            setWindowPosition(window, x: frame.x, y: frame.y)
            setWindowSize(window, width: frame.width, height: frame.height)
            restored += 1
        }
        return restored
    }

    public static func allProfiles() -> [WindowLayoutProfile] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let profiles = try? JSONDecoder().decode([WindowLayoutProfile].self, from: data)
        else { return [] }
        return profiles.sorted { $0.savedAt > $1.savedAt }
    }

    public static func deleteProfile(named name: String) {
        persist(allProfiles().filter { $0.name != name })
    }

    private static func persist(_ profiles: [WindowLayoutProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    // MARK: - Accessibility helpers de nivel scazut

    private static func windowTitle(_ window: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func windowPosition(_ window: AXUIElement) -> (Double, Double)? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &ref) == .success else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(ref as! AXValue, .cgPoint, &point) else { return nil }
        return (Double(point.x), Double(point.y))
    }

    private static func windowSize(_ window: AXUIElement) -> (Double, Double)? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &ref) == .success else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(ref as! AXValue, .cgSize, &size) else { return nil }
        return (Double(size.width), Double(size.height))
    }

    private static func setWindowPosition(_ window: AXUIElement, x: Double, y: Double) {
        var point = CGPoint(x: x, y: y)
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func setWindowSize(_ window: AXUIElement, width: Double, height: Double) {
        var size = CGSize(width: width, height: height)
        guard let value = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }
}
