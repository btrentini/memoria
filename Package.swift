// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Memoria",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "MemoriaCore", targets: ["MemoriaCore"]),
        .library(name: "MemoriaLifecycle", targets: ["MemoriaLifecycle"]),
        .library(name: "MemoriaStoreMetrics", targets: ["MemoriaStoreMetrics"]),
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
        .target(name: "MemoriaLifecycle", linkerSettings: [.linkedFramework("ServiceManagement")]),
        .target(name: "MemoriaStoreNative", publicHeadersPath: "include"),
        .target(name: "MemoriaStoreMetrics", dependencies: ["MemoriaStoreNative"], linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "MemoriaWidgetSupport"),
        .target(name: "MemoriaCollectors", dependencies: ["MemoriaCore", "MemoriaNative"], linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "MemoriaServices", dependencies: ["MemoriaCore", "MemoriaCollectors", "MemoriaNative"], linkerSettings: [.linkedFramework("Security"), .linkedFramework("ServiceManagement")]),
        .executableTarget(name: "MemoriaApp", dependencies: ["MemoriaLifecycle", "MemoriaCore", "MemoriaCollectors", "MemoriaServices", "MemoriaWidgetSupport"], path: "App", resources: [.process("Resources")]),
        .executableTarget(name: "MemoriaHelper", dependencies: ["MemoriaServices"], path: "Helper"),
        .executableTarget(name: "MemoriaFixture", path: "Fixtures"),
        .executableTarget(name: "MemoriaProbe", dependencies: ["MemoriaCollectors", "MemoriaServices"], path: "Probe"),
        .testTarget(name: "MemoriaLifecycleTests", dependencies: ["MemoriaLifecycle"]),
        .testTarget(name: "MemoriaStoreTests", dependencies: ["MemoriaStoreMetrics", "MemoriaWidgetSupport"]),
        .testTarget(name: "MemoriaCoreTests", dependencies: ["MemoriaCore", "MemoriaCollectors", "MemoriaServices", "MemoriaWidgetSupport"])
    ],
    swiftLanguageModes: [.v6]
)
