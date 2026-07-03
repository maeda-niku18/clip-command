//
//  PasteboardMonitorAdapter.swift
//  clip-command — Data 層 / Platform
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import AppKit

/// ClipboardWatcher の実装。一般ペーストボードの changeCount をポーリングして変化を通知する。
/// 画像は PNG の Data に変換して渡し、上位層を AppKit 非依存に保つ。
@MainActor
final class PasteboardMonitorAdapter: ClipboardWatcher {
    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount = 0
    private var suppress = false
    private var onChange: ((String?, Data?, Data?) -> Void)?

    func start(interval: TimeInterval, onChange: @escaping (String?, Data?, Data?) -> Void) {
        stop()
        self.onChange = onChange
        lastChangeCount = pasteboard.changeCount
        let timer = Timer.scheduledTimer(withTimeInterval: max(0.1, interval), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func suppressNext() {
        suppress = true
    }

    private func check() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if suppress {
            suppress = false
            return
        }

        // パスワードマネージャ等が付与する機密フラグが付いていれば履歴に残さない。
        if let types = pasteboard.types, types.contains(where: { Self.concealedTypes.contains($0.rawValue) }) {
            return
        }

        let text = pasteboard.string(forType: .string)
        var rtfData: Data?
        var imageData: Data?
        if let text, !text.isEmpty {
            // 書式付きテキストがあれば保持（プレーン変換オフ時の書式維持貼り付けに使う）。
            rtfData = pasteboard.data(forType: .rtf)
        } else {
            if let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil),
               let image = objects.first as? NSImage {
                imageData = Self.pngData(from: image)
            }
        }
        onChange?(text, rtfData, imageData)
    }

    /// 履歴に残さない機密ペーストボード型。
    private static let concealedTypes: Set<String> = [
        "org.nspasteboard.ConcealedType",
        "com.agilebits.onepassword",
    ]

    static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
