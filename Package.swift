// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacMasterControlPro",
    platforms: [.macOS(.v14)],
    targets: [
        // Model + licentiere + Keychain, fara UI - identic ca separare cu
        // GDCVaultCore. MachineID/LicenseCore se copiaza byte-for-byte din
        // gdc-plugin-manager-catalog-vendor pentru id-ul "mac-master-control-pro".
        .target(
            name: "MacMasterControlProCore",
            path: "Sources/MacMasterControlProCore"
        ),
        .executableTarget(
            name: "MacMasterControlPro",
            dependencies: ["MacMasterControlProCore"],
            path: "Sources/MacMasterControlPro"
        )
    ]
)
