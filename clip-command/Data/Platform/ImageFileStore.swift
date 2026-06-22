//
//  ImageFileStore.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation

/// ImageRepository の実装。サンドボックスコンテナ内 Application Support に PNG を保存する。
struct ImageFileStore: ImageRepository {

    private var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundleID = Bundle.main.bundleIdentifier ?? "clip-command"
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    @discardableResult
    func save(data: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    func loadData(ref: String?) -> Data? {
        guard let ref else { return nil }
        return try? Data(contentsOf: directory.appendingPathComponent(ref))
    }

    func delete(ref: String?) {
        guard let ref else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(ref))
    }
}
