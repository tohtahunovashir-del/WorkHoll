import Foundation

final class MenuService {
    static let shared = MenuService()
    private let repository: MenuRepository

    init(repository: MenuRepository = .shared) {
        self.repository = repository
    }

    func saveMenuItem(_ item: MenuItem) throws {
        var cleaned = item
        cleaned.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.itemDescription = item.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned.weight = item.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        try repository.save(cleaned)
    }

    func importOCRItems(_ items: [MenuItem]) throws {
        guard !items.isEmpty else { return }
        let existing = try repository.fetchAll()
        let existingNames = Set(existing.map { $0.name.lowercased() })

        let newItems = items.filter { !existingNames.contains($0.name.lowercased()) }
        if !newItems.isEmpty {
            try repository.saveBatch(newItems)
        }
    }

    func toggleAvailability(_ item: MenuItem) throws {
        try repository.toggleAvailability(item)
    }

    func toggleHit(_ item: MenuItem) throws {
        try repository.toggleHit(item)
    }

    func deleteMenuItem(_ item: MenuItem) throws {
        try repository.delete(item)
    }
}
