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
    var isPinned: Bool = false

    /// リスト表示用の1行サマリ。
    var summary: String {
        switch kind {
        case .text:
            let line = (text ?? "")
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? (text ?? "")
            return line.isEmpty ? "（空白）" : line
        case .image:
            return "画像"
        }
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
