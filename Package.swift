// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Nimbo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Nimbo", path: "Sources/Nimbo")
    ]
)
