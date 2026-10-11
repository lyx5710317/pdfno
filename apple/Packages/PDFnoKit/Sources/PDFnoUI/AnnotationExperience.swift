// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Combine
import SwiftUI
import WebKit
import PDFKit
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

@MainActor enum AnnotationReader {
    case pdf(PDFReaderSession), epub(EPUBReaderSession), text(TextFormatReaderSession), ebook(EbookReaderSession), docx(DOCXReaderSession)
    var bookID: UUID? { switch self { case .pdf(let r): r.book?.id; case .epub(let r): r.book?.id; case .text(let r): r.book?.id; case .ebook(let r): r.book?.id; case .docx(let r): r.book?.id } }
    var changes: AnyPublisher<Void,Never> { switch self { case .pdf(let r): r.objectWillChange.eraseToAnyPublisher();case .epub(let r): r.objectWillChange.eraseToAnyPublisher();case .text(let r): r.objectWillChange.eraseToAnyPublisher();case .ebook(let r): r.objectWillChange.eraseToAnyPublisher();case .docx(let r): r.objectWillChange.eraseToAnyPublisher() } }
    var ready: Bool { switch self { case .pdf(let r): r.book != nil; case .epub(let r): r.book != nil && !r.busy; case .text(let r): r.ready; case .ebook(let r): r.ready; case .docx(let r): r.ready } }
    var sessionID: UUID { switch self { case .pdf(let r): r.readerSessionID; case .epub(let r): r.readerSessionID; case .text(let r): r.readerSessionID; case .ebook(let r): r.readerSessionID; case .docx(let r): r.readerSessionID } }
    var scopeID: String { switch self { case .epub(let r): sessionID.uuidString+":"+String(r.documentVersion)+":"+String(r.busy);case .pdf(let r): sessionID.uuidString+":"+String(r.pageIndex);default: sessionID.uuidString } }
    var view: NSView? { switch self { case .pdf(let r): r.view; case .epub(let r): r.webView; case .text(let r): r.webView; case .ebook(let r): r.webView; case .docx(let r): r.webView } }
    func capture() async -> AnnotationAnchor? {
        switch self {
        case .pdf(let r): r.captureSelection(); return r.capturedSelection.map(AnnotationAnchor.pdf)
        case .epub(let r): return await r.captureSelection().map(AnnotationAnchor.epub)
        case .text(let r): return await r.captureSelection().map(AnnotationAnchor.text)
        case .ebook(let r): return await r.captureSelection().map(AnnotationAnchor.ebook)
        case .docx(let r): return await r.captureSelection().map(AnnotationAnchor.docx)
        }
    }
    func accepts(_ anchor: AnnotationAnchor) -> Bool {
        switch (self,anchor) {
        case (.pdf(let r),.pdf(let a)): return r.resolution(of: a) == .exact
        case (.epub(let r),.epub(let a)): return r.book?.accepts(a) == true
        case (.text(let r),.text(let a)): return r.book?.accepts(a) == true && r.document?.resolves(a) == true
        case (.ebook(let r),.ebook(let a)): return r.book?.accepts(a) == true && r.document?.resolves(a) == true
        case (.docx(let r),.docx(let a)): return r.book?.accepts(a) == true && r.document?.resolves(a) == true
        default: return false
        }
    }
    func navigate(_ anchor: AnnotationAnchor) async -> Bool {
        switch (self,anchor) {
        case (.pdf(let r),.pdf(let a)): return r.navigate(to: a) == .exact
        case (.epub(let r),.epub(let a)): return await r.command("navigate",anchor: a.withVertical(r.vertical))
        case (.text(let r),.text(let a)): return await r.navigate(to: a)
        case (.ebook(let r),.ebook(let a)): return await r.navigate(to: a)
        case (.docx(let r),.docx(let a)): return await r.navigate(to: a)
        default: return false
        }
    }
    func selectionRect() async -> NSRect? {
        guard let view else { return nil }
        if case .pdf(let r) = self, let pdf = r.view, let selection = pdf.currentSelection {
            let lines = selection.selectionsByLine()
            for line in lines { for page in line.pages {
                let rect = pdf.convert(line.bounds(for: page),from: page).intersection(pdf.bounds)
                if !rect.isEmpty { return rect }
            } }
            return nil
        }
        guard let web = view as? WKWebView else { return nil }
        let script = """
          const frame=document.querySelector('iframe'),d=frame?.contentDocument??document,s=d.getSelection();
          if(!s?.rangeCount||s.isCollapsed)return null;
          const f=frame?.getBoundingClientRect()??{left:0,top:0};
          for(const r of s.getRangeAt(0).getClientRects()){
            const x=r.left+f.left,y=r.top+f.top;
            if(r.width>0&&r.height>0&&x<innerWidth&&x+r.width>0&&y<innerHeight&&y+r.height>0)return {x:Math.max(0,x),y:Math.max(0,y),width:Math.min(r.width,innerWidth-Math.max(0,x)),height:Math.min(r.height,innerHeight-Math.max(0,y))};
          }return null;
          """
        guard let value = try? await web.callAsyncJavaScript(script,arguments: [:],in: nil,contentWorld: .page) as? [String: Double],
              let x=value["x"],let y=value["y"],let w=value["width"],let h=value["height"], [x,y,w,h].allSatisfy(\.isFinite), w>0,h>0 else { return nil }
        return NSRect(x: x,y: view.isFlipped ? y : view.bounds.height-y-h,width: w,height: h)
    }
    func project(_ annotations: [AnchoredAnnotation]) async {
        let records = annotations.filter { $0.bookID == bookID && accepts($0.anchor) }
        if case .pdf(let r) = self { r.projectAnnotations(records); return }
        if case .epub(let r) = self { await r.projectAnnotations(records); return }
        guard let web = view as? WKWebView else { return }
        let items: [[String: Any]] = records.compactMap { record in
            let data: Data?
            switch record.anchor { case .text(let a): data=try? JSONEncoder().encode(a);case .ebook(let a): data=try? JSONEncoder().encode(a);case .docx(let a): data=try? JSONEncoder().encode(a);default: data=nil }
            guard let data,let anchor=try? JSONSerialization.jsonObject(with: data) else { return nil }
            return ["anchor":anchor,"kind":record.kind.rawValue]
        }
        _ = try? await web.callAsyncJavaScript(AnnotationDOM.semantic,arguments: ["items":items],in: nil,contentWorld: .page)
    }
}

@MainActor final class AnnotationModel: ObservableObject {
    @Published private(set) var records: [AnchoredAnnotation] = []
    @Published var editing: AnchoredAnnotation?
    @Published var error: String?
    @Published var status: String?
    @Published private(set) var saving = false
    let editor: SavedBodyEditingModel<AnnotationBodySnapshot>
    let repository: AnnotationRepository
    let root: URL
    var reader: AnnotationReader?
    private var changes: AnyCancellable?
    private var editingCheckpoint: (key: String,text: String?)?
    private let owner = "annotations:"+UUID().uuidString
    init(root: URL) {
        self.root=root; let repository=AnnotationRepository(root: root);self.repository=repository
        #if DEBUG
        let failureFixture = NoteEditingFilesystemUITestFixture(root: root, manifest: AnnotationRepository.filename)
        #endif
        editor=SavedBodyEditingModel(root: root) { note,text in
            #if DEBUG
            if note.annotation.revision > 0 { try failureFixture?.prepareAttempt() }
            #endif
            return AnnotationBodySnapshot(try await repository.save(expected: note.annotation,text: text))
        }
        changes=editor.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
            Task { @MainActor [weak self] in self?.updateDraftOwner() }
        }
    }
    var bookRecords: [AnchoredAnnotation] { records.filter { $0.bookID == reader?.bookID } }
    var bookDrafts: [SavedBodyDraft<AnnotationBodySnapshot>] { editor.drafts.values.filter { draft in draft.baseline.bookID == reader?.bookID && !bookRecords.contains(where: { $0.id == draft.baseline.noteID }) }.sorted { $0.baseline.key<$1.baseline.key } }
    private func updateDraftOwner() { LibraryMaintenanceOwners.setDraft(root: root,owner: owner,dirty: !editor.drafts.isEmpty || !editor.saving.isEmpty) }
    func bind(_ reader: AnnotationReader) async {
        self.reader=reader;updateDraftOwner();let scope=reader.scopeID
        await reload()
        guard self.reader?.scopeID==scope else { return };await reader.project(records)
    }
    func reload() async { do { records=try await repository.load().notes } catch { self.error=error.localizedDescription } }
    func apply(_ kind: AnnotationKind,anchor: AnnotationAnchor,bookID: UUID,sessionID: UUID) async {
        guard !saving,let reader,reader.bookID==bookID,reader.sessionID==sessionID,reader.accepts(anchor) else { error="原文来源已经变化，请重新选择。";return }
        if kind == .note {
            await reload()
            let existing=records.first { $0.bookID==bookID && $0.origin == .manual && $0.anchor.isSameSource(as: anchor) }
            let unsaved=editor.drafts.values.first { $0.baseline.bookID==bookID && $0.baseline.annotation.anchor.isSameSource(as: anchor) }?.baseline.annotation
            begin(existing ?? unsaved ?? AnchoredAnnotation(bookID: bookID,anchor: anchor,kind: .note));return
        }
        // A changed mark type must not silently invalidate an existing comment draft.
        guard !editor.drafts.values.contains(where: { $0.baseline.bookID==bookID && $0.baseline.annotation.anchor.isSameSource(as: anchor) }) else { error="这段原文有未保存批注，请先保存或取消编辑。";return }
        saving=true;defer { saving=false }
        do { _=try await repository.mark(bookID: bookID,anchor: anchor,kind: kind);await reload();if self.reader?.sessionID==sessionID { await reader.project(records) };status=kind.title+"已保存" } catch { self.error=error.localizedDescription }
    }
    func begin(_ record: AnchoredAnnotation) {
        let snapshot=AnnotationBodySnapshot(record)
        if editing?.id != record.id { editingCheckpoint=(snapshot.key,editor.drafts[snapshot.key]?.text) }
        editor.begin(snapshot);editing=editor.drafts[snapshot.key]?.baseline.annotation ?? record;updateDraftOwner()
    }
    func save(_ baseline: AnchoredAnnotation) async {
        let snapshot=AnnotationBodySnapshot(baseline)
        guard let saved=await editor.save(snapshot) else { return }
        await reload();if let reader,reader.bookID==saved.bookID { await reader.project(records) }
        if editing?.id==baseline.id && editor.drafts[snapshot.key]==nil { editing=nil;editingCheckpoint=nil };updateDraftOwner()
    }
    func cancel(_ baseline: AnchoredAnnotation) {
        let snapshot=AnnotationBodySnapshot(baseline)
        if let checkpoint=editingCheckpoint,checkpoint.key==snapshot.key,let previous=checkpoint.text {
            // A resumed draft belongs to the previous editing session. Cancel
            // only the new changes, using the existing journal's write fence.
            guard !editor.saving.contains(snapshot.key) else { return }
            editor.setText(previous,for: snapshot)
            guard editor.journalError==nil,editor.drafts[snapshot.key]?.text.utf8.elementsEqual(previous.utf8)==true else { return }
            if editing?.id==baseline.id { editing=nil;editingCheckpoint=nil }
        } else {
            editor.cancel(snapshot)
            if editor.drafts[snapshot.key]==nil && editing?.id==baseline.id { editing=nil;editingCheckpoint=nil }
        }
        updateDraftOwner()
    }
    func rebase(_ baseline: AnchoredAnnotation) async { await reload();if let fresh=records.first(where: { $0.id==baseline.id }) { editor.rebase(AnnotationBodySnapshot(fresh));editing=fresh } else { editor.reportReloadFailure(AnnotationBodySnapshot(baseline)) } }
    func navigate(_ record: AnchoredAnnotation) async { guard let reader,reader.bookID==record.bookID,await reader.navigate(record.anchor) else { error="原文无法精确定位；标注和摘录已保留。";return };status="已定位原文" }
}

struct AnnotationList: View {
    @ObservedObject var model: AnnotationModel
    let legacy: () -> Void
    var body: some View {
        VStack(spacing: 0) {
        List {
            if !model.bookDrafts.isEmpty {
                Section("未保存批注") { ForEach(model.bookDrafts,id: \.baseline.key) { draft in
                    Button { model.begin(draft.baseline.annotation) } label: {
                        VStack(alignment: .leading) { Text(draft.baseline.annotation.anchor.quote).lineLimit(2);Text("继续编辑 · 草稿保留").font(.caption).foregroundStyle(.secondary) }
                    }.accessibilityIdentifier("annotation-resume-draft")
                } }
            }
            Section("当前文档标注") {
                if model.bookRecords.isEmpty { Text("选中文字后，在浮动工具条添加高亮、下划线或笔记。").foregroundStyle(.secondary) }
                ForEach(model.bookRecords) { record in
                    VStack(alignment: .leading,spacing: 8) {
                        Button { Task { await model.navigate(record) } } label: {
                            VStack(alignment: .leading,spacing: 8) {
                                Label(record.displayTitle,systemImage: record.aiResult == nil ? record.kind.symbol : "sparkles").font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: record.anchor.quote).lineLimit(5).accessibilityIdentifier("annotation-excerpt")
                            }.frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("annotation-row-"+record.id.uuidString)
                        if let result=record.aiResult { AIResultNoteBox(result: result,identifier: "annotation-ai-result") }
                        if model.editor.drafts[AnnotationBodySnapshot(record).key] != nil { Text("未保存批注 · 右键继续编辑").font(.caption).foregroundStyle(.orange) }
                        if !record.userText.isEmpty {
                            Text(verbatim: record.userText).foregroundStyle(.secondary).accessibilityIdentifier("annotation-comment")
                                .contentShape(Rectangle()).onTapGesture { Task { await model.navigate(record) } }
                        }
                    }.padding(.vertical,6).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                        .accessibilityElement(children: .contain)
                        .contextMenu { Button("编辑批注") { model.begin(record) }.accessibilityIdentifier("annotation-context-edit") }
                        .onTapGesture(count: 2) { model.begin(record) }
                }
            }
            if let status=model.status { Text(status).font(.caption).accessibilityIdentifier("annotation-status") }
        }.accessibilityIdentifier("annotation-list")
            Divider()
            Button("旧笔记与学习记录",action: legacy)
                .frame(maxWidth: .infinity,alignment: .leading).padding(12)
                .accessibilityIdentifier("annotation-legacy-records")
        }
    }
}

/// Keep the existing native editor/delegate; expose its real edit availability
/// explicitly because a plain NSTextView reports AXEnabled=false on this SDK.
struct AnnotationCommentInput: NSViewRepresentable {
    @Binding var text: String
    let identifier: String
    let enabled: Bool
    var borderless = false
    func makeCoordinator() -> NativeNoteBodyInput.Coordinator { NativeNoteBodyInput.Coordinator(text: $text) }
    static func makeEditor(coordinator: NativeNoteBodyInput.Coordinator,identifier: String,enabled: Bool,borderless: Bool = false) -> NSScrollView {
        let scroll=NativeNoteBodyInput.makeEditor(coordinator: coordinator,identifier: identifier,enabled: enabled)
        if borderless {
            scroll.borderType = .noBorder;scroll.drawsBackground=false;scroll.contentView.drawsBackground=false
            (scroll.documentView as? NSTextView)?.drawsBackground=false
        }
        (scroll.documentView as? NSTextView)?.setAccessibilityEnabled(enabled)
        return scroll
    }
    func makeNSView(context: Context) -> NSScrollView { Self.makeEditor(coordinator: context.coordinator,identifier: identifier,enabled: enabled,borderless: borderless) }
    func updateNSView(_ scroll: NSScrollView,context: Context) {
        guard let view=scroll.documentView as? NSTextView else { return }
        context.coordinator.update(view,text: $text,enabled: enabled)
        // The delegate enforces this same flag immediately while native layout settles.
        view.setAccessibilityEnabled(enabled)
    }
    static func dismantleNSView(_ scroll: NSScrollView,coordinator: NativeNoteBodyInput.Coordinator) {
        guard let view=scroll.documentView as? NSTextView else { return };coordinator.unmount(view)
    }
}

struct AnnotationEditor: View {
    @ObservedObject var model: AnnotationModel
    let baseline: AnchoredAnnotation
    private var snapshot: AnnotationBodySnapshot { AnnotationBodySnapshot(baseline) }
    var body: some View {
        VStack(alignment: .leading,spacing: 14) {
            if let result=baseline.aiResult { AIResultNoteBox(result: result,identifier: "annotation-editor-ai-result") }
            AnnotationCommentInput(text: Binding(get: { model.editor.drafts[snapshot.key]?.text ?? baseline.userText },set: { model.editor.setText($0,for: snapshot) }),identifier: "annotation-comment-input",enabled: !model.editor.saving.contains(snapshot.key),borderless: true).frame(minHeight: 200,idealHeight: 240).id(snapshot.key)
            if let feedback=model.editor.feedback[snapshot.key],feedback != "正文未保存" { Text(feedback).font(.caption).accessibilityIdentifier("annotation-editor-status") }
            if let error=model.editor.journalError { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer(minLength: 0)
                Button("取消") { model.cancel(baseline) }.disabled(model.editor.saving.contains(snapshot.key)).accessibilityIdentifier("annotation-editor-cancel").keyboardShortcut(.cancelAction)
                Button("完成") { Task { await model.save(baseline) } }.buttonStyle(.borderedProminent)
                    .disabled(model.editor.saving.contains(snapshot.key) || !(model.editor.drafts[snapshot.key]?.baseline.accepts(model.editor.drafts[snapshot.key]?.text ?? "") ?? false)).accessibilityIdentifier("annotation-editor-save")
            }
            if model.editor.conflicts.contains(snapshot.key) { Button("重新载入基线，保留草稿") { Task { await model.rebase(baseline) } } }
        }.padding(16).frame(minWidth: 300,idealWidth: 360,maxWidth: 480)
            .background(PDFnoDesign.Palette.surface)
            .interactiveDismissDisabled(model.editor.saving.contains(snapshot.key))
    }
}

struct AnnotationExperience: ViewModifier {
    @ObservedObject var model: AnnotationModel
    let reader: AnnotationReader
    var aiLibrary: LibraryModel? = nil
    @StateObject private var gestures=AnnotationGestureController()
    init(model: AnnotationModel,reader: AnnotationReader,aiLibrary: LibraryModel? = nil) { self.model=model;self.reader=reader;self.aiLibrary=aiLibrary }
    func body(content: Content) -> some View {
        content
            .onAppear { gestures.attach(model,reader: reader,aiLibrary: aiLibrary) }
            .onChange(of: reader.sessionID) { _,_ in gestures.attach(model,reader: reader,aiLibrary: aiLibrary) }
            .onDisappear { gestures.stop() }
            .sheet(item: $model.editing) { AnnotationEditor(model: model,baseline: $0) }
            .background {
                if let aiLibrary { SelectionAISheetPresenter(library: aiLibrary) }
            }
            .alert("标注未完成",isPresented: Binding(get: { model.error != nil },set: { if !$0 { model.error=nil } })) { Button("知道了") { model.error=nil } } message: { Text(model.error ?? "") }
    }
}
extension View { func annotationExperience(_ model: AnnotationModel,reader: AnnotationReader,aiLibrary: LibraryModel? = nil) -> some View { modifier(AnnotationExperience(model: model,reader: reader,aiLibrary: aiLibrary)) } }

/// Event observation belongs to SwiftUI state, independent of a zero-sized view.
@MainActor private final class AnnotationGestureController: ObservableObject {
    private weak var model: AnnotationModel?
    private weak var aiLibrary: LibraryModel?
    private var monitor: Any?
    private var resizeObserver: AnyCancellable?
    private var readerObserver: AnyCancellable?
    private var observedSession: UUID?
    private var projection: Task<Void,Never>?
    private var projectionScope: String?
    private var scope: String?
    private var pending: Task<Void,Never>?
    private let popover=NSPopover()
    init() { popover.behavior = .transient;popover.contentSize=NSSize(width: 270,height: 48) }
    private func trace(_ stage: String) {
        #if DEBUG
        let env=ProcessInfo.processInfo.environment
        guard env["PDFNO_A_QA_SCOPE"]=="a-regression",Bundle.main.bundleIdentifier?.hasPrefix("org.pdfno.integration.professionala20261007.qa")==true,
              let raw=env["PDFNO_UI_TEST_SESSION"],let id=UUID(uuidString: raw) else { return }
        let file=URL(fileURLWithPath: "/tmp/PDFno-AnnotationGestureTrace-"+id.uuidString+".log")
        let bytes=Data((stage+"\n").utf8)
        if FileManager.default.fileExists(atPath: file.path),let handle=try? FileHandle(forWritingTo: file) { defer { try? handle.close() };if let size=try? handle.seekToEnd(),size<16_384 { try? handle.write(contentsOf: bytes) } }
        else { try? bytes.write(to: file,options: .atomic) }
        #endif
    }
    func attach(_ model: AnnotationModel,reader: AnnotationReader,aiLibrary: LibraryModel? = nil) {
        // Bind synchronously before the first mouse event. Reader readiness arrives
        // through its publisher even when a parent cancels a SwiftUI task.
        self.model=model;model.reader=reader;self.aiLibrary=aiLibrary
        if observedSession != reader.sessionID || readerObserver==nil {
            observedSession=reader.sessionID;readerObserver?.cancel()
            readerObserver=reader.changes.receive(on: RunLoop.main).sink { [weak self] in self?.refreshReader() }
        }
        refreshReader()
        guard monitor==nil else { return }
        trace("attached-reader="+String(model.reader != nil))
        resizeObserver=NotificationCenter.default.publisher(for: NSWindow.didResizeNotification).receive(on: RunLoop.main).sink { [weak self] notification in
            guard let self,notification.object as? NSWindow === self.model?.reader?.view?.window else { return }
            self.pending?.cancel();self.popover.close()
        }
        monitor=NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown,.leftMouseUp,.scrollWheel,.keyDown]) { [weak self] event in self?.observe(event);return event }
    }
    private func refreshReader() {
        guard let model,let reader=model.reader else { return };let next=reader.scopeID
        if scope != next { trace("scope-reset");pending?.cancel();popover.close();scope=next }
        guard reader.ready else { projection?.cancel();projectionScope=nil;return }
        guard projectionScope != next else { return };projectionScope=next;projection?.cancel()
        projection=Task { [weak model] in
            guard !Task.isCancelled,let model,model.reader?.scopeID==next else { return }
            await model.bind(reader)
        }
    }
    func stop() { trace("stopped");pending?.cancel();projection?.cancel();projectionScope=nil;readerObserver?.cancel();readerObserver=nil;observedSession=nil;popover.close();popover.contentViewController=nil;resizeObserver?.cancel();resizeObserver=nil;if let monitor { NSEvent.removeMonitor(monitor) };monitor=nil }
    private func observe(_ event: NSEvent) {
        if event.type == .leftMouseUp { trace("mouse-up-reader="+String(model?.reader != nil)) }
        guard let model,let reader=model.reader,let view=reader.view,let window=view.window,event.window===window,window.isKeyWindow else { return }
        if event.type != .leftMouseUp { pending?.cancel();popover.close();return }
        guard let content=window.contentView else { return }
        let point=content.superview?.convert(event.locationInWindow,from: nil) ?? event.locationInWindow
        guard let hit=content.hitTest(point),hit===view || hit.isDescendant(of: view) else { trace("reader-surface-miss");return }
        trace("reader-mouse-up")
        let session=reader.sessionID;pending?.cancel()
        pending=Task { [weak self,weak model,weak view] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled,let self,let model,let view,model.reader?.sessionID==session,let bookID=reader.bookID else { return }
            guard let anchor=await reader.capture(),reader.accepts(anchor) else { self.trace("capture-empty");return }
            guard let rect=await reader.selectionRect() else { self.trace("rect-empty");return }
            guard !Task.isCancelled,model.reader?.sessionID==session,view.window?.isKeyWindow==true else { self.trace("scope-cancelled");return }
            self.popover.contentViewController=NSHostingController(rootView: HStack(spacing: 12) {
                ForEach(AnnotationKind.allCases,id: \.self) { kind in
                    Button { self.popover.close();Task { await model.apply(kind,anchor: anchor,bookID: bookID,sessionID: session) } } label: { Label(kind.title,systemImage: kind.symbol) }
                        .buttonStyle(.borderless).accessibilityIdentifier("selection-annotation-"+kind.rawValue)
                }
                if let library=self.aiLibrary {
                    NativeSelectionAIMenu(tasks: ReadingConversationTask.allCases.filter { library.learning.tools.isEnabled($0) }) { [weak self, weak library] command in
                        guard let self, let library else { return }
                        self.popover.close()
                        switch command {
                        case .conversation(let task): library.openConversationAI(task, anchor: anchor, sessionID: session)
                        case .japaneseReview: library.openJapaneseReview(anchor: anchor, sessionID: session)
                        case .englishReview: library.openEnglishReview(anchor: anchor, sessionID: session)
                        }
                    }.frame(width: 51, height: 24)
                }
            }.font(.system(size: 13)).padding(12).frame(width: self.aiLibrary == nil ? 270 : 325,height: 48))
            self.popover.contentSize=NSSize(width: self.aiLibrary == nil ? 270 : 325,height: 48)
            self.popover.show(relativeTo: rect,of: view,preferredEdge: view.isFlipped ? .minY : .maxY)
            self.trace("shown="+String(self.popover.isShown))
        }
    }
}
#endif
