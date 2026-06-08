// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "image_editor_macos",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "image-editor-macos", targets: ["image_editor_macos"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "image_editor_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
