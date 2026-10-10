// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

struct SemanticReflowState {
    let layout: ReadingLayout
    let hasPrevious: Bool
    let hasNext: Bool
    let sourceStart: Int?
    init?(_ value: [String: Any],language: DocumentWritingLanguage) {
        guard let font=value["fontSize"] as? Int,let raw=value["mode"] as? String,let mode=ReadingPageMode(rawValue: raw),let vertical=value["vertical"] as? Bool,
              let previous=value["hasPrevious"] as? Bool,let next=value["hasNext"] as? Bool else { return nil }
        let settings=ReadingLayout(fontSize: font,mode: mode,vertical: vertical)
        guard settings.isValid,settings.permitted(for: language)==settings else { return nil }
        layout=settings;hasPrevious=previous;hasNext=next;sourceStart=value["sourceStart"] as? Int
    }
}
