import Foundation
import GRDB

final class MenuRepository {
    static let shared = MenuRepository()
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // Реактивное наблюдение за всеми позициями меню через GRDB ValueObservation
    func observeAll() -> ValueObservation<ValueReducers.Fetch<[MenuItem]>> {
        ValueObservation.tracking { db in
            try MenuItem
                .order(MenuItem.Columns.popularity.desc, MenuItem.Columns.name.asc)
                .fetchAll(db)
        }
    }

    func fetchAll() throws -> [MenuItem] {
        try dbQueue.read { db in
            try MenuItem
                .order(MenuItem.Columns.popularity.desc, MenuItem.Columns.name.asc)
                .fetchAll(db)
        }
    }

    func save(_ item: MenuItem) throws {
        try dbQueue.write { db in
            try item.save(db)
        }
    }

    func saveBatch(_ items: [MenuItem]) throws {
        try dbQueue.write { db in
            for item in items {
                try item.save(db)
            }
        }
    }

    func toggleAvailability(_ item: MenuItem) throws {
        try dbQueue.write { db in
            var updated = item
            updated.isAvailable.toggle()
            try updated.update(db)
        }
    }

    func toggleHit(_ item: MenuItem) throws {
        try dbQueue.write { db in
            var updated = item
            updated.isHit.toggle()
            try updated.update(db)
        }
    }

    func delete(_ item: MenuItem) throws {
        try dbQueue.write { db in
            _ = try item.delete(db)
        }
    }

    func incrementPopularity(itemIds: [String]) throws {
        try dbQueue.write { db in
            for id in itemIds {
                if var item = try MenuItem.fetchOne(db, key: id) {
                    item.popularity += 1
                    try item.update(db)
                }
            }
        }
    }
}
