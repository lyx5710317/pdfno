// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

/// A dedicated reader action row keeps the manual Japanese flow reachable above the
/// native canvas, including after a large review sheet changes window geometry.
struct JapaneseLearningEntry: View {
    let identifier: String
    var disabled = false
    let action: () -> Void
    var body: some View {
        HStack {
            Button("日语选文学习", action: action)
                .accessibilityIdentifier(identifier).disabled(disabled)
            Spacer(minLength: 0)
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }
}
#endif
