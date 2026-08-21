//
//  Entities.swift
//  clip-command — Domain 層
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//
//  フレームワーク非依存（Foundation のみ）。永続化・UI・Carbon などに一切依存しない。
//

import Foundation

// MARK: - 履歴

enum ClipKind: String, Codable, Sendable {
    case text
    case image
}

/// クリップボード履歴の1項目（ドメインエンティティ）。
/// 画像は実体ではなく参照（imageRef）のみを持ち、メモリと層の独立を保つ。
struct ClipEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let kind: ClipKind
    let text: String?
    let imageRef: String?
    /// コピー元の書式付きテキスト（RTF）。取得できた場合のみ保持し、書式維持での貼り付けに使う。
    var rtfData: Data?
    var isPinned: Bool = false

    /// リスト表示用の1行サマリ。長文でも走査量を抑えるため先頭だけを見る。
    var summary: String {
        switch kind {
        case .text:
            let head = (text ?? "").prefix(ClipPreview.summaryScanLimit).drop(while: \.isNewline)
            let line = head.prefix(while: { !$0.isNewline })
            return line.isEmpty ? "（空白）" : String(line.prefix(ClipPreview.summaryLimit))
        case .image:
            return "画像"
        }
    }
}

/// プレビュー表示用のテキスト整形。長文をそのまま描画すると UI が固まるため、行数と文字数で打ち切る。
enum ClipPreview {
    /// プレビューに出す最大行数。
    static let maxLines = 30
    /// プレビューに出す最大文字数（1行が極端に長い場合の保険）。
    static let maxCharacters = 4_000
    /// 1行サマリの最大文字数。
    static let summaryLimit = 200
    /// 1行サマリを作るために走査する最大文字数。
    static let summaryScanLimit = 4_000

    /// 先頭から maxLines 行 / maxCharacters 文字までを返す。打ち切ったかどうかも返す。
    static func truncate(
        _ text: String,
        maxLines: Int = maxLines,
        maxCharacters: Int = maxCharacters
    ) -> (text: String, isTruncated: Bool) {
        var lines = 1
        var count = 0
        var index = text.startIndex
        while index < text.endIndex {
            if count >= maxCharacters { return (String(text[..<index]), true) }
            if text[index].isNewline {
                if lines >= maxLines { return (String(text[..<index]), true) }
                lines += 1
            }
            index = text.index(after: index)
            count += 1
        }
        return (text, false)
    }
}

// MARK: - スニペット

struct SnippetItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var order: Int
    let folderID: UUID?
}

struct SnippetFolderEntity: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var order: Int
    var snippets: [SnippetItem]
}

/// スニペットのタイトルを本文から導出する純粋ロジック。
enum SnippetTitle {
    static func derive(from content: String) -> String {
        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? content
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "無題" : String(trimmed.prefix(40))
    }
}

// MARK: - 設定 / ショートカット

/// グローバルショートカット1つ分の設定（仮想キーコード + 修飾キー）。
struct HotKeyConfig: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let historyDefault = HotKeyConfig(keyCode: KeyCodes.v, modifiers: KeyCodes.cmdShift)
    static let snippetDefault = HotKeyConfig(keyCode: KeyCodes.b, modifiers: KeyCodes.cmdShift)
    static let quickSnippetDefault = HotKeyConfig(keyCode: KeyCodes.s, modifiers: KeyCodes.cmdShift)
}

/// アプリ全体の設定（ドメイン値）。
struct AppPreferences: Equatable, Sendable {
    var historyLimit: Int = 50
    var autoPaste: Bool = true
    /// 貼り付け時に書式を落としてプレーンテキストにするか。true で常にプレーン（既定）。
    var pasteAsPlainText: Bool = true
    var pollInterval: Double = 0.5
    var launchAtLogin: Bool = false
    var historyHotKey: HotKeyConfig = .historyDefault
    var snippetHotKey: HotKeyConfig = .snippetDefault
    var quickSnippetHotKey: HotKeyConfig = .quickSnippetDefault
}

/// キーコード／修飾キーの定数と表示変換。
/// 値は Carbon の定数（cmdKey=0x100 等、kVK_ANSI_* の仮想キーコード）に一致するが、
/// Domain をフレームワーク非依存に保つためリテラルで保持する。
enum KeyCodes {
    static let cmd: UInt32 = 0x0100
    static let shift: UInt32 = 0x0200
    static let option: UInt32 = 0x0800
    static let control: UInt32 = 0x1000
    static let cmdShift = cmd | shift

    static let v: UInt32 = 9
    static let b: UInt32 = 11
    static let s: UInt32 = 1

    static let letterToCode: [String: UInt32] = [
        "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5, "H": 4, "I": 34,
        "J": 38, "K": 40, "L": 37, "M": 46, "N": 45, "O": 31, "P": 35, "Q": 12, "R": 15,
        "S": 1, "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
    ]

    static var letters: [String] { letterToCode.keys.sorted() }

    static func letter(for code: UInt32) -> String {
        letterToCode.first(where: { $0.value == code })?.key ?? "?"
    }

    static func description(_ c: HotKeyConfig) -> String {
        var s = ""
        if c.modifiers & control != 0 { s += "⌃" }
        if c.modifiers & option != 0 { s += "⌥" }
        if c.modifiers & shift != 0 { s += "⇧" }
        if c.modifiers & cmd != 0 { s += "⌘" }
        s += letter(for: c.keyCode)
        return s
    }
}
