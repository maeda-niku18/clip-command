//
//  SnippetPanelViewModel.swift
//  clip-command — Presentation 層 / スニペット
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import Observation

/// スニペットパネルの ViewModel。
@MainActor
@Observable
final class SnippetPanelViewModel {
    private let fetchUseCase: FetchSnippetFoldersUseCase
    private let pasteUseCase: PasteTextUseCase
    private let autoPaste: () -> Bool

    var requestClose: () -> Void = {}
    var openEditor: () -> Void = {}

    var searchText = "" { didSet { selectedIndex = 0 } }
    private(set) var folders: [SnippetFolderEntity] = []
    var selectedIndex = 0

    init(
        fetchUseCase: FetchSnippetFoldersUseCase,
        pasteUseCase: PasteTextUseCase,
        autoPaste: @escaping () -> Bool
    ) {
        self.fetchUseCase = fetchUseCase
        self.pasteUseCase = pasteUseCase
        self.autoPaste = autoPaste
    }

    func onAppear() {
        selectedIndex = 0
        folders = fetchUseCase.execute()
    }

    /// 検索で絞り込んだフラットなスニペット一覧（キーボード選択用）。
    var flat: [SnippetItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return folders.flatMap(\.snippets).filter {
            q.isEmpty
                || $0.title.localizedCaseInsensitiveContains(q)
                || $0.content.localizedCaseInsensitiveContains(q)
        }
    }

    func folderName(for id: UUID?) -> String {
        folders.first { $0.id == id }?.name ?? ""
    }

    /// flat 上で、その位置がフォルダの先頭か（フォルダ見出しを差し込む判定）。
    func isFirstInFolder(_ index: Int) -> Bool {
        let items = flat
        guard items.indices.contains(index) else { return false }
        if index == 0 { return true }
        return items[index].folderID != items[index - 1].folderID
    }

    func move(_ delta: Int) {
        guard !flat.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), flat.count - 1)
    }

    func activateSelected() {
        guard flat.indices.contains(selectedIndex) else { return }
        paste(flat[selectedIndex])
    }

    func paste(_ snippet: SnippetItem) {
        requestClose()
        pasteUseCase.execute(snippet.content, autoPaste: autoPaste())
    }
}
