import Foundation
import GRDB

final class TableRepository {
    static let shared = TableRepository()
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // Реактивное наблюдение за столами зала через GRDB ValueObservation
    func observeAll() -> ValueObservation<ValueReducers.Fetch<[Table]>> {
        ValueObservation.tracking { db in
            try Table
                .order(Table.Columns.number.asc)
                .fetchAll(db)
        }
    }

    func fetchAll() throws -> [Table] {
        try dbQueue.read { db in
            try Table
                .order(Table.Columns.number.asc)
                .fetchAll(db)
        }
    }

    func save(_ table: Table) throws {
        try dbQueue.write { db in
            try table.save(db)
        }
    }

    func updateStatus(
        tableNumber: Int,
        status: TableStatus,
        guestCount: Int? = nil,
        note: String? = nil
    ) throws {
        try dbQueue.write { db in
            guard var table = try Table
                .filter(Table.Columns.number == tableNumber)
                .fetchOne(db) else { return }

            table.status = status
            if let guestCount {
                table.guestCount = guestCount
            }
            if let note {
                table.waiterNote = note
            }
            switch status {
            case .free:
                table.guestCount = 0
                table.occupiedSince = nil
                table.waiterNote = ""
            case .occupied:
                if table.occupiedSince == nil {
                    table.occupiedSince = Date()
                }
            case .waitingBill, .reserved:
                if table.occupiedSince == nil {
                    table.occupiedSince = Date()
                }
            }
            try table.update(db)
        }
    }

    func delete(_ table: Table) throws {
        try dbQueue.write { db in
            _ = try table.delete(db)
        }
    }
}
