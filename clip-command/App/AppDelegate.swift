//
//  AppDelegate.swift
//  clip-command — App 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import AppKit

/// 薄いアプリデリゲート。合成ルートとコーディネータを起動するだけ。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var container: AppContainer!
    private var coordinator: AppCoordinator!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer()
        self.container = container
        let coordinator = AppCoordinator(container: container)
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
