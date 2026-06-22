//
//  AppContainer.swift
//  clip-command — App 層 / 合成ルート（DI）
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  依存を一箇所で組み立てる合成ルート。各層は具象を知らず、ここでだけ結線する。
//

import Foundation
import SwiftData

@MainActor
final class AppContainer {
    // 永続化
    let modelContainer: ModelContainer

    // サービス / リポジトリ（ポート実装）
    let images: ImageRepository
    let clipboardRepository: ClipboardRepository
    let snippetRepository: SnippetRepository
    let preferencesRepository: PreferencesRepository
    let watcher: ClipboardWatcher
    let pasteService: PasteService
    let loginItem: LoginItemService

    // ユースケース
    let ingestUseCase: IngestClipboardUseCase
    let quickAddUseCase: QuickAddSnippetUseCase

    // ViewModel
    let settingsViewModel: SettingsViewModel
    let historyViewModel: HistoryViewModel
    let snippetViewModel: SnippetPanelViewModel
    let editorViewModel: SnippetEditorViewModel

    init() {
        let schema = Schema([ClipItemModel.self, SnippetFolderModel.self, SnippetModel.self])
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema)
        } catch {
            NSLog("ModelContainer 生成に失敗、インメモリにフォールバック: \(error)")
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: config)
        }
        self.modelContainer = container
        let context = container.mainContext

        // ポート実装
        let images = ImageFileStore()
        let clipboardRepository = SwiftDataClipboardRepository(context: context, images: images)
        let snippetRepository = SwiftDataSnippetRepository(context: context)
        let preferencesRepository = UserDefaultsPreferencesRepository()
        let watcher = PasteboardMonitorAdapter()
        let pasteService = PasteServiceImpl(watcher: watcher)
        let loginItem = LoginItemServiceImpl()

        self.images = images
        self.clipboardRepository = clipboardRepository
        self.snippetRepository = snippetRepository
        self.preferencesRepository = preferencesRepository
        self.watcher = watcher
        self.pasteService = pasteService
        self.loginItem = loginItem

        // ユースケース
        self.ingestUseCase = IngestClipboardUseCase(clipboard: clipboardRepository, images: images)
        self.quickAddUseCase = QuickAddSnippetUseCase(snippets: snippetRepository)

        // ViewModel
        let settingsViewModel = SettingsViewModel(
            repository: preferencesRepository,
            loginItem: loginItem,
            clearHistoryUseCase: ClearHistoryUseCase(clipboard: clipboardRepository),
            paste: pasteService
        )
        self.settingsViewModel = settingsViewModel

        self.historyViewModel = HistoryViewModel(
            searchUseCase: SearchHistoryUseCase(clipboard: clipboardRepository),
            deleteUseCase: DeleteClipUseCase(clipboard: clipboardRepository),
            togglePinUseCase: TogglePinUseCase(clipboard: clipboardRepository),
            pasteUseCase: PasteEntryUseCase(images: images, paste: pasteService),
            quickAddUseCase: QuickAddSnippetUseCase(snippets: snippetRepository),
            images: images,
            autoPaste: { settingsViewModel.autoPaste }
        )

        self.snippetViewModel = SnippetPanelViewModel(
            fetchUseCase: FetchSnippetFoldersUseCase(snippets: snippetRepository),
            pasteUseCase: PasteTextUseCase(paste: pasteService),
            autoPaste: { settingsViewModel.autoPaste }
        )

        self.editorViewModel = SnippetEditorViewModel(
            fetchUseCase: FetchSnippetFoldersUseCase(snippets: snippetRepository),
            addFolder: AddFolderUseCase(snippets: snippetRepository),
            renameFolder: RenameFolderUseCase(snippets: snippetRepository),
            deleteFolder: DeleteFolderUseCase(snippets: snippetRepository),
            addSnippet: AddSnippetUseCase(snippets: snippetRepository),
            updateSnippet: UpdateSnippetUseCase(snippets: snippetRepository),
            deleteSnippet: DeleteSnippetUseCase(snippets: snippetRepository)
        )
    }
}
