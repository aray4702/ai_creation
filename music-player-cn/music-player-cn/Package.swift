// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MusicPlayerCN",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MusicPlayerCN", targets: ["MusicPlayerCN"])
    ],
    targets: [
        .executableTarget(
            name: "MusicPlayerCN",
            path: "Sources/MusicPlayerCN"
        )
    ]
)
