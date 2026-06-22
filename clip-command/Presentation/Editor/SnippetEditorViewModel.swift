//
//  SnippetEditorViewModel.swift
//  clip-command — Presentation 層 / 編集
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import Observation

/// スニペット編集ウィンドウの ViewModel。
@MainActor
@Observable
final class SnippetEditorViewModel {
    private let fetchUseCase: FetchSnippetFoldersUseCase
    private let addFolder: AddFolderUseCase
    private let renameFolder: RenameFolderUseCase
    private let deleteFolder: DeleteFolderUseCase
    private let addSnippet: AddSnippetUseCase
    private let updateSnippet: UpdateSnippetUseCase
    private let deleteSnippet: DeleteSnippetUseCase

    private(set) var folders: [SnippetFolderEntity] = []
    var selectedFolderID: UUID?
    var selectedSnippetID: UUID?

    init(
        fetchUseCase: FetchSnippetFoldersUseCase,
        addFolder: AddFolderUseCase,
        renameFolder: RenameFolderUseCase,
        deleteFolder: DeleteFolderUseCase,
        addSnippet: AddSnippetUseCase,
        updateSnippet: UpdateSnippetUseCase,
        deleteSnippet: DeleteSnippetUseCase
    ) {
        self.fetchUseCase = fetchUseCase
        self.addFolder = addFolder
        self.renameFolder = renameFolder
        self.deleteFolder = deleteFolder
        self.addSnippet = addSnippet
        self.updateSnippet = updateSnippet
        self.deleteSnippet = deleteSnippet
    }

    var selectedFolder: SnippetFolderEntity? {
        folders.first { $0.id == selectedFolderID }
    }

    var selectedSnippet: SnippetItem? {
        selectedFolder?.snippets.first { $0.id == selectedSnippetID }
    }

    func onAppear() {
        reload()
        if selectedFolderID == nil { selectedFolderID = folders.first?.id }
    }

    func reload() {
        folders = fetchUseCase.execute()
    }

    func createFolder() {
        let folder = addFolder.execute(name: "新規フォルダ")
        reload()
        selectedFolderID = folder.id
    }

    func removeSelectedFolder() {
        guard let id = selectedFolderID else { return }
        deleteFolder.execute(id: id)
        reload()
        selectedFolderID = folders.first?.id
        selectedSnippetID = nil
    }

    func createSnippet() {
        guard let folderID = selectedFolderID else { return }
        let snippet = addSnippet.execute(title: "新規スニペット", content: "", folderID: folderID)
        reload()
        selectedSnippetID = snippet?.id
    }

    func removeSelectedSnippet() {
        guard let id = selectedSnippetID else { return }
        deleteSnippet.execute(id: id)
        reload()
        selectedSnippetID = nil
    }

    func updateSelected(title: String, content: String) {
        guard let id = selectedSnippetID else { return }
        updateSnippet.execute(id: id, title: title, content: content)
        reload()
    }
}
