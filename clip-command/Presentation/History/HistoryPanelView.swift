//
//  HistoryPanelView.swift
//  clip-command — Presentation 層 / 履歴
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import SwiftUI

/// 履歴パネル。検索・コンパクトリスト・hover ワイドプレビュー・下部スニペット登録バー。
struct HistoryPanelView: View {
    @Bindable var viewModel: HistoryViewModel
    @FocusState private var focus: HistoryViewModel.Field?

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            listView
            Divider()
            snippetBar
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
        .onChange(of: focus) { _, new in viewModel.focusedField = new ?? .search }
        .onAppear {
            focus = .search
            viewModel.onAppear()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("検索…", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .focused($focus, equals: .search)
        }
        .padding(10)
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, entry in
                        HistoryRow(
                            entry: entry,
                            index: index,
                            isSelected: index == viewModel.selectedIndex,
                            isHovered: viewModel.hoveredID == entry.id,
                            thumbnail: entry.kind == .image ? viewModel.image(for: entry) : nil
                        )
                        .id(entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.paste(entry) }
                        .onHover { hovering in
                            if hovering {
                                viewModel.hoveredID = entry.id
                                viewModel.previewID = entry.id // 後勝ち：ホバーが最後の操作
                            } else if viewModel.hoveredID == entry.id {
                                viewModel.hoveredID = nil
                                viewModel.previewID = viewModel.selectedEntryID // ホバーを離れたら選択側へ戻す
                            }
                        }
                        .popover(isPresented: previewBinding(entry.id), arrowEdge: .trailing) {
                            ClipPreviewView(
                                entry: entry,
                                image: entry.kind == .image ? viewModel.image(for: entry) : nil,
                                metadata: viewModel.metadata(for: entry)
                            )
                        }
                        .contextMenu {
                            Button(entry.isPinned ? "ピン留めを解除" : "ピン留め") { viewModel.togglePin(entry) }
                            Button("削除", role: .destructive) { viewModel.delete(entry) }
                        }
                    }
                }
            }
            .onChange(of: viewModel.selectedIndex) { _, new in
                if viewModel.results.indices.contains(new) {
                    proxy.scrollTo(viewModel.results[new].id, anchor: .center)
                }
            }
            .overlay {
                if viewModel.results.isEmpty {
                    Text(viewModel.searchText.isEmpty ? "履歴がありません" : "一致なし")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var snippetBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "square.and.pencil").foregroundStyle(.secondary)
            TextField("ここに入力してスニペット登録…", text: $viewModel.snippetDraft)
                .textFieldStyle(.plain)
                .focused($focus, equals: .snippet)
            if viewModel.selectedIsText {
                Button("選択中から") { viewModel.fillDraftFromSelected() }
                    .buttonStyle(.borderless).font(.caption)
            }
            Button("詳細▸") { viewModel.openEditor() }
                .buttonStyle(.borderless).font(.caption)
        }
        .padding(10)
    }

    /// previewID に一致する行だけ popover を出すための束縛。後勝ちで常に1つだけ表示される。
    private func previewBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { viewModel.previewID == id },
            set: { newValue in if !newValue, viewModel.previewID == id { viewModel.previewID = nil } }
        )
    }
}

/// 履歴の1行（コンパクト表示）。
struct HistoryRow: View {
    let entry: ClipEntry
    let index: Int
    let isSelected: Bool
    let isHovered: Bool
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(entry.summary).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2).foregroundStyle(.orange)
            }
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(rowBackground)
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.20) }
        if isHovered { return Color.accentColor.opacity(0.10) }
        return .clear
    }

    @ViewBuilder private var icon: some View {
        switch entry.kind {
        case .text:
            Image(systemName: "text.alignleft").foregroundStyle(.secondary)
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFill()
                    .frame(width: 18, height: 18).clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
    }
}

/// hover 時に横へポップするワイドプレビュー。
struct ClipPreviewView: View {
    let entry: ClipEntry
    let image: NSImage?
    let metadata: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
            Divider()
            Text(metadata).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 360)
    }

    @ViewBuilder private var content: some View {
        switch entry.kind {
        case .text:
            ScrollView {
                Text(entry.text ?? "")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)
        case .image:
            if let image {
                Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 280)
            } else {
                Text("画像を読み込めません").foregroundStyle(.secondary)
            }
        }
    }
}
