//
//  SnippetEditorView.swift
//  clip-command — Presentation 層 / 編集
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import SwiftUI

/// アプリ内のスニペット編集ウィンドウ。フォルダ／スニペットの追加・編集・削除。
struct SnippetEditorView: View {
    @Bindable var viewModel: SnippetEditorViewModel

    var body: some View {
        NavigationSplitView {
            folderList
        } content: {
            snippetList
        } detail: {
            editor
        }
        .frame(minWidth: 720, minHeight: 420)
        .onAppear { viewModel.onAppear() }
    }

    private var folderList: some View {
        List(selection: $viewModel.selectedFolderID) {
            ForEach(viewModel.folders) { folder in
                Text(folder.name).tag(folder.id as UUID?)
            }
        }
        .navigationTitle("フォルダ")
        .toolbar {
            ToolbarItemGroup {
                Button { viewModel.createFolder() } label: { Image(systemName: "folder.badge.plus") }
                Button { viewModel.removeSelectedFolder() } label: { Image(systemName: "trash") }
                    .disabled(viewModel.selectedFolder == nil)
            }
        }
    }

    private var snippetList: some View {
        Group {
            if let folder = viewModel.selectedFolder {
                List(selection: $viewModel.selectedSnippetID) {
                    ForEach(folder.snippets) { snippet in
                        VStack(alignment: .leading) {
                            Text(snippet.title.isEmpty ? "（無題）" : snippet.title)
                            Text(snippet.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .tag(snippet.id as UUID?)
                    }
                }
                .toolbar {
                    ToolbarItemGroup {
                        Button { viewModel.createSnippet() } label: { Image(systemName: "plus") }
                        Button { viewModel.removeSelectedSnippet() } label: { Image(systemName: "trash") }
                            .disabled(viewModel.selectedSnippet == nil)
                    }
                }
            } else {
                Text("フォルダを選択").foregroundStyle(.secondary)
            }
        }
    }

    private var editor: some View {
        Group {
            if let snippet = viewModel.selectedSnippet {
                SnippetDetailEditor(viewModel: viewModel, snippet: snippet)
                    .id(snippet.id)
            } else {
                Text("スニペットを選択").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 1スニペットの編集フォーム。変更を都度 ViewModel 経由で保存する。
private struct SnippetDetailEditor: View {
    let viewModel: SnippetEditorViewModel
    let snippet: SnippetItem

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        Form {
            TextField("タイトル", text: $title)
                .onChange(of: title) { _, _ in save() }
            Section("本文") {
                TextEditor(text: $content)
                    .font(.body)
                    .frame(minHeight: 240)
                    .onChange(of: content) { _, _ in save() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { title = snippet.title; content = snippet.content }
    }

    private func save() {
        viewModel.updateSelected(title: title, content: content)
    }
}
