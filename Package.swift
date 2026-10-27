// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Memoria",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MemoriaCore", targets: ["MemoriaCore"]),
        .library(name: "MemoriaWidgetSupport", targets: ["MemoriaWidgetSupport"]),
        .library(name: "MemoriaCollectors", targets: ["MemoriaCollectors"]),
        .library(name: "MemoriaServices", targets: ["MemoriaServices"]),
        .executable(name: "Memoria", targets: ["MemoriaApp"]),
        .executable(name: "MemoriaFixture", targets: ["MemoriaFixture"]),
        .executable(name: "MemoriaProbe", targets: ["MemoriaProbe"]),
        .executable(name: "MemoriaHelper", targets: ["MemoriaHelper"])
    ],
    targets: [
        .target(name: "MemoriaNative", publicHeadersPath: "include", linkerSettings: [.linkedLibrary("proc")]),
        .target(name: "MemoriaCore"),
        .target(name: "MemoriaWidgetSupport"),
        .target(name: "MemoriaCollectors", dependencies: ["MemoriaCore", "MemoriaNative"], linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "MemoriaServices", dependencies: ["MemoriaCore", "MemoriaCollectors", "MemoriaNative"], linkerSettings: [.linkedFramework("Security"), .linkedFramework("ServiceManagement")]),
        .executableTarget(name: "MemoriaApp", dependencies: ["MemoriaCore", "MemoriaCollectors", "MemoriaServices", "MemoriaWidgetSupport"], path: "App", resources: [.process("Resources")]),
        .executableTarget(name: "MemoriaHelper", dependencies: ["MemoriaServices"], path: "Helper"),
        .executableTarget(name: "MemoriaFixture", path: "Fixtures"),
        .executableTarget(name: "MemoriaProbe", dependencies: ["MemoriaCollectors", "MemoriaServices"], path: "Probe"),
        .testTarget(name: "MemoriaCoreTests", dependencies: ["MemoriaCore", "MemoriaCollectors", "MemoriaServices", "MemoriaWidgetSupport"])
    ],
    swiftLanguageModes: [.v6]
)
