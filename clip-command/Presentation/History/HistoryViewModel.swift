//
//  HistoryViewModel.swift
//  clip-command — Presentation 層 / 履歴
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import AppKit
import Observation

/// 履歴パネルの ViewModel。ユースケース経由でドメインを操作し、View に状態を公開する。
@MainActor
@Observable
final class HistoryViewModel {
    private let searchUseCase: SearchHistoryUseCase
    private let deleteUseCase: DeleteClipUseCase
    private let togglePinUseCase: TogglePinUseCase
    private let pasteUseCase: PasteEntryUseCase
    private let quickAddUseCase: QuickAddSnippetUseCase
    private let images: ImageRepository
    private let autoPaste: () -> Bool

    /// UI フロー（パネルを閉じる / 編集を開く）はコーディネータが注入する。
    var requestClose: () -> Void = {}
    var openEditor: () -> Void = {}

    /// 入力フォーカスの対象。Return キーの分岐に使う。
    enum Field {
        case search
        case snippet
    }

    var searchText = "" { didSet { refresh() } }
    private(set) var results: [ClipEntry] = []
    var selectedIndex = 0
    var hoveredID: UUID?
    /// 詳細プレビューを表示する対象。ホバー / キー選択のうち「後に操作した方」で上書きする（後勝ち）。
    var previewID: UUID?
    var snippetDraft = ""
    var focusedField: Field = .search

    /// 現在キー選択している項目の ID。
    var selectedEntryID: UUID? {
        results.indices.contains(selectedIndex) ? results[selectedIndex].id : nil
    }

    init(
        searchUseCase: SearchHistoryUseCase,
        deleteUseCase: DeleteClipUseCase,
        togglePinUseCase: TogglePinUseCase,
        pasteUseCase: PasteEntryUseCase,
        quickAddUseCase: QuickAddSnippetUseCase,
        images: ImageRepository,
        autoPaste: @escaping () -> Bool
    ) {
        self.searchUseCase = searchUseCase
        self.deleteUseCase = deleteUseCase
        self.togglePinUseCase = togglePinUseCase
        self.pasteUseCase = pasteUseCase
        self.quickAddUseCase = quickAddUseCase
        self.images = images
        self.autoPaste = autoPaste
    }

    func onAppear() {
        selectedIndex = 0
        refresh()
    }

    func refresh() {
        results = searchUseCase.execute(query: searchText)
        clampSelection()
        previewID = selectedEntryID
    }

    func move(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(0, selectedIndex + delta), results.count - 1)
        previewID = selectedEntryID // 後勝ち：キー選択が最後の操作
    }

    /// Return キー押下時の分岐：登録欄なら即スニペット登録、それ以外は選択を貼り付け。
    func handleReturn() {
        if focusedField == .snippet {
            registerSnippet()
        } else {
            activateSelected()
        }
    }

    func activateSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        paste(results[selectedIndex])
    }

    func paste(_ entry: ClipEntry) {
        requestClose()
        pasteUseCase.execute(entry: entry, autoPaste: autoPaste())
    }

    /// ⌘1〜9：表示中の n 番目（0始まり）を貼り付け。
    func paste(at index: Int) {
        guard results.indices.contains(index) else { return }
        paste(results[index])
    }

    func togglePin(_ entry: ClipEntry) {
        togglePinUseCase.execute(entry: entry)
        refresh()
    }

    func togglePinSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        togglePin(results[selectedIndex])
    }

    func delete(_ entry: ClipEntry) {
        deleteUseCase.execute(id: entry.id)
        refresh()
    }

    func registerSnippet() {
        let text = snippetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        quickAddUseCase.execute(content: text, title: nil)
        snippetDraft = ""
    }

    func fillDraftFromSelected() {
        guard results.indices.contains(selectedIndex),
              results[selectedIndex].kind == .text else { return }
        snippetDraft = results[selectedIndex].text ?? ""
    }

    var selectedIsText: Bool {
        results.indices.contains(selectedIndex) && results[selectedIndex].kind == .text
    }

    func image(for entry: ClipEntry) -> NSImage? {
        images.loadData(ref: entry.imageRef).flatMap(NSImage.init(data:))
    }

    func metadata(for entry: ClipEntry) -> String {
        let date = entry.createdAt.formatted(date: .abbreviated, time: .shortened)
        switch entry.kind {
        case .text: return "\(entry.text?.count ?? 0) 文字 ・ \(date)"
        case .image: return "画像 ・ \(date)"
        }
    }

    private func clampSelection() {
        if results.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(selectedIndex, results.count - 1)
        }
    }
}
