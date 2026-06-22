//
//  SwiftDataSnippetRepository.swift
//  clip-command — Data 層 / 永続化
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import SwiftData

/// SnippetRepository の SwiftData 実装。フォルダが空なら既定フォルダを用意する。
@MainActor
final class SwiftDataSnippetRepository: SnippetRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        seedIfEmpty()
    }

    func fetchFolders() -> [SnippetFolderEntity] {
        fetchFolderModels().map { $0.toEntity() }
    }

    @discardableResult
    func addFolder(name: String) -> SnippetFolderEntity {
        let folder = SnippetFolderModel(name: name, order: fetchFolderModels().count)
        context.insert(folder)
        save()
        return folder.toEntity()
    }

    func renameFolder(id: UUID, name: String) {
        guard let folder = folderModel(for: id) else { return }
        folder.name = name
        save()
    }

    func deleteFolder(id: UUID) {
        guard let folder = folderModel(for: id) else { return }
        context.delete(folder)
        save()
    }

    @discardableResult
    func addSnippet(title: String, content: String, folderID: UUID?) -> SnippetItem? {
        let folder = folderID.flatMap { folderModel(for: $0) } ?? fetchFolderModels().first ?? ensureFolder()
        guard let folder else { return nil }
        let snippet = SnippetModel(
            title: title,
            content: content,
            order: folder.snippets.count,
            folder: folder
        )
        context.insert(snippet)
        save()
        return snippet.toEntity()
    }

    func updateSnippet(id: UUID, title: String, content: String) {
        guard let snippet = snippetModel(for: id) else { return }
        snippet.title = title
        snippet.content = content
        save()
    }

    func deleteSnippet(id: UUID) {
        guard let snippet = snippetModel(for: id) else { return }
        context.delete(snippet)
        save()
    }

    // MARK: - 補助

    private func fetchFolderModels() -> [SnippetFolderModel] {
        let descriptor = FetchDescriptor<SnippetFolderModel>(
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func folderModel(for id: UUID) -> SnippetFolderModel? {
        let descriptor = FetchDescriptor<SnippetFolderModel>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private func snippetModel(for id: UUID) -> SnippetModel? {
        let descriptor = FetchDescriptor<SnippetModel>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    @discardableResult
    private func ensureFolder() -> SnippetFolderModel? {
        let folder = SnippetFolderModel(name: "デフォルト", order: 0)
        context.insert(folder)
        save()
        return folder
    }

    private func seedIfEmpty() {
        if fetchFolderModels().isEmpty {
            _ = ensureFolder()
        }
    }

    private func save() {
        try? context.save()
    }
}
