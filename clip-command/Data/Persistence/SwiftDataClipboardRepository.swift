//
//  SwiftDataClipboardRepository.swift
//  clip-command — Data 層 / 永続化
//  Copyright © 2026 Satoshi Maeda. All rights reserved.
//

import Foundation
import SwiftData

/// ClipboardRepository の SwiftData 実装。画像実体は ImageRepository に委譲する。
@MainActor
final class SwiftDataClipboardRepository: ClipboardRepository {
    private let context: ModelContext
    private let images: ImageRepository

    init(context: ModelContext, images: ImageRepository) {
        self.context = context
        self.images = images
    }

    func fetchAll() -> [ClipEntry] {
        fetchModels().map { $0.toEntity() }
    }

    func addText(_ text: String) {
        context.insert(ClipItemModel(kind: .text, text: text))
        save()
    }

    @discardableResult
    func addImage(data: Data) -> ClipEntry? {
        guard let ref = images.save(data: data) else { return nil }
        let model = ClipItemModel(kind: .image, imageFileName: ref)
        context.insert(model)
        save()
        return model.toEntity()
    }

    func touch(id: UUID) {
        guard let model = model(for: id) else { return }
        model.createdAt = .now
        save()
    }

    func setPinned(id: UUID, pinned: Bool) {
        guard let model = model(for: id) else { return }
        model.pinned = pinned
        save()
    }

    func delete(id: UUID) {
        guard let model = model(for: id) else { return }
        images.delete(ref: model.imageFileName)
        context.delete(model)
        save()
    }

    func deleteAll() {
        for model in fetchModels() {
            images.delete(ref: model.imageFileName)
            context.delete(model)
        }
        save()
    }

    func trim(to limit: Int) {
        // ピン留め項目は対象外。非ピンの最新 limit 件を残し、それより古いものを削除。
        let nonPinned = fetchModels().filter { !$0.pinned }
        guard nonPinned.count > limit else { return }
        for model in nonPinned[limit...] {
            images.delete(ref: model.imageFileName)
            context.delete(model)
        }
        save()
    }

    // MARK: - 補助

    /// ピン留めを先頭に、その中で新しい順。
    /// （SortDescriptor は Bool キーパスを扱えないため、取得後に Swift 側で整列する）
    private func fetchModels() -> [ClipItemModel] {
        let descriptor = FetchDescriptor<ClipItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.createdAt > b.createdAt
        }
    }

    private func model(for id: UUID) -> ClipItemModel? {
        let descriptor = FetchDescriptor<ClipItemModel>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private func save() {
        try? context.save()
    }
}
