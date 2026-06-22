//
//  LoginItemServiceImpl.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import ServiceManagement

/// LoginItemService の実装。SMAppService でログイン項目の登録/解除を行う。
struct LoginItemServiceImpl: LoginItemService {
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("launchAtLogin の更新に失敗: \(error)")
        }
    }
}
