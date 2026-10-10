// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import PDFKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct AnnotationReaderTests {
    private func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/"+name))
    }
    private func window(_ view: NSView) -> NSWindow {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let window=NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed=false;window.contentView=view;view.frame=NSRect(x: 0,y: 0,width: 720,height: 520);return window
    }
    private func ready(_ reader: AnnotationReader) async throws {
        let deadline=Date().addingTimeInterval(22)
        while !reader.ready && Date()<deadline { reader.view?.layoutSubtreeIfNeeded();try await Task.sleep(for: .milliseconds(50)) }
        try #require(reader.ready)
    }
    private func selected(_ reader: AnnotationReader,epub: Bool=false) async throws -> AnnotationAnchor {
        let web=try #require(reader.view as? WKWebView)
        let script=epub ? "const d=document.querySelector('iframe').contentDocument,b=d.querySelector('[data-pdfno-spine=\"0\"] p');const w=d.createTreeWalker(b,NodeFilter.SHOW_TEXT),n=w.nextNode(),r=d.createRange();r.setStart(n,0);r.setEnd(n,Math.min(n.length,8));const s=d.getSelection();s.removeAllRanges();s.addRange(r);return true;" : "const b=document.querySelector('[data-block]'),w=document.createTreeWalker(b,NodeFilter.SHOW_TEXT),n=w.nextNode(),r=document.createRange();r.setStart(n,0);r.setEnd(n,Math.min(n.length,8));const s=getSelection();s.removeAllRanges();s.addRange(r);return true;"
        _=try await web.callAsyncJavaScript(script,arguments: [:],in: nil,contentWorld: .page)
        return try #require(await reader.capture())
    }
    private func semanticProjection(_ reader: AnnotationReader) async throws {
        try await ready(reader)
        let web=try #require(reader.view as? WKWebView),source=try await selected(reader)
        let original=try await web.callAsyncJavaScript("return canonical;",arguments: [:],in: nil,contentWorld: .page) as? String
        var mark=AnchoredAnnotation(bookID: try #require(reader.bookID),anchor: source,kind: .highlight,revision: 1)
        await reader.project([mark])
        #expect(try await web.callAsyncJavaScript("return CSS.highlights.get('pdfnoAnnotations').size;",arguments: [:],in: nil,contentWorld: .page) as? Int == 1)
        mark.kind = .underline;await reader.project([mark])
        #expect(try await web.callAsyncJavaScript("return document.querySelectorAll('[data-pdfno-annotation-overlay]').length>0;",arguments: [:],in: nil,contentWorld: .page) as? Bool == true)
        #expect(await reader.navigate(source))
        #expect((try #require(await reader.capture())).isSameSource(as: source))
        mark.kind = .note;mark.userText="Original annotation comment";await reader.project([mark])
        #expect(try await web.callAsyncJavaScript("return canonical;",arguments: [:],in: nil,contentWorld: .page) as? String == original)
        #expect(try await web.callAsyncJavaScript("return document.querySelectorAll('[data-pdfno-annotation-overlay]').length;",arguments: [:],in: nil,contentWorld: .page) as? Int == 0)
        #expect(reader.view?.window?.isVisible==false && reader.view?.window?.isKeyWindow==false)
    }
    @Test func pdfCreatesUnderlineAndHighlightWithoutChangingOriginalBytes() async throws {
        let data=try originalSample(),book=BookRecord(title: "Original",fileSHA256: LibraryRepository.digest(data),originalFilename: "Original.pdf",pageCount: 2)
        let session=PDFReaderSession();try session.open(data: data,book: book)
        let view=PDFView(),window=window(view);session.attach(view);defer { session.close();window.close() }
        let selection=try #require(session.document?.findString("window",withOptions: []).first);view.setCurrentSelection(selection,animate: false)
        let reader=AnnotationReader.pdf(session),source=try #require(await reader.capture())
        var mark=AnchoredAnnotation(bookID: book.id,anchor: source,kind: .underline,revision: 1)
        await reader.project([mark]);#expect(session.document?.page(at: 0)?.annotations.contains(where: { $0.type=="Underline" })==true)
        mark.kind = .highlight;await reader.project([mark]);#expect(session.document?.page(at: 0)?.annotations.contains(where: { $0.type=="Highlight" })==true)
        #expect(session.document?.page(at: 0)?.annotations.contains(where: { $0.type=="Underline" })==false)
        #expect(await reader.navigate(source));#expect(session.resolution(of: { if case .pdf(let a)=source { return a };fatalError() }()) == .exact)
        #expect(try originalSample()==data && !window.isVisible)
    }
    @Test func threeActionsUpdateOneRowAndStaleReleasedSelectionCannotWrite() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Original-Annotation-Reader-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let data=try originalSample(),library=LibraryRepository(root: root),book=try await library.importPDF(data,filename: "Original.pdf",pageCount: 2)
        let session=PDFReaderSession();try session.open(data: data,book: book)
        let view=PDFView(),window=window(view);session.attach(view);defer { session.close();window.close() }
        view.setCurrentSelection(try #require(session.document?.findString("window",withOptions: []).first),animate: false)
        let reader=AnnotationReader.pdf(session),model=AnnotationModel(root: root),source=try #require(await reader.capture()),sessionID=reader.sessionID
        await model.bind(reader)
        await model.apply(.highlight,anchor: source,bookID: book.id,sessionID: sessionID)
        let initial=try #require(model.bookRecords.first)
        await model.apply(.underline,anchor: source,bookID: book.id,sessionID: sessionID)
        await model.apply(.note,anchor: source,bookID: book.id,sessionID: sessionID)
        let baseline=try #require(model.editing)
        #expect(baseline.id==initial.id && baseline.kind == .underline && model.bookRecords.count==1)
        #expect(model.bookDrafts.isEmpty) // A saved mark with a draft still has one list row.
        model.editor.setText("Original comment",for: AnnotationBodySnapshot(baseline));await model.save(baseline)
        #expect(model.bookRecords.count==1 && model.bookRecords.first?.id==initial.id && model.bookRecords.first?.userText=="Original comment")
        let edited=try #require(model.bookRecords.first);model.begin(edited)
        model.editor.setText("Discarded comment",for: AnnotationBodySnapshot(edited));model.cancel(edited)
        #expect(model.bookRecords.first?.userText=="Original comment")
        await model.navigate(edited);#expect(session.capturedSelection?.quote==source.quote)
        session.close();await model.apply(.highlight,anchor: source,bookID: book.id,sessionID: sessionID)
        let persisted=try await model.repository.load();#expect(model.error != nil && persisted.notes.count==1)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    @Test(arguments: [TextFileFormat.txt,.markdown,.html,.xhtml,.mhtml,.xml])
    func allSelectableTextFormatsKeepCanonicalTextAndExactSource(_ format: TextFileFormat) async throws {
        let text="原创选文 日本語 か\u{3099} 🌸 English 2026",body: String
        switch format {
        case .txt: body=text
        case .markdown: body="# "+text+"\n\nOriginal second paragraph."
        case .html: body="<html><body><p>"+text+"</p></body></html>"
        case .xhtml: body="<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>"+text+"</p></body></html>"
        case .xml: body="<document><para>"+text+"</para></document>"
        case .mhtml: body="MIME-Version: 1.0\r\nContent-Type: multipart/related; boundary=original\r\n\r\n--original\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n<html><body><p>"+text+"</p></body></html>\r\n--original--\r\n"
        }
        let data=Data(body.utf8),book=TextFormatBook(fileSHA256: LibraryRepository.digest(data),title: "Original",originalFilename: "Original."+format.rawValue,format: format)
        let session=TextFormatReaderSession();try await session.open(data: data,book: book,notes: [])
        let window=window(try #require(session.webView));defer { session.close();window.close() }
        try await semanticProjection(.text(session))
    }
    @Test(arguments: [EbookFormat.mobi,.azw,.azw3,.fb2])
    func ebookFormatsProjectThreeKindsWithoutDuplicatingSource(_ format: EbookFormat) async throws {
        let data=try fixture("Ebooks/study-sample."+format.rawValue),kind: EbookContentKind=format == .fb2 ? .fb2 : (format == .azw3 ? .kf8 : .mobi6)
        let book=EbookBook(fileSHA256: LibraryRepository.digest(data),format: format,contentKind: kind,title: "Original",originalFilename: "Original."+format.rawValue)
        let session=EbookReaderSession();try await session.open(data: data,book: book,notes: [])
        let window=window(try #require(session.webView));defer { session.close();window.close() }
        try await semanticProjection(.ebook(session))
    }
    @Test func semanticDOCXProjectsAndNavigatesTheSameCheckedSpan() async throws {
        let data=try fixture("DOCX/study-sample.docx"),book=DOCXBook(fileSHA256: LibraryRepository.digest(data),title: "Original",originalFilename: "Original.docx")
        let session=DOCXReaderSession();try await session.open(data: data,book: book,notes: [])
        let window=window(try #require(session.webView));defer { session.close();window.close() }
        try await semanticProjection(.docx(session))
    }
    @Test func japaneseEPUBPreservesSelectionAcrossProjectionOrientationAndRestart() async throws {
        let data=try fixture("Annotations/original-japanese-annotations.epub")
        var book=EPUBBook(fileSHA256: LibraryRepository.digest(data),title: "自作資料",originalFilename: "Original.epub")
        let session=EPUBReaderSession();try await session.open(data: data,book: book,notes: [])
        let window=window(try #require(session.webView));defer { session.close();window.close() }
        let reader=AnnotationReader.epub(session);try await ready(reader)
        #expect(session.writingLanguage == .japanese && session.writingLanguage.permitsVerticalReflow)
        let source=try await selected(reader,epub: true),mark=AnchoredAnnotation(bookID: book.id,anchor: source,kind: .underline,revision: 1)
        await reader.project([mark]);#expect((try #require(await reader.capture())).isSameSource(as: source))
        let web=try #require(session.webView)
        #expect(try await web.callAsyncJavaScript("return document.querySelector('iframe').contentDocument.querySelectorAll('[data-pdfno-annotation-overlay]').length>0;",arguments: [:],in: nil,contentWorld: .page) as? Bool == true)
        #expect(await session.command("vertical"));#expect(session.vertical)
        #expect((try #require(await reader.capture())).isSameSource(as: source))
        await reader.project([mark]);#expect(await reader.navigate(source));#expect(session.vertical)
        book.progress=session.progress
        session.close();try await session.open(data: data,book: book,notes: []);window.contentView=try #require(session.webView)
        try await ready(.epub(session));#expect(session.vertical && session.writingLanguage == .japanese)
        await AnnotationReader.epub(session).project([mark]);#expect(await AnnotationReader.epub(session).navigate(source))
        #expect(session.selection?.quote==source.quote && !window.isVisible)
    }
    @Test func englishEPUBHidesVerticalAndSafelyOpensLegacyVerticalProgress() async throws {
        let data=try fixture("study-sample.epub")
        var book=EPUBBook(fileSHA256: LibraryRepository.digest(data),title: "Original English",originalFilename: "Original.epub")
        let session=EPUBReaderSession();try await session.open(data: data,book: book,notes: [])
        let window=window(try #require(session.webView));defer { session.close();window.close() }
        try await ready(.epub(session));#expect(!session.writingLanguage.permitsVerticalReflow)
        #expect(!(await session.command("vertical")) && !session.vertical)
        let old=try #require(session.progress).withVertical(true);book.progress=old
        session.close();try await session.open(data: data,book: book,notes: []);window.contentView=try #require(session.webView)
        try await ready(.epub(session));#expect(!session.vertical && book.progress==old)
        #expect(await session.command("navigate",anchor: old));#expect(!session.vertical && session.selection?.vertical==false)
    }
}
#endif
