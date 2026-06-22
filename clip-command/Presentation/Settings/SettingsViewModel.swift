//
//  SettingsViewModel.swift
//  clip-command — Presentation 層 / 設定
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import Observation

/// 設定の ViewModel。変更を都度永続化し、ホットキー変更・監視間隔変更を外部へ通知する。
@MainActor
@Observable
final class SettingsViewModel {
    private let repository: PreferencesRepository
    private let loginItem: LoginItemService
    private let clearHistoryUseCase: ClearHistoryUseCase
    private let paste: PasteService

    /// ホットキー変更時に呼ばれる（再登録用）。
    var onHotKeysChanged: () -> Void = {}
    /// 監視間隔変更時に呼ばれる（監視再起動用）。
    var onPollIntervalChanged: () -> Void = {}

    private(set) var preferences: AppPreferences

    init(
        repository: PreferencesRepository,
        loginItem: LoginItemService,
        clearHistoryUseCase: ClearHistoryUseCase,
        paste: PasteService
    ) {
        self.repository = repository
        self.loginItem = loginItem
        self.clearHistoryUseCase = clearHistoryUseCase
        self.paste = paste
        self.preferences = repository.load()
    }

    /// 現在の設定（コーディネータが起動時に参照）。
    var current: AppPreferences { preferences }

    var historyLimit: Int {
        get { preferences.historyLimit }
        set { preferences.historyLimit = newValue; persist() }
    }

    var autoPaste: Bool {
        get { preferences.autoPaste }
        set { preferences.autoPaste = newValue; persist() }
    }

    var pollInterval: Double {
        get { preferences.pollInterval }
        set { preferences.pollInterval = newValue; persist(); onPollIntervalChanged() }
    }

    var launchAtLogin: Bool {
        get { preferences.launchAtLogin }
        set {
            preferences.launchAtLogin = newValue
            persist()
            loginItem.setEnabled(newValue)
        }
    }

    var historyHotKey: HotKeyConfig {
        get { preferences.historyHotKey }
        set { preferences.historyHotKey = newValue; persist(); onHotKeysChanged() }
    }

    var snippetHotKey: HotKeyConfig {
        get { preferences.snippetHotKey }
        set { preferences.snippetHotKey = newValue; persist(); onHotKeysChanged() }
    }

    var quickSnippetHotKey: HotKeyConfig {
        get { preferences.quickSnippetHotKey }
        set { preferences.quickSnippetHotKey = newValue; persist(); onHotKeysChanged() }
    }

    var hasAccessibility: Bool { paste.hasAccessibility }

    func requestAccessibility() { paste.requestAccessibility() }

    func clearHistory() { clearHistoryUseCase.execute() }

    private func persist() {
        repository.save(preferences)
    }
}
