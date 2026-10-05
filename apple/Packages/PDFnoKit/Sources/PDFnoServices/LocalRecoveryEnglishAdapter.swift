// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

extension LocalRecoveryAdditionalAdapter {
    /// One audited saved-record schema, never a dynamic plugin filename loader.
    public static func englishLearning() throws -> Self {
        try Self(filename: EnglishLearningRepository.filename,
                 validate: { _ = try EnglishLearningRepository.decode($0) },
                 associations: { data in
                     try EnglishLearningRepository.decode(data).notes.map { note in
                         let source = note.review.source
                         let format: String
                         switch source.anchor { case .pdf: format = "pdf"; case .epub: format = "epub"; default: throw LocalRecoveryError.integrity }
                         return LocalRecoveryAssociation(recordID: note.id, bookID: source.bookID,
                             editionID: source.anchor.editionID, fileSHA256: source.anchor.fileSHA256, format: format)
                     }
                 })
    }
}
