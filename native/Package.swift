// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PDFnoBridge", platforms: [.macOS(.v13)], products: [.executable(name: "PDFnoBridge", targets: ["PDFnoBridge"])], targets: [.executableTarget(name: "PDFnoBridge")])
