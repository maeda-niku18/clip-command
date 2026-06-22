//
//  FloatingPanel.swift
//  clip-command — Presentation 層 / 共通
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import AppKit
import SwiftUI

/// 前面アプリをアクティブにしたまま表示できるパネル。
/// nonactivating により入力フォーカスを得つつ前面アプリのフォーカスを奪わない。
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// フローティングパネルの表示制御。SwiftUI ビューをホストし、
/// マウス位置付近への表示・フォーカス喪失での自動クローズを行う。
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: FloatingPanel?
    private let size: NSSize

    /// ↑↓キーのハンドラ（delta: -1=上, +1=下）。表示のたびに差し替える。
    private var verticalArrow: ((Int) -> Void)?
    /// Return キーのハンドラ。
    private var returnKey: (() -> Void)?
    /// Escape キーのハンドラ。
    private var escape: (() -> Void)?
    /// ⌘1〜9 のハンドラ（1〜9）。
    private var commandNumber: ((Int) -> Void)?
    /// ⌘P のハンドラ。
    private var togglePin: (() -> Void)?
    private var keyMonitor: Any?

    init(size: NSSize) {
        self.size = size
    }

    /// SwiftUI ビューを表示する。↑↓ / Return / Escape は、TextField にフォーカスがあると
    /// SwiftUI 側（onKeyPress / onSubmit / onExitCommand）で拾えないため、
    /// パネルが key のあいだ AppKit レベルのキーモニタで処理する。
    func show<Content: View>(
        onVerticalArrow: ((Int) -> Void)? = nil,
        onReturn: (() -> Void)? = nil,
        onEscape: (() -> Void)? = nil,
        onCommandNumber: ((Int) -> Void)? = nil,
        onTogglePin: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.verticalArrow = onVerticalArrow
        self.returnKey = onReturn
        self.escape = onEscape
        self.commandNumber = onCommandNumber
        self.togglePin = onTogglePin
        let hosting = NSHostingView(rootView: AnyView(
            content().frame(width: size.width, height: size.height)
        ))
        let panel = self.panel ?? makePanel()
        panel.contentView = hosting
        positionNearMouse(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installKeyMonitorIfNeeded()
    }

    func close() {
        panel?.orderOut(nil)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: size))
        panel.delegate = self
        return panel
    }

    /// パネルが key のあいだ ↑↓ を捕捉して selection 移動に回す（矢印はフィールドに渡さず消費）。
    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // パネル本体、またはパネルに紐づく popover（子ウィンドウ）が key のあいだ捕捉する。
            guard let self,
                  let panel = self.panel,
                  panel.isVisible,
                  event.window === panel || event.window?.parent === panel else { return event }

            // 矢印キーには .function / .numericPad が、英字キーには capsLock 状態が乗るため、
            // それらを除いた「意味のある修飾」だけで分岐する（さもないと ↑↓ が素通りしてビープ）。
            let flags = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.function, .numericPad, .capsLock])

            // ⌘ 修飾つき：⌘1〜9 で即貼り付け、⌘P でピン留めトグル。
            if flags == .command {
                if let number = Self.numberKey(for: event.keyCode), let handler = self.commandNumber {
                    handler(number); return nil
                }
                if event.keyCode == 35, let handler = self.togglePin { // P
                    handler(); return nil
                }
                return event
            }

            // 修飾なしのナビゲーションキー。
            guard flags.isEmpty else { return event }
            switch event.keyCode {
            case 126: self.verticalArrow?(-1); return nil // ↑
            case 125: self.verticalArrow?(1); return nil  // ↓
            case 36, 76: self.returnKey?(); return nil    // Return / Enter
            case 53: self.escape?(); return nil           // Esc
            default: return event
            }
        }
    }

    private func positionNearMouse(_ panel: FloatingPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        var origin = NSPoint(x: mouse.x, y: mouse.y - size.height)
        origin.x = min(max(visible.minX, origin.x), visible.maxX - size.width)
        origin.y = min(max(visible.minY, origin.y), visible.maxY - size.height)
        panel.setFrameOrigin(origin)
    }

    func windowDidResignKey(_ notification: Notification) {
        // hover プレビューの popover など、アプリ内の付随ウィンドウへ key が移った
        // だけでは閉じない。本当に他アプリ／他ウィンドウへ移ったときだけ閉じる。
        // （閉じてしまうとキーモニタの isKeyWindow 条件が崩れ、↑↓ ナビが効かなくなる）
        DispatchQueue.main.async { [weak self] in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if panel.isKeyWindow { return }
            if let key = NSApp.keyWindow, key === panel || key.parent === panel { return }
            self.close()
        }
    }

    /// 数字キー(1〜9)の仮想キーコード → 数値。
    private static func numberKey(for keyCode: UInt16) -> Int? {
        switch keyCode {
        case 18: return 1
        case 19: return 2
        case 20: return 3
        case 21: return 4
        case 23: return 5
        case 22: return 6
        case 26: return 7
        case 28: return 8
        case 25: return 9
        default: return nil
        }
    }
}
