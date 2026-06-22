//
//  HistoryUseCases.swift
//  clip-command — Domain 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation

/// 新しいクリップボード内容を取り込む。重複排除と件数上限制御を担う中心ロジック。
struct IngestClipboardUseCase {
    let clipboard: ClipboardRepository
    let images: ImageRepository

    func execute(text: String?, imageData: Data?, limit: Int) {
        if let text, !text.isEmpty {
            ingestText(text)
        } else if let imageData {
            ingestImage(imageData)
        } else {
            return
        }
        clipboard.trim(to: max(1, limit))
    }

    private func ingestText(_ text: String) {
        // 同一テキストが既にあれば重複を作らず先頭へ移動する。
        if let existing = clipboard.fetchAll().first(where: { $0.kind == .text && $0.text == text }) {
            clipboard.touch(id: existing.id)
        } else {
            clipboard.addText(text)
        }
    }

    private func ingestImage(_ data: Data) {
        // 直近の画像と同一なら取り込まない。
        if let top = clipboard.fetchAll().first,
           top.kind == .image,
           images.loadData(ref: top.imageRef) == data {
            return
        }
        clipboard.addImage(data: data)
    }
}

/// クエリで履歴を絞り込む。空クエリなら全件。
struct SearchHistoryUseCase {
    let clipboard: ClipboardRepository

    func execute(query: String) -> [ClipEntry] {
        let all = clipboard.fetchAll()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { entry in
            switch entry.kind {
            case .text: return (entry.text ?? "").localizedCaseInsensitiveContains(q)
            case .image: return "画像".localizedCaseInsensitiveContains(q)
            }
        }
    }
}

struct TogglePinUseCase {
    let clipboard: ClipboardRepository
    func execute(entry: ClipEntry) {
        clipboard.setPinned(id: entry.id, pinned: !entry.isPinned)
    }
}

struct DeleteClipUseCase {
    let clipboard: ClipboardRepository
    func execute(id: UUID) { clipboard.delete(id: id) }
}

struct ClearHistoryUseCase {
    let clipboard: ClipboardRepository
    func execute() { clipboard.deleteAll() }
}
