//
//  AppCoordinator.swift
//  clip-command — App 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  UI フローの調停役。ステータスバー・パネル・ウィンドウ・ホットキー・監視を結線する。
//

import AppKit
import SwiftUI

@MainActor
final class AppCoordinator: NSObject, NSWindowDelegate {
    private let container: AppContainer

    private var statusItem: NSStatusItem!
    private let historyPanel = PanelController(size: NSSize(width: 420, height: 460))
    private let snippetPanel = PanelController(size: NSSize(width: 380, height: 420))
    private var settingsWindow: NSWindow?
    private var editorWindow: NSWindow?
    private let updaterService = UpdaterService()

    init(container: AppContainer) {
        self.container = container
    }

    func start() {
        wireViewModels()
        setupStatusItem()
        setupMonitor()
        registerHotKeys()
        promptAccessibilityIfNeeded()
    }

    // MARK: - アクセシビリティ

    /// 自動貼り付けが有効なのにアクセシビリティ未許可なら、起動時に警告して許可へ誘導する。
    private func promptAccessibilityIfNeeded() {
        guard container.settingsViewModel.autoPaste,
              !container.pasteService.hasAccessibility else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "アクセシビリティの許可が必要です"
        alert.informativeText = """
        自動貼り付け（選んだ項目を前面アプリへ ⌘V で貼り付け）には、\
        「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で clip-command を許可してください。

        許可するまでは、選んだ内容はクリップボードにコピーされるので、手動の ⌘V で貼り付けできます。
        （許可後はアプリの再起動が必要な場合があります）
        """
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "あとで")

        if alert.runModal() == .alertFirstButtonReturn {
            container.pasteService.requestAccessibility()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - 結線

    private func wireViewModels() {
        container.historyViewModel.requestClose = { [weak self] in self?.historyPanel.close() }
        container.historyViewModel.openEditor = { [weak self] in self?.openEditor() }
        container.snippetViewModel.requestClose = { [weak self] in self?.snippetPanel.close() }
        container.snippetViewModel.openEditor = { [weak self] in self?.openEditor() }
        container.settingsViewModel.onHotKeysChanged = { [weak self] in self?.registerHotKeys() }
        container.settingsViewModel.onPollIntervalChanged = { [weak self] in self?.setupMonitor() }
    }

    // MARK: - ステータスバー

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "clip-command"
        )

        let menu = NSMenu()
        addItem(menu, "履歴を表示", #selector(showHistory))
        addItem(menu, "スニペットを表示", #selector(showSnippets))
        menu.addItem(.separator())
        addItem(menu, "スニペットを編集…", #selector(openEditor))
        addItem(menu, "設定…", #selector(openSettings))
        addItem(menu, "アップデートを確認…", #selector(checkForUpdates))
        menu.addItem(.separator())
        addItem(menu, "履歴をクリア", #selector(clearHistory))
        addItem(menu, "clip-command を終了", #selector(quit))
        statusItem.menu = menu
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: - 監視 / ホットキー

    private func setupMonitor() {
        container.watcher.start(interval: container.settingsViewModel.pollInterval) { [weak self] text, imageData in
            guard let self else { return }
            self.container.ingestUseCase.execute(
                text: text,
                imageData: imageData,
                limit: self.container.settingsViewModel.historyLimit
            )
        }
    }

    private func registerHotKeys() {
        let prefs = container.settingsViewModel.current
        CarbonHotKeyManager.shared.unregisterAll()
        CarbonHotKeyManager.shared.register(prefs.historyHotKey) { [weak self] in self?.toggleHistory() }
        CarbonHotKeyManager.shared.register(prefs.snippetHotKey) { [weak self] in self?.toggleSnippets() }
        CarbonHotKeyManager.shared.register(prefs.quickSnippetHotKey) { [weak self] in self?.quickSnippet() }
    }

    // MARK: - パネル

    private func toggleHistory() {
        if historyPanel.isVisible { historyPanel.close() } else { showHistory() }
    }

    private func toggleSnippets() {
        if snippetPanel.isVisible { snippetPanel.close() } else { showSnippets() }
    }

    @objc private func showHistory() {
        historyPanel.show(
            onVerticalArrow: { [weak self] delta in self?.container.historyViewModel.move(delta) },
            onReturn: { [weak self] in self?.container.historyViewModel.handleReturn() },
            onEscape: { [weak self] in self?.historyPanel.close() },
            onCommandNumber: { [weak self] n in self?.container.historyViewModel.paste(at: n - 1) },
            onTogglePin: { [weak self] in self?.container.historyViewModel.togglePinSelected() }
        ) {
            HistoryPanelView(viewModel: container.historyViewModel)
        }
    }

    @objc private func showSnippets() {
        snippetPanel.show(
            onVerticalArrow: { [weak self] delta in self?.container.snippetViewModel.move(delta) },
            onReturn: { [weak self] in self?.container.snippetViewModel.activateSelected() },
            onEscape: { [weak self] in self?.snippetPanel.close() }
        ) {
            SnippetPanelView(viewModel: container.snippetViewModel)
        }
    }

    // MARK: - スニペット即登録

    private func quickSnippet() {
        guard let content = NSPasteboard.general.string(forType: .string), !content.isEmpty else {
            NSSound.beep()
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "スニペットを登録"
        alert.informativeText = "タイトルを入力してください"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = SnippetTitle.derive(from: content)
        alert.accessoryView = field
        alert.addButton(withTitle: "登録")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn {
            container.quickAddUseCase.execute(content: content, title: field.stringValue)
        }
    }

    // MARK: - ウィンドウ

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = makeWindow(
                title: "設定",
                size: NSSize(width: 460, height: 360),
                view: SettingsView(viewModel: container.settingsViewModel)
            )
            window.delegate = self
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openEditor() {
        if editorWindow == nil {
            editorWindow = makeWindow(
                title: "スニペット編集",
                size: NSSize(width: 760, height: 460),
                view: SnippetEditorView(viewModel: container.editorViewModel)
            )
        }
        NSApp.activate(ignoringOtherApps: true)
        editorWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func clearHistory() {
        container.settingsViewModel.clearHistory()
    }

    @objc private func checkForUpdates() {
        updaterService.checkForUpdates()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func makeWindow<V: View>(title: String, size: NSSize, view: V) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
