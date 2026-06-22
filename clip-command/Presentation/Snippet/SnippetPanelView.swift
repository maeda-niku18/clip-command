//
//  SnippetPanelView.swift
//  clip-command — Presentation 層 / スニペット
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import SwiftUI

/// スニペットパネル。フォルダごとにスニペットを並べ、選択で貼り付ける。
struct SnippetPanelView: View {
    @Bindable var viewModel: SnippetPanelViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("スニペットを検索…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { viewModel.activateSelected() }
            }
            .padding(10)
            Divider()
            listView
            Divider()
            HStack {
                Spacer()
                Button("スニペットを編集▸") { viewModel.openEditor() }
                    .buttonStyle(.borderless).font(.caption)
            }
            .padding(10)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .onAppear {
            searchFocused = true
            viewModel.onAppear()
        }
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.flat.enumerated()), id: \.element.id) { index, snippet in
                        if viewModel.isFirstInFolder(index) {
                            Text(viewModel.folderName(for: snippet.folderID))
                                .font(.caption).foregroundStyle(.secondary)
                                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        SnippetRow(snippet: snippet, isSelected: index == viewModel.selectedIndex)
                            .id(snippet.id)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.paste(snippet) }
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, new in
                if viewModel.flat.indices.contains(new) {
                    proxy.scrollTo(viewModel.flat[new].id, anchor: .center)
                }
            }
            .overlay {
                if viewModel.flat.isEmpty {
                    Text("スニペットがありません").foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct SnippetRow: View {
    let snippet: SnippetItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snippet.title).lineLimit(1)
            Text(snippet.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.20) : .clear)
    }
}
