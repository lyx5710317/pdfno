// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum DocumentWritingLanguage: String, Codable, Sendable {
    case simplifiedChinese, traditionalChinese, chinese, japanese, other, unknown
    public var permitsVerticalReflow: Bool { [.simplifiedChinese,.traditionalChinese,.chinese,.japanese].contains(self) }
    /// Whole-document bounded sampling. Digits, punctuation and emoji do not
    /// change the primary language; Hangul is counted separately from Han/kana.
    public static func classify(metadata: String? = nil, text: String) -> Self {
        let tag = metadata?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let legal = tag.map { $0.range(of: "^[a-z]{2,3}(-[a-z0-9]{2,8})*$", options: .regularExpression) != nil } == true
        let root = legal ? tag?.split(separator: "-").first.map(String.init) : nil
        var han = 0, kana = 0, hangul = 0, letters = 0
        let scalars=text.unicodeScalars,step=max(1,(scalars.count+99_999)/100_000)
        for (index,scalar) in scalars.enumerated() where index % step == 0 {
            let x = scalar.value
            if (0x3400...0x4dbf).contains(x) || (0x4e00...0x9fff).contains(x) || (0x20000...0x2fa1f).contains(x) { han += 1; letters += 1 }
            else if (0x3040...0x30ff).contains(x) || (0x31f0...0x31ff).contains(x) || (0xff66...0xff9d).contains(x) { kana += 1; letters += 1 }
            else if (0xac00...0xd7af).contains(x) || (0x1100...0x11ff).contains(x) || (0x3130...0x318f).contains(x) { hangul += 1; letters += 1 }
            else if CharacterSet.letters.contains(scalar) { letters += 1 }
        }
        let supported = han + kana, strongSupported = supported >= 8 && Double(supported) / Double(max(1,letters)) >= 0.6
        let obviousMismatch = letters >= 80 && Double(supported) / Double(letters) < 0.15
        if root == "ja", !obviousMismatch { return .japanese }
        if root == "zh", !obviousMismatch {
            if tag?.contains("hant") == true || ["tw","hk","mo"].contains(tag?.split(separator: "-").last.map(String.init) ?? "") { return .traditionalChinese }
            if tag?.contains("hans") == true || ["cn","sg"].contains(tag?.split(separator: "-").last.map(String.init) ?? "") { return .simplifiedChinese }
            return .chinese
        }
        if strongSupported, hangul < supported / 3 { return kana > 0 ? .japanese : .chinese }
        if legal && root != nil || letters >= 8 { return .other }
        return .unknown
    }
}
