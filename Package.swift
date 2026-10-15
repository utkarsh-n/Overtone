// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OvertoneCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "OvertoneCore", targets: ["OvertoneCore"])],
    targets: [
        .target(name: "OvertoneCore"),
        .testTarget(name: "OvertoneCoreTests", dependencies: ["OvertoneCore"])
    ]
)
