//
//  UpdaterService.swift
//  clip-command — App 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  Sparkle による自動アップデートを管理する。
//

import AppKit
import Sparkle

/// Sparkle の更新コントローラを保持するサービス。
/// フィード（SUFeedURL）と公開鍵（SUPublicEDKey）は Info.plist で設定する。
///
/// 本アプリはメニューバー常駐（LSUIElement / 通常は Dock アイコン無しの .accessory）。
/// その状態では Sparkle の更新ウィンドウが前面に出ず「インストールして再起動」を
/// 押せないため、更新セッション中だけ一時的に通常アプリ（.regular）化して前面に出す。
@MainActor
final class UpdaterService: NSObject, SPUStandardUserDriverDelegate {
    private var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
    }

    /// ユーザー操作による手動チェック。
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    /// 更新 UI を表示する直前。エージェントアプリを前面化して、確認・再起動ボタンを操作可能にする。
    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 更新セッション終了時。メニューバー常駐（Dock アイコン無し）に戻す。
    func standardUserDriverWillFinishUpdateSession() {
        NSApp.setActivationPolicy(.accessory)
    }
}
