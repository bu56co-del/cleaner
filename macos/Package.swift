// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pawly",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Pawly", targets: ["Pawly"])],
    dependencies: [.package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.20.0")],
    targets: [
        .target(name: "PawlySpawn"),
        .target(name: "PawlyCore", dependencies: ["PawlySpawn"]),
        .executableTarget(name: "Pawly", dependencies: ["PawlyCore", .product(name: "SwiftTerm", package: "SwiftTerm")], resources: [.process("Resources")]),
        .testTarget(name: "PawlyCoreTests", dependencies: ["PawlyCore"]),
        .testTarget(name: "PawlyUITests", dependencies: ["Pawly"])
    ]
)
