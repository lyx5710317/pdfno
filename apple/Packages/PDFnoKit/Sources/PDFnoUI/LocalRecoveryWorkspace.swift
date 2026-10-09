// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import UniformTypeIdentifiers
import PDFnoDomain
import PDFnoServices

/// Integration supplies the pause/drain/reload lifecycle. No default implementation
/// can authorize writes while an existing reader or repository is still active.
public typealias LocalRecoveryPausedOperation = @Sendable (LocalRecoveryWritePermit) async throws -> Void
public typealias LocalRecoveryHostPause = @MainActor (@escaping LocalRecoveryPausedOperation) async throws -> Void

@MainActor public final class LocalRecoveryManagementModel: ObservableObject {
    @Published public private(set) var books: [LocalRecoveryBook] = []
    @Published public private(set) var tombstones: [LocalRecoveryTombstone] = []
    @Published public private(set) var changePreview: LocalRecoveryChangePreview?
    @Published public private(set) var backupPreview: LocalRecoveryPreview?
    @Published public private(set) var busy = false
    @Published public private(set) var lastExportedParent: URL?
    @Published public private(set) var lastExportedPackage: URL?
    @Published public private(set) var message = "回收站一直保留。原件与已保存笔记可恢复；未保存草稿不进入备份。"
    private let service: LocalRecoveryService
    private let pause: LocalRecoveryHostPause
    private var package: URL?
    public init(service: LocalRecoveryService, withPausedWriters: @escaping LocalRecoveryHostPause) { self.service = service; pause = withPausedWriters }
    public func refresh() async {
        do { books = try await service.books(); tombstones = try await service.tombstones() }
        catch { message = error.localizedDescription }
    }
    public func preview(_ target: LocalRecoveryTarget) async {
        do { changePreview = try await service.previewMoveToTrash(target) }
        catch { message = error.localizedDescription }
    }
    public func previewRestore(_ id: UUID) async {
        do { changePreview = try await service.previewRestoreTombstone(id) }
        catch { message = error.localizedDescription }
    }
    public func dismissChange() { changePreview = nil }
    public func confirmChange() async {
        guard !busy, let preview = changePreview else { return }
        busy = true; defer { busy = false }
        do {
            let service = service
            try await pause { permit in
                if preview.tombstoneID == nil { _ = try await service.moveToTrash(preview, permit: permit) }
                else { _ = try await service.restoreTombstone(preview, permit: permit) }
            }
            changePreview = nil; message = preview.tombstoneID == nil ? "已移至本地回收站，原件和关联笔记保留。" : "已恢复；请从重载后的书库打开。"
            await refresh()
        } catch { message = error.localizedDescription }
    }
    public func export(to parent: URL) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let access = parent.startAccessingSecurityScopedResource(); defer { if access { parent.stopAccessingSecurityScopedResource() } }
        do {
            let service = service, destination = parent.appendingPathComponent("PDFnoBackup-" + UUID().uuidString + ".pdfnobackup")
            try await pause { permit in _ = try await service.exportBackup(to: destination, permit: permit) }
            lastExportedParent = parent; lastExportedPackage = destination
            message = "已导出并校验目录备份：\(destination.lastPathComponent)。不包含草稿、缓存、密钥或事务暂存。"
        } catch { message = error.localizedDescription }
    }
    public func inspect(_ url: URL) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { backupPreview = try await service.verifyBackup(at: url); package = url; message = "备份预检通过；确认后仅恢复到新目录。" }
        catch { backupPreview = nil; package = nil; message = error.localizedDescription }
    }
    public func restore(to parent: URL) async {
        guard !busy, let preview = backupPreview, let package else { return }
        busy = true; defer { busy = false }
        let parentAccess = parent.startAccessingSecurityScopedResource(), packageAccess = package.startAccessingSecurityScopedResource()
        defer { if parentAccess { parent.stopAccessingSecurityScopedResource() }; if packageAccess { package.stopAccessingSecurityScopedResource() } }
        do {
            let service = service, destination = parent.appendingPathComponent("PDFnoRecovered-" + UUID().uuidString)
            try await pause { permit in _ = try await service.restoreBackup(at: package, preview: preview, to: destination, permit: permit) }
            message = "已恢复到新目录：\(destination.lastPathComponent)。当前书库未切换；宿主可验证后选择新目录。"
            backupPreview = nil; self.package = nil
        } catch { message = error.localizedDescription }
    }
}
public enum LocalRecoveryWorkspaceMode { case combined, recycle, backup, change }
public struct LocalRecoveryWorkspace: View {
    @ObservedObject private var model: LocalRecoveryManagementModel
    @State private var picker = false
    @State private var action = PickerAction.export
    private enum PickerAction { case export, inspect, restore }
    private let mode: LocalRecoveryWorkspaceMode
    public init(model: LocalRecoveryManagementModel, mode: LocalRecoveryWorkspaceMode = .combined) { self.model = model; self.mode = mode }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(mode == .backup ? "备份与恢复" : mode == .recycle ? "回收站" : mode == .change ? "文件移至回收站" : "本地回收站与备份").font(.title2).bold()
                Text("移至回收站会暂时移出本地书库，保留原件、来源、阅读位置和已保存笔记。回收站没有自动清空或永久删除。")
                if mode == .backup || mode == .combined {
                HStack {
                    Button("导出校验备份") { action = .export; picker = true }.accessibilityIdentifier("local-recovery-export")
                    Button("预检备份目录") { action = .inspect; picker = true }.accessibilityIdentifier("local-recovery-inspect")
                    Button("刷新") { Task { await model.refresh() } }
                }
                if let preview = model.backupPreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(preview.books.count) 本书 · \(preview.savedRecordCount) 项已保存记录 · \(preview.tombstoneCount) 项回收记录")
                        Text("\(preview.inventory.entries.count) 个文件 · \(preview.inventory.totalBytes) 字节").font(.caption)
                        Text(preview.restoreMode)
                        Text("不恢复未保存草稿、缓存、密钥或账户。当前书库不会被替换。")
                        Button("确认恢复到新目录…") { action = .restore; picker = true }.accessibilityIdentifier("local-recovery-restore-package")
                    }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                }
                if mode != .backup, let preview = model.changePreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(preview.tombstoneID == nil ? "确认移至回收站" : "确认恢复回收记录").font(.headline)
                        Text("关联已保存笔记：\(preview.savedRecords)；保留资产：\(preview.retainedAssets)。数据变化或冲突会阻止提交。")
                        HStack {
                            Button("取消") { model.dismissChange() }.accessibilityIdentifier("local-recovery-cancel-change")
                            Button(preview.tombstoneID == nil ? "移至本地回收站" : "恢复到书库") { Task { await model.confirmChange() } }.accessibilityIdentifier("local-recovery-confirm-change")
                        }
                    }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                if mode == .combined {
                Text("书库").font(.headline)
                ForEach(model.books) { book in
                    HStack {
                        Text(book.title); Spacer()
                        Button("移至回收站…") { Task { await model.preview(.book(book)) } }
                            .accessibilityIdentifier("local-recovery-trash-" + book.id.uuidString)
                    }
                }
                }
                if mode == .recycle || mode == .combined {
                Text("回收站（一直保留）").font(.headline)
                if model.tombstones.isEmpty { Text("回收站为空").foregroundStyle(.secondary) }
                ForEach(model.tombstones) { entry in
                    HStack {
                        Text(label(entry.target)); Spacer()
                        if entry.restored { Text("已恢复").foregroundStyle(.secondary) }
                        else { Button("预检恢复…") { Task { await model.previewRestore(entry.id) } }.accessibilityIdentifier("local-recovery-restore-" + entry.id.uuidString) }
                    }
                }
                }
                Text(model.message).font(.callout).accessibilityIdentifier("local-recovery-status")
                if mode == .backup || mode == .combined {
                Text("备份为 PDFno 目录包，不是 ZIP。当前限额：256 MiB、20000 个文件；单个 manifest 5 MiB。")
                    .font(.caption).foregroundStyle(.secondary)
                }
            }.padding()
        }
        .accessibilityIdentifier("local-recovery-form")
        .disabled(model.busy)
        .overlay { if model.busy { ProgressView("正在校验本地数据…") } }
        .task { await model.refresh() }
        #if os(macOS)
        .preference(key: PDFnoWorkspaceBusyKey.self, value: model.busy)
        .background {
            PDFnoDirectoryPicker(isPresented: $picker, initialDirectory: initialDirectory, message: pickerMessage) { url in
                receiveDirectory(url)
            }.frame(width: 0, height: 0)
        }
        #else
        .fileImporter(isPresented: $picker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                receiveDirectory(url)
            }
        }
        #endif
    }
    private var initialDirectory: URL? { action == .inspect ? model.lastExportedPackage : model.lastExportedParent }
    private var pickerMessage: String {
        switch action { case .export: "选择存放备份的文件夹"; case .inspect: "选择要预检的备份文件夹"; case .restore: "选择用于存放新恢复目录的文件夹" }
    }
    private func receiveDirectory(_ url: URL) {
        Task { switch action { case .export: await model.export(to: url); case .inspect: await model.inspect(url); case .restore: await model.restore(to: url) } }
    }
    private func label(_ target: LocalRecoveryTarget) -> String {
        switch target { case .book(let book): book.title; case .note(let manifest, _): "已保存笔记 · " + manifest }
    }
}
