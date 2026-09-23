// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sansara",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Sansara",
            targets: ["Sansara"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Sansara",
            path: "Sources/Sansara",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
