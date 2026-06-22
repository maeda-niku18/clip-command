//
//  SnippetUseCases.swift
//  clip-command — Domain 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation

struct FetchSnippetFoldersUseCase {
    let snippets: SnippetRepository
    func execute() -> [SnippetFolderEntity] { snippets.fetchFolders() }
}

struct AddFolderUseCase {
    let snippets: SnippetRepository
    @discardableResult
    func execute(name: String) -> SnippetFolderEntity { snippets.addFolder(name: name) }
}

struct RenameFolderUseCase {
    let snippets: SnippetRepository
    func execute(id: UUID, name: String) { snippets.renameFolder(id: id, name: name) }
}

struct DeleteFolderUseCase {
    let snippets: SnippetRepository
    func execute(id: UUID) { snippets.deleteFolder(id: id) }
}

struct AddSnippetUseCase {
    let snippets: SnippetRepository
    @discardableResult
    func execute(title: String, content: String, folderID: UUID?) -> SnippetItem? {
        snippets.addSnippet(title: title, content: content, folderID: folderID)
    }
}

struct UpdateSnippetUseCase {
    let snippets: SnippetRepository
    func execute(id: UUID, title: String, content: String) {
        snippets.updateSnippet(id: id, title: title, content: content)
    }
}

struct DeleteSnippetUseCase {
    let snippets: SnippetRepository
    func execute(id: UUID) { snippets.deleteSnippet(id: id) }
}

/// クリップボード内容などから手早くスニペットを登録する。タイトル省略時は本文先頭行から導出。
struct QuickAddSnippetUseCase {
    let snippets: SnippetRepository
    func execute(content: String, title: String?) {
        let resolved = (title?.isEmpty == false) ? title! : SnippetTitle.derive(from: content)
        snippets.addSnippet(title: resolved, content: content, folderID: nil)
    }
}
