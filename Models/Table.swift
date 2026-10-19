import Foundation
import GRDB

// MARK: - Зона зала

enum HallZone: String, CaseIterable, Codable, Identifiable, DatabaseValueConvertible {
    case main = "Основной зал"
    case terrace = "Терраса"
    case vip = "VIP-зал"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .main: return "building.columns.fill"
        case .terrace: return "sun.max.fill"
        case .vip: return "crown.fill"
        }
    }
}

// MARK: - Статус стола

enum TableStatus: String, CaseIterable, Codable, Identifiable, DatabaseValueConvertible {
    case free = "Свободен"
    case occupied = "Занят"
    case waitingBill = "Ожидает счёт"
    case reserved = "Бронь"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .free: return "checkmark.circle.fill"
        case .occupied: return "person.2.fill"
        case .waitingBill: return "creditcard.fill"
        case .reserved: return "clock.badge.checkmark.fill"
        }
    }
}

// MARK: - Модель стола (СТРОГО struct для GRDB и SwiftUI)

struct Table: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tables"

    var id: String
    var number: Int
    var seats: Int
    var zone: HallZone
    var status: TableStatus
    var guestCount: Int
    var occupiedSince: Date?
    var waiterNote: String

    enum Columns: String, ColumnExpression {
        case id
        case number
        case seats
        case zone
        case status
        case guestCount
        case occupiedSince
        case waiterNote
    }

    init(
        id: String = UUID().uuidString,
        number: Int,
        seats: Int = 4,
        zone: HallZone = .main,
        status: TableStatus = .free,
        guestCount: Int = 0,
        occupiedSince: Date? = nil,
        waiterNote: String = ""
    ) {
        self.id = id
        self.number = number
        self.seats = seats
        self.zone = zone
        self.status = status
        self.guestCount = guestCount
        self.occupiedSince = occupiedSince
        self.waiterNote = waiterNote
    }

    var elapsedMinutes: Int {
        guard let since = occupiedSince, status != .free else { return 0 }
        return max(0, Int(Date().timeIntervalSince(since) / 60))
    }
}
