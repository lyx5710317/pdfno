// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import Combine
import UniformTypeIdentifiers
import PDFnoDomain
import PDFnoServices
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class CoverLibraryModel: ObservableObject {
    private final class WeakModel { weak var value: CoverLibraryModel?; init(_ value: CoverLibraryModel) { self.value = value } }
    private static var models: [URL: WeakModel] = [:]
    static func shared(root: URL) -> CoverLibraryModel {
        let key = root.standardizedFileURL
        if let existing = models[key]?.value { return existing }
        models = models.filter { $0.value.value != nil }
        let model = CoverLibraryModel(root: key); models[key] = WeakModel(model); return model
    }
    let repository: CoverRepository
    @Published private(set) var generations: [UUID: Int] = [:]
    @Published private(set) var busy = false
    @Published var error: String?
    init(root: URL) { repository = CoverRepository(root: root) }
    func replace(_ identity: CoverIdentity, url: URL) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { _ = try await repository.replace(identity, withLocalImage: url); generations[identity.bookID, default: 0] += 1 }
        catch { self.error = error.localizedDescription }
    }
    func restore(_ identity: CoverIdentity) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { _ = try await repository.restoreAutomatic(identity); generations[identity.bookID, default: 0] += 1 }
        catch { self.error = error.localizedDescription }
    }
}
struct LibraryCoverItem: Identifiable {
    let identity: CoverIdentity
    let title: String
    let subtitle: String
    let accessibilityID: String
    var id: UUID { identity.bookID }
}
/// Both layouts use the same source/record and lazy task. Offscreen decoded images are released.
struct LibraryCoverImage: View {
    @ObservedObject var covers: CoverLibraryModel
    let identity: CoverIdentity
    var width: CGFloat = 40
    var height: CGFloat = 56
    @State private var image: Image?
    @State private var origin = "正在载入"
    @State private var failure = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(.quaternary)
            if let image { image.resizable().scaledToFit() }
            else {
                VStack(spacing: 3) {
                    Image(systemName: identity.format == .docx ? "doc.text" : "book.closed").font(width > 60 ? .title : .body)
                    Text(identity.format.rawValue.uppercased()).font(.system(size: width > 60 ? 12 : 8, weight: .medium))
                }.foregroundStyle(.secondary)
            }
        }.frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(failure ? "封面暂不可用" : origin)
            .accessibilityIdentifier("cover-image-" + identity.bookID.uuidString)
            .task(id: "\(identity.hashValue)-\(covers.generations[identity.bookID, default: 0])") {
                image = nil; failure = false
                do {
                    let result = try await covers.repository.thumbnail(for: identity)
                    try Task.checkCancellation()
                    #if os(macOS)
                    if let data = result.png, let decoded = NSImage(data: data) { image = Image(nsImage: decoded) }
                    #else
                    if let data = result.png, let decoded = UIImage(data: data) { image = Image(uiImage: decoded) }
                    #endif
                    switch result.record.origin {
                    case .userImage: origin = "自选封面"
                    case .placeholder: origin = "默认封面"
                    default: origin = "自动封面"
                    }
                } catch is CancellationError { }
                catch { failure = true; origin = "封面暂不可用" }
            }
            .onDisappear { image = nil }
    }
}
struct LibraryCoverRow: View {
    @ObservedObject var covers: CoverLibraryModel
    let item: LibraryCoverItem
    let grid: Bool
    let edit: () -> Void
    var body: some View {
        Group {
            if grid {
                VStack(alignment: .leading, spacing: 6) {
                    LibraryCoverImage(covers: covers, identity: item.identity, width: 90, height: 124)
                    Text(item.title).font(.callout).lineLimit(2)
                    Text(item.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    LibraryCoverImage(covers: covers, identity: item.identity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline).lineLimit(2)
                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityIdentifier(item.accessibilityID)
            .contextMenu { Button("编辑封面", action: edit) }
    }
}
#if os(macOS)
struct LibraryCoverEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var covers: CoverLibraryModel
    let item: LibraryCoverItem
    @State private var importer = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LibraryCoverImage(covers: covers, identity: item.identity, width: 150, height: 208)
                Text(item.title).font(.headline).lineLimit(2)
                Text("选择本地图片作为封面，或重新生成自动封面。原书不会被改写。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("选择本地图片") { importer = true }.buttonStyle(.borderedProminent)
                    .disabled(covers.busy).accessibilityIdentifier("cover-select-image")
                Button("恢复自动封面") { Task { await covers.restore(item.identity) } }
                    .disabled(covers.busy).accessibilityIdentifier("cover-restore-automatic")
                Text("单帧 PNG / JPEG / HEIC / TIFF，最多 12 MiB、3200 万像素。仅在本地处理。")
                    .font(.caption).foregroundStyle(.secondary)
                if covers.busy { ProgressView("正在更新封面…") }
            }.padding(24).frame(width: 380, height: 450).navigationTitle("编辑封面")
                .toolbar { ToolbarItem { Button("完成") { dismiss() }.disabled(covers.busy).accessibilityIdentifier("cover-editor-done") } }
        }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.png, .jpeg, .heic, .tiff]) { result in
            switch result {
            case .success(let url): Task { await covers.replace(item.identity, url: url) }
            case .failure(let error): covers.error = error.localizedDescription
            }
        }
        .alert("封面未更新", isPresented: Binding(get: { covers.error != nil }, set: { if !$0 { covers.error = nil } })) {
            Button("知道了") { covers.error = nil }
        } message: { Text(covers.error ?? "") }
    }
}
#endif
