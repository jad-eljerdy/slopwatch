// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Slopwatch",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "Slopwatch", resources: [.copy("Resources/rates.tsv"), .copy("Resources/ProviderIcons")]),
        .testTarget(name: "SlopwatchTests", dependencies: ["Slopwatch"]),
    ],
    swiftLanguageModes: [.v6]
)
