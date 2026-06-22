//
//  SettingsView.swift
//  clip-command — Presentation 層 / 設定
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import SwiftUI

/// 設定ウィンドウ。履歴件数・ショートカット・貼り付け方式などを編集する。
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        TabView {
            generalTab.tabItem { Label("一般", systemImage: "gear") }
            shortcutTab.tabItem { Label("ショートカット", systemImage: "command") }
        }
        .frame(width: 460, height: 360)
    }

    private var generalTab: some View {
        Form {
            Section("履歴") {
                Stepper(value: $viewModel.historyLimit, in: 10...500, step: 10) {
                    Text("保持件数: \(viewModel.historyLimit)")
                }
                Button("履歴をすべてクリア", role: .destructive) { viewModel.clearHistory() }
            }
            Section("貼り付け") {
                Toggle("選択時に自動で貼り付ける", isOn: $viewModel.autoPaste)
                if viewModel.autoPaste && !viewModel.hasAccessibility {
                    HStack {
                        Text("アクセシビリティ許可が必要です").foregroundStyle(.secondary).font(.caption)
                        Button("許可をリクエスト") { viewModel.requestAccessibility() }.font(.caption)
                    }
                }
            }
            Section("監視") {
                Slider(value: $viewModel.pollInterval, in: 0.2...2.0, step: 0.1) {
                    Text("間隔")
                } minimumValueLabel: { Text("0.2s") } maximumValueLabel: { Text("2.0s") }
                Text("\(viewModel.pollInterval, specifier: "%.1f") 秒ごと").font(.caption).foregroundStyle(.secondary)
            }
            Section("起動") {
                Toggle("ログイン時に自動起動", isOn: $viewModel.launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutTab: some View {
        Form {
            HotKeyEditor(title: "履歴を表示", config: $viewModel.historyHotKey)
            HotKeyEditor(title: "スニペットを表示", config: $viewModel.snippetHotKey)
            HotKeyEditor(title: "クリップボードを即スニペット登録", config: $viewModel.quickSnippetHotKey)
        }
        .formStyle(.grouped)
    }
}

/// 修飾キーのトグルとキー選択でショートカットを編集する。
struct HotKeyEditor: View {
    let title: String
    @Binding var config: HotKeyConfig

    var body: some View {
        Section(title) {
            HStack {
                Text(KeyCodes.description(config)).font(.system(.body, design: .monospaced))
                Spacer()
                modifierToggle("⌘", KeyCodes.cmd)
                modifierToggle("⇧", KeyCodes.shift)
                modifierToggle("⌥", KeyCodes.option)
                modifierToggle("⌃", KeyCodes.control)
                Picker("", selection: Binding(
                    get: { KeyCodes.letter(for: config.keyCode) },
                    set: { config.keyCode = KeyCodes.letterToCode[$0] ?? config.keyCode }
                )) {
                    ForEach(KeyCodes.letters, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 60)
            }
        }
    }

    private func modifierToggle(_ label: String, _ mask: UInt32) -> some View {
        let isOn = config.modifiers & mask != 0
        return Button(label) {
            if isOn { config.modifiers &= ~mask } else { config.modifiers |= mask }
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : nil)
    }
}
