import Foundation
import Security

/// Stare de sanatate a unui disc montat (2026-08-31, Nivel 1 #3) - un
/// disc de scratch/cache aproape plin sau pe moarte e cea mai frecventa
/// cauza reala de "Resolve se blocheaza"/randari care esueaza la mijloc.
public struct DiskHealth: Identifiable {
    public var id: String { mountPath }
    public let name: String
    public let mountPath: String
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let isInternal: Bool
    /// "Verified"/"Failing"/"Not Supported" (extern, unele SSD-uri externe
    /// nu raporteaza SMART prin USB) - `nil` daca `diskutil` n-a raspuns.
    public var smartStatus: String?
    /// Viteza masurata la ultimul test manual (MB/s) - `nil` pana userul
    /// apasa "Testeaza viteza" pentru acest disc (test explicit, NU automat
    /// pentru toate discurile - ar scrie fisiere de test peste tot fara sa
    /// fie cerut).
    public var writeSpeedMBps: Double?

    public var freePercent: Double {
        totalBytes > 0 ? Double(availableBytes) / Double(totalBytes) * 100 : 0
    }
    /// Prag orientativ - sub 10% liber pe un disc de scratch e deja cauza
    /// tipica de fragmentare/erori la scriere de fisiere media mari.
    public var isLowSpace: Bool { freePercent < 10 }
    public var isFailing: Bool { smartStatus?.localizedCaseInsensitiveContains("fail") ?? false }
}

public enum DiskHealthService {
    /// Toate volumele montate, vizibile in Finder (exclude volume ascunse
    /// de sistem) - fiecare cu status SMART citit din `diskutil info`.
    public static func scanVolumes() -> [DiskHealth] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeIsInternalKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        return urls.compactMap { url -> DiskHealth? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let name = values.volumeName,
                  let total = values.volumeTotalCapacity,
                  let available = values.volumeAvailableCapacity
            else { return nil }
            let isInternal = values.volumeIsInternal ?? true
            var health = DiskHealth(
                name: name, mountPath: url.path,
                totalBytes: Int64(total), availableBytes: Int64(available),
                isInternal: isInternal, smartStatus: nil, writeSpeedMBps: nil
            )
            health.smartStatus = smartStatus(forMountPath: url.path)
            return health
        }.sorted { $0.name < $1.name }
    }

    private static func smartStatus(forMountPath path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            for line in text.split(separator: "\n") where line.contains("SMART Status") {
                return line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces)
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Test de scriere real - 256 MB de date aleatorii, masurat direct,
    /// NU citit din specificatiile discului (un SSD extern prin un cablu
    /// prost poate merge la o fractiune din viteza lui reala). Fisierul
    /// se sterge imediat dupa masuratoare.
    public static func measureWriteSpeed(mountPath: String) -> Double? {
        let testFile = (mountPath as NSString).appendingPathComponent(".mmc_speedtest_\(UUID().uuidString).bin")
        let sizeBytes = 256 * 1024 * 1024
        guard let data = randomData(count: sizeBytes) else { return nil }
        let start = Date()
        do {
            try data.write(to: URL(fileURLWithPath: testFile))
        } catch {
            return nil
        }
        let elapsed = Date().timeIntervalSince(start)
        try? FileManager.default.removeItem(atPath: testFile)
        guard elapsed > 0 else { return nil }
        return (Double(sizeBytes) / 1_048_576) / elapsed
    }

    private static func randomData(count: Int) -> Data? {
        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return result == errSecSuccess ? data : nil
    }
}
