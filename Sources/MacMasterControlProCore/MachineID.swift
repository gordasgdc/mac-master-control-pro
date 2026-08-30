import Foundation
import IOKit

/// Identic cu implementarea din GDCVault/GDCPluginManager: IOPlatformUUID
/// citit via IOKit, folosit ca Hardware Machine ID pentru sincronizare
/// licenta cu GDC Plugin Manager.
public enum MachineID {
    public static func current() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }
        guard platformExpert != 0,
              let uuid = IORegistryEntryCreateCFProperty(
                platformExpert,
                kIOPlatformUUIDKey as CFString,
                kCFAllocatorDefault,
                0
              )?.takeRetainedValue() as? String
        else { return "UNKNOWN-MACHINE-ID" }
        return uuid
    }
}
