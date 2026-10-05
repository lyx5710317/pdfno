// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct EnglishLearningSheet: View {
    @ObservedObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: PDFnoDesign.Space.regular) {
            HStack {
                Text("英语选文学习").font(PDFnoDesign.TypeStyle.title)
                Spacer()
                Button("重新固定当前选文") { library.prepareEnglishLearning() }.accessibilityIdentifier("english-learning-recapture")
                Button("完成") { library.englishLearning.cancel(); dismiss() }.accessibilityIdentifier("english-learning-close")
            }
            EnglishLearningWorkspace(model: library.englishLearning, returnToSource: { source in Task { if await library.returnToEnglishSource(source) { dismiss() } } })
            if library.learning.offlineTransport { Text("离线 transport 替身 · 不发送真实 API").font(.caption).accessibilityIdentifier("english-offline-fixture") }
        }.padding(PDFnoDesign.Space.regular)
            .frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: PDFnoDesign.Metric.sheetIdeal, minHeight: 600)
            .onDisappear { library.englishLearning.cancel() }
    }
}
#endif
