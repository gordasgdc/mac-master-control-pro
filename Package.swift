// swift-tools-version:5.9
import PackageDescription
import Foundation

// Ediția comunitară: fără dependențe externe, ruleaza in Demo.
// Ediția oficială (doar build-ul GDC): variabila GDC_COMMERCIAL_CORE_PATH arată spre core-ul comercial privat, iar un director
// `Sources/MacMasterControlProOfficial` (legătură simbolică ignorată de Git, creată de scriptul privat de build) conține
// adaptorul `AccessProviding`. Niciun cod privat nu e în acest repository.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let corePath = ProcessInfo.processInfo.environment["GDC_COMMERCIAL_CORE_PATH"]
let officialAdapter = root.appendingPathComponent("Sources/MacMasterControlProOfficial").path
let official = corePath != nil && FileManager.default.fileExists(atPath: officialAdapter)

var dependencies: [Package.Dependency] = []
var targets: [Target] = [
    .target(name: "MacMasterControlProCore", path: "Sources/MacMasterControlProCore"),
    .executableTarget(name: "mcsp-bench", dependencies: ["MacMasterControlProCore"], path: "Sources/mcsp-bench"),
    .testTarget(name: "MacMasterControlProCoreTests", dependencies: ["MacMasterControlProCore"], path: "Tests/MacMasterControlProCoreTests"),
]
var appDependencies: [Target.Dependency] = ["MacMasterControlProCore"]
var appSettings: [SwiftSetting] = []

if official, let corePath {
    dependencies.append(.package(path: corePath))
    targets.append(.target(
        name: "MacMasterControlProOfficial",
        dependencies: ["MacMasterControlProCore", .product(name: "GDCCommercialCore", package: URL(fileURLWithPath: corePath).lastPathComponent)],
        path: "Sources/MacMasterControlProOfficial"))
    appDependencies.append("MacMasterControlProOfficial")
    appSettings.append(.define("OFFICIAL_BUILD"))
}

targets.append(.executableTarget(name: "MacMasterControlPro", dependencies: appDependencies, path: "Sources/MacMasterControlPro", swiftSettings: appSettings))

let package = Package(
    name: "MacMasterControlPro",
    platforms: [.macOS(.v14)],
    dependencies: dependencies,
    targets: targets
)
