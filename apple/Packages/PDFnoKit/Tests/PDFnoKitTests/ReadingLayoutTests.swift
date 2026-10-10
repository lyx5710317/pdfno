// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoReaders

@Suite struct ReadingLayoutTests {
    @Test func validatedFormatsSeparateWordPDFComicsAndFixedLayout() {
        #expect(ReadingFormatCapability.reflowEPUB.allowsAa)
        for format in EbookFormat.allCases { #expect(ReadingFormatCapability.ebook(format).allowsAa) }
        for format in TextFileFormat.allCases { #expect(ReadingFormatCapability.flowingText(format).allowsAa) }
        for value in [ReadingFormatCapability.pdf,.word,.comic,.fixedEPUB,.unavailable] { #expect(!value.allowsAa) }
        #expect(ReadingFormatCapability.comic.allowsBottomPaging)
        #expect(!ReadingFormatCapability.pdf.allowsBottomPaging && !ReadingFormatCapability.word.allowsBottomPaging)
    }
    @Test func defaultScrollingAndLanguageRestrictionDoNotFollowFilename() {
        #expect(ReadingLayout().mode == .scroll && ReadingLayout().fontSize==20)
        let vertical=ReadingLayout(fontSize: 24,mode: .double,vertical: true)
        for language in [DocumentWritingLanguage.simplifiedChinese,.traditionalChinese,.chinese,.japanese] { #expect(vertical.permitted(for: language)==vertical) }
        for text in ["An English document has ordinary Latin prose and punctuation.","한국어 문서 한국어 문서 한국어 문서","Texte français avec accents et mots ordinaires."] {
            let language=DocumentWritingLanguage.classify(text: text)
            #expect(!language.permitsVerticalReflow && !vertical.permitted(for: language).vertical)
        }
        #expect(!ReadingLayout(fontSize: 11).isValid && !ReadingLayout(fontSize: 37).isValid)
    }
    @Test func wordSemanticHTMLDoesNotOptIntoEbookBridge() {
        let id=UUID(),word=DOCXDocument(blocks: [DOCXBlock(id: 0,runs: [DOCXRun("Word original")],start: 0)])
        let html=DOCXHTML.render(word,sessionID: id)
        #expect(!html.contains("configureReflow") && !html.contains("PDFnoReflow"))
        let text=TextFormatDocument(blocks: [TextFormatBlock(id: 0,runs: [TextFormatRun("Plain source")],start: 0)])
        #expect(TextFormatHTML.render(text,sessionID: id).contains("window.pdfnoText"))
        #expect(TextFormatHTML.render(text,sessionID: id).contains("configureReflow"))
    }
}
