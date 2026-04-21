// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MisarMail",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [
        .library(name: "MisarMail", targets: ["MisarMail"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MisarMail",
            path: "swift/Sources/MisarMail"
        ),
        .testTarget(
            name: "MisarMailTests",
            dependencies: ["MisarMail"],
            path: "swift/Tests/MisarMailTests"
        ),
    ]
)
