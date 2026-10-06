// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Battlify",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Battlify", targets: ["Battlify"]),
        .executable(name: "battlify-helper", targets: ["battlify-helper"]),
        .executable(name: "battlify-mcp", targets: ["battlify-mcp"]),
        .executable(name: "licensetool", targets: ["licensetool"])
    ],
    targets: [
        // Low-level SMC access (C). Requires root to *write*.
        .target(
            name: "CSMC",
            path: "Sources/CSMC"
        ),
        // macOS's own charge limit (System Settings › Battery › Charge Limit), reached
        // through the private PowerUI framework at runtime. The only way to stop charging
        // on firmware that gates the SMC charge keys.
        .target(
            name: "CPowerUI",
            path: "Sources/CPowerUI",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        // Shared Swift library used by both the GUI and the privileged helper.
        .target(
            name: "BattlifyKit",
            dependencies: ["CSMC", "CPowerUI"],
            path: "Sources/BattlifyKit"
        ),
        // The menu bar GUI app (runs as the user).
        .executableTarget(
            name: "Battlify",
            dependencies: ["BattlifyKit"],
            path: "Sources/Battlify",
            linkerSettings: [
                // Wi-Fi power control.
                .linkedFramework("CoreWLAN"),
                // Bluetooth power control (private IOBluetoothPreference* symbols).
                .linkedFramework("IOBluetooth"),
                // Display brightness control (private DisplayServices framework).
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-framework", "DisplayServices"
                ])
            ]
        ),
        // The privileged daemon/CLI (runs as root) that enforces the charge limit.
        .executableTarget(
            name: "battlify-helper",
            dependencies: ["BattlifyKit"],
            path: "Sources/battlify-helper"
        ),
        // MCP server on stdio (runs as the user, launched by an AI agent): lets the agent
        // keep the Mac awake for a long task, through the helper's control socket.
        .executableTarget(
            name: "battlify-mcp",
            dependencies: ["BattlifyKit"],
            path: "Sources/battlify-mcp"
        ),
        // Seller-side license key generator/signer (not shipped in the app).
        .executableTarget(
            name: "licensetool",
            dependencies: ["BattlifyKit"],
            path: "Sources/licensetool"
        ),
        // Unit tests + benchmarks for the shared library (charge logic, Caffeine, …).
        .testTarget(
            name: "BattlifyKitTests",
            dependencies: ["BattlifyKit"],
            path: "Tests/BattlifyKitTests"
        )
    ]
)
