import Foundation
import GRDB

// MARK: - Статус заказа

enum OrderStatus: String, CaseIterable, Codable, Identifiable, DatabaseValueConvertible {
    case new = "Новый"
    case preparing = "Готовится"
    case ready = "Готов к подаче"
    case served = "Подан"
    case closed = "Закрыт"
    case cancelled = "Отменён"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .new: return "sparkles"
        case .preparing: return "flame.fill"
        case .ready: return "bell.badge.fill"
        case .served: return "fork.knife"
        case .closed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.octagon.fill"
        }
    }

    var isActive: Bool {
        switch self {
        case .new, .preparing, .ready, .served:
            return true
        case .closed, .cancelled:
            return false
        }
    }
}

// MARK: - Способ оплаты

enum PaymentMethod: String, CaseIterable, Codable, Identifiable, DatabaseValueConvertible {
    case card = "Карта"
    case qr = "СБП / QR"
    case cash = "Наличные"
    case split = "Раздельный счёт"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .card: return "creditcard.fill"
        case .qr: return "qrcode"
        case .cash: return "banknote.fill"
        case .split: return "person.2.crop.square.stack.fill"
        }
    }
}

// MARK: - Модель заказа (СТРОГО struct для GRDB и SwiftUI)

struct Order: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "orders"

    var id: String
    var tableNumber: Int
    var guestCount: Int
    var guestName: String
    var status: OrderStatus
    var paymentMethod: PaymentMethod
    var notes: String
    var discountPercent: Double
    var tipPercent: Double
    var splitCount: Int
    var createdAt: Date
    var closedAt: Date?

    enum Columns: String, ColumnExpression {
        case id
        case tableNumber
        case guestCount
        case guestName
        case status
        case paymentMethod
        case notes
        case discountPercent
        case tipPercent
        case splitCount
        case createdAt
        case closedAt
    }

    init(
        id: String = UUID().uuidString,
        tableNumber: Int,
        guestCount: Int = 2,
        guestName: String = "",
        status: OrderStatus = .new,
        paymentMethod: PaymentMethod = .card,
        notes: String = "",
        discountPercent: Double = 0,
        tipPercent: Double = 10,
        splitCount: Int = 1,
        createdAt: Date = Date(),
        closedAt: Date? = nil
    ) {
        self.id = id
        self.tableNumber = tableNumber
        self.guestCount = max(1, guestCount)
        self.guestName = guestName
        self.status = status
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.discountPercent = discountPercent
        self.tipPercent = tipPercent
        self.splitCount = max(1, splitCount)
        self.createdAt = createdAt
        self.closedAt = closedAt
    }
}

// MARK: - Агрегированная структура заказа с позициями (СТРОГО struct)

struct OrderWithItems: Identifiable, Equatable, Hashable, Codable {
    var order: Order
    var items: [OrderItem]

    var id: String { order.id }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.subtotal }
    }

    var discountAmount: Double {
        subtotal * (order.discountPercent / 100.0)
    }

    var discountedTotal: Double {
        max(0, subtotal - discountAmount)
    }

    var tipAmount: Double {
        discountedTotal * (order.tipPercent / 100.0)
    }

    var total: Double {
        discountedTotal + tipAmount
    }

    var perGuestAmount: Double {
        let count = max(1, order.splitCount)
        return total / Double(count)
    }

    var totalQuantity: Int {
        items.reduce(0) { $0 + $1.quantity }
    }

    var servedQuantity: Int {
        items.filter(\.isServed).reduce(0) { $0 + $1.quantity }
    }
}
