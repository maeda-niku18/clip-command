//
//  PersistenceModels.swift
//  clip-command — Data 層 / 永続化
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  SwiftData の永続化モデル。Domain エンティティとは別物として保持し、相互変換で橋渡しする。
//

import Foundation
import SwiftData

@Model
final class ClipItemModel {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var kindRaw: String = ClipKind.text.rawValue
    var text: String?
    var imageFileName: String?
    var pinned: Bool = false

    init(kind: ClipKind, text: String? = nil, imageFileName: String? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.kindRaw = kind.rawValue
        self.text = text
        self.imageFileName = imageFileName
        self.pinned = false
    }

    func toEntity() -> ClipEntry {
        ClipEntry(
            id: id,
            createdAt: createdAt,
            kind: ClipKind(rawValue: kindRaw) ?? .text,
            text: text,
            imageRef: imageFileName,
            isPinned: pinned
        )
    }
}

@Model
final class SnippetFolderModel {
    var id: UUID = UUID()
    var name: String = ""
    var order: Int = 0
    @Relationship(deleteRule: .cascade, inverse: \SnippetModel.folder)
    var snippets: [SnippetModel] = []

    init(name: String, order: Int) {
        self.id = UUID()
        self.name = name
        self.order = order
    }

    func toEntity() -> SnippetFolderEntity {
        SnippetFolderEntity(
            id: id,
            name: name,
            order: order,
            snippets: snippets.sorted { $0.order < $1.order }.map { $0.toEntity() }
        )
    }
}

@Model
final class SnippetModel {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var order: Int = 0
    var folder: SnippetFolderModel?

    init(title: String, content: String, order: Int, folder: SnippetFolderModel?) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.order = order
        self.folder = folder
    }

    func toEntity() -> SnippetItem {
        SnippetItem(id: id, title: title, content: content, order: order, folderID: folder?.id)
    }
}
