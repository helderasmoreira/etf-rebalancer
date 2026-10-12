// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ETFRebalancer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "RebalancerCore"),
        .executableTarget(name: "ETFRebalancer", dependencies: ["RebalancerCore"]),
        .testTarget(name: "RebalancerCoreTests", dependencies: ["RebalancerCore"]),
    ]
)
