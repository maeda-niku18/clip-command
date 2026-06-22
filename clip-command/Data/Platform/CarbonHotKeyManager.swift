//
//  CarbonHotKeyManager.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Carbon
import Foundation

private let kHotKeySignature: OSType = 0x434C4950 // 'CLIP'

/// Carbon RegisterEventHotKey を薄くラップしたグローバルショートカット管理。
/// サンドボックス内で追加権限なしに動作する。
@MainActor
final class CarbonHotKeyManager {
    static let shared = CarbonHotKeyManager()

    private var actions: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    private init() {}

    @discardableResult
    func register(_ config: HotKeyConfig, action: @escaping () -> Void) -> UInt32 {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1
        actions[id] = action

        let hotKeyID = EventHotKeyID(signature: kHotKeySignature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            refs[id] = ref
        }
        return id
    }

    func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C 関数ポインタ用クロージャはコンテキストをキャプチャできず非分離。
        // ホットキーイベントはメインスレッドで配送されるため assumeIsolated で安全に処理する。
        let callback: EventHandlerUPP = { _, event, _ -> OSStatus in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if err == noErr {
                let id = hotKeyID.id
                MainActor.assumeIsolated {
                    CarbonHotKeyManager.shared.fire(id: id)
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, nil)
    }
}
