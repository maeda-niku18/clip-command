//
//  Ports.swift
//  clip-command — Domain 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  外側の層（Data / Platform）が実装すべきインターフェース（ポート）。
//  依存方向は常に内向き：Domain はこれらの実装を一切知らない。
//

import Foundation

/// クリップボード履歴の永続化ポート。
protocol ClipboardRepository {
    func fetchAll() -> [ClipEntry]
    func addText(_ text: String)
    @discardableResult func addImage(data: Data) -> ClipEntry?
    func touch(id: UUID)
    func setPinned(id: UUID, pinned: Bool)
    func delete(id: UUID)
    func deleteAll()
    /// ピン留め項目を除いた最新 limit 件を残し、それより古い非ピン項目を削除する。
    func trim(to limit: Int)
}

/// スニペットの永続化ポート。
protocol SnippetRepository {
    func fetchFolders() -> [SnippetFolderEntity]
    @discardableResult func addFolder(name: String) -> SnippetFolderEntity
    func renameFolder(id: UUID, name: String)
    func deleteFolder(id: UUID)
    @discardableResult func addSnippet(title: String, content: String, folderID: UUID?) -> SnippetItem?
    func updateSnippet(id: UUID, title: String, content: String)
    func deleteSnippet(id: UUID)
}

/// 画像実体の保存・読込ポート。Domain は Data（PNG バイト列）でやり取りする。
protocol ImageRepository {
    @discardableResult func save(data: Data) -> String?
    func loadData(ref: String?) -> Data?
    func delete(ref: String?)
}

/// 前面アプリへの貼り付けポート。
protocol PasteService {
    var hasAccessibility: Bool { get }
    func requestAccessibility()
    func pasteText(_ text: String, autoPaste: Bool)
    func pasteImage(data: Data, autoPaste: Bool)
}

/// クリップボード変化の監視ポート。
protocol ClipboardWatcher {
    func start(interval: TimeInterval, onChange: @escaping (String?, Data?) -> Void)
    func stop()
    /// 自アプリの書き込みによる次の変化を取り込まないよう抑止する。
    func suppressNext()
}

/// 設定の永続化ポート。
protocol PreferencesRepository {
    func load() -> AppPreferences
    func save(_ preferences: AppPreferences)
}

/// ログイン項目（自動起動）ポート。
protocol LoginItemService {
    func setEnabled(_ enabled: Bool)
}
