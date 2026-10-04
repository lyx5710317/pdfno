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
        .target(name: "PDFnoDOCXZIP", linkerSettings: [.linkedLibrary("z")]),
        .target(name: "PDFnoComicCodecs", exclude: ["SOURCE.json", "Licenses"], publicHeadersPath: "include",
                cSettings: [.define("HAVE_CONFIG_H", to: "1"), .headerSearchPath("private"), .headerSearchPath("libarchive"),
                            .headerSearchPath("xz/common"), .headerSearchPath("xz/liblzma/api"), .headerSearchPath("xz/liblzma/common"),
                            .headerSearchPath("xz/liblzma/check"), .headerSearchPath("xz/liblzma/lz"), .headerSearchPath("xz/liblzma/lzma"),
                            .headerSearchPath("xz/liblzma/rangecoder"), .headerSearchPath("xz/liblzma/delta"), .headerSearchPath("xz/liblzma/simple"),
                            .define("PDFNO_BOUNDED_CODECS", to: "1")],
                linkerSettings: [.linkedLibrary("z")]),
        .target(name: "PDFnoServices", dependencies: ["PDFnoDomain", "PDFnoDOCXZIP", "PDFnoComicCodecs"], resources: [.copy("Resources/ComicCodecs")]),
        .target(name: "PDFnoReaders", dependencies: ["PDFnoDomain", "PDFnoServices"], resources: [.copy("Resources/EPUB"), .copy("Resources/Comics"), .copy("Resources/DOCX"), .copy("Resources/TextFormats"), .copy("Resources/Ebooks")]),
        .target(name: "PDFnoUI", dependencies: ["PDFnoDomain", "PDFnoServices", "PDFnoReaders"],
                resources: [.copy("Resources/study-sample.pdf"), .copy("Resources/study-sample.epub"), .copy("Resources/study-sample.docx"), .copy("Resources/Ebooks")]),
        .testTarget(name: "PDFnoKitTests", dependencies: ["PDFnoDomain", "PDFnoServices", "PDFnoReaders", "PDFnoUI"],
                    resources: [.copy("Fixtures")])
    ]
)
