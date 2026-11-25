// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RedAlertMini",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RedAlertMini", targets: ["RedAlertMini"])
    ],
    targets: [
        .target(name: "RedAlertMini", path: "RedAlertMini")
    ]
)
