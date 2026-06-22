//
//  PasteServiceImpl.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import AppKit
import ApplicationServices
import Carbon

/// PasteService の実装。ペーストボードへの書き込みと ⌘V 擬似入力を担う。
@MainActor
final class PasteServiceImpl: PasteService {
    private let watcher: ClipboardWatcher

    init(watcher: ClipboardWatcher) {
        self.watcher = watcher
    }

    var hasAccessibility: Bool { AXIsProcessTrusted() }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func pasteText(_ text: String, autoPaste: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        finish(autoPaste: autoPaste)
    }

    func pasteImage(data: Data, autoPaste: Bool) {
        guard let image = NSImage(data: data) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
        finish(autoPaste: autoPaste)
    }

    private func finish(autoPaste: Bool) {
        watcher.suppressNext()
        guard autoPaste, hasAccessibility else { return }
        // パネルが閉じて前面アプリにフォーカスが戻るのを待ってから送出する。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            Self.sendCommandV()
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
