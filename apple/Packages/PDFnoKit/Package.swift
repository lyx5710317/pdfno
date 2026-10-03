// swift-tools-version: 6.0
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "PDFnoKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PDFnoUI", targets: ["PDFnoUI"]),
        .library(name: "PDFnoDomain", targets: ["PDFnoDomain"]),
        .library(name: "PDFnoServices", targets: ["PDFnoServices"]),
        .library(name: "PDFnoReaders", targets: ["PDFnoReaders"])
    ],
    targets: [
        .target(name: "PDFnoDomain"),
        .target(name: "PDFnoServices", dependencies: ["PDFnoDomain"]),
        .target(name: "PDFnoReaders", dependencies: ["PDFnoDomain", "PDFnoServices"], resources: [.copy("Resources/EPUB"), .copy("Resources/Comics")]),
        .target(name: "PDFnoUI", dependencies: ["PDFnoDomain", "PDFnoServices", "PDFnoReaders"],
                resources: [.copy("Resources/study-sample.pdf"), .copy("Resources/study-sample.epub")]),
        .testTarget(name: "PDFnoKitTests", dependencies: ["PDFnoDomain", "PDFnoServices", "PDFnoReaders", "PDFnoUI"],
                    resources: [.copy("Fixtures")])
    ]
)
