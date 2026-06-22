//
//  clip_commandApp.swift
//  clip-command — App 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import SwiftUI

@main
struct clip_commandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // メニューバー常駐エージェント。ウィンドウは AppCoordinator が AppKit で管理する。
        Settings { EmptyView() }
    }
}
