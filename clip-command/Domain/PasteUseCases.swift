//
//  PasteUseCases.swift
//  clip-command — Domain 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation

/// 履歴項目を前面アプリへ貼り付ける。
struct PasteEntryUseCase {
    let images: ImageRepository
    let paste: PasteService

    func execute(entry: ClipEntry, autoPaste: Bool) {
        switch entry.kind {
        case .text:
            if let text = entry.text { paste.pasteText(text, autoPaste: autoPaste) }
        case .image:
            if let data = images.loadData(ref: entry.imageRef) {
                paste.pasteImage(data: data, autoPaste: autoPaste)
            }
        }
    }
}

/// 任意テキスト（スニペット本文など）を前面アプリへ貼り付ける。
struct PasteTextUseCase {
    let paste: PasteService
    func execute(_ text: String, autoPaste: Bool) {
        paste.pasteText(text, autoPaste: autoPaste)
    }
}
