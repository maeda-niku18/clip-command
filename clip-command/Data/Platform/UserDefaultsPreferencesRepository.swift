//
//  UserDefaultsPreferencesRepository.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation

/// PreferencesRepository の UserDefaults 実装。
struct UserDefaultsPreferencesRepository: PreferencesRepository {
    private let defaults = UserDefaults.standard

    func load() -> AppPreferences {
        var prefs = AppPreferences()
        if defaults.object(forKey: Keys.historyLimit) != nil {
            prefs.historyLimit = defaults.integer(forKey: Keys.historyLimit)
        }
        if defaults.object(forKey: Keys.autoPaste) != nil {
            prefs.autoPaste = defaults.bool(forKey: Keys.autoPaste)
        }
        if defaults.object(forKey: Keys.pollInterval) != nil {
            prefs.pollInterval = defaults.double(forKey: Keys.pollInterval)
        }
        prefs.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        prefs.historyHotKey = loadHotKey(Keys.historyHotKey) ?? .historyDefault
        prefs.snippetHotKey = loadHotKey(Keys.snippetHotKey) ?? .snippetDefault
        prefs.quickSnippetHotKey = loadHotKey(Keys.quickSnippetHotKey) ?? .quickSnippetDefault
        return prefs
    }

    func save(_ preferences: AppPreferences) {
        defaults.set(preferences.historyLimit, forKey: Keys.historyLimit)
        defaults.set(preferences.autoPaste, forKey: Keys.autoPaste)
        defaults.set(preferences.pollInterval, forKey: Keys.pollInterval)
        defaults.set(preferences.launchAtLogin, forKey: Keys.launchAtLogin)
        saveHotKey(preferences.historyHotKey, Keys.historyHotKey)
        saveHotKey(preferences.snippetHotKey, Keys.snippetHotKey)
        saveHotKey(preferences.quickSnippetHotKey, Keys.quickSnippetHotKey)
    }

    private func loadHotKey(_ key: String) -> HotKeyConfig? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyConfig.self, from: data)
    }

    private func saveHotKey(_ config: HotKeyConfig, _ key: String) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }

    private enum Keys {
        static let historyLimit = "historyLimit"
        static let autoPaste = "autoPaste"
        static let pollInterval = "pollInterval"
        static let launchAtLogin = "launchAtLogin"
        static let historyHotKey = "historyHotKey"
        static let snippetHotKey = "snippetHotKey"
        static let quickSnippetHotKey = "quickSnippetHotKey"
    }
}
