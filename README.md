# clip-command

macOS のメニューバー常駐クリップボードマネージャ。コピー履歴とスニペットをホットキーで素早く呼び出し、前面アプリへワンクリック / キー操作で貼り付けます。

## 特長

- 📋 クリップボード履歴（テキスト / 画像）の自動記録
- ⌨️ グローバルホットキーで履歴・スニペットパネルを表示
- ⚡️ 選択項目を前面アプリへ自動貼り付け（⌘V 送出）
- 📝 スニペット登録・編集
- 🔢 ⌘1〜9 で素早く貼り付け、↑↓ で選択、ホバー / 選択で詳細プレビュー
- 🔄 Sparkle による自動アップデート

## 動作環境

- macOS 14.0 以降
- 自動貼り付けには「システム設定 > プライバシーとセキュリティ > アクセシビリティ」での許可が必要です。

## インストール

[Releases](https://github.com/maeda-niku18/clip-command/releases) から最新の `clip-command-x.y.z.dmg` をダウンロードし、`clip-command.app` を `Applications` へドラッグしてください。公証済みのため Gatekeeper の警告は出ません。

## 開発

XcodeGen でプロジェクトを生成します（`.xcodeproj` は生成物で Git 管理外）。

```sh
brew install xcodegen
xcodegen generate
open clip-command.xcodeproj
```

## リリース

```sh
./release.sh 1.0.0
```

Developer ID 署名 → DMG 作成 → 公証 → appcast 生成 → GitHub Release へアップロード、までを一括で行います。

## ライセンス

[MIT](LICENSE) © 2026 Satoshi Maeda
