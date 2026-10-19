import Foundation
import GRDB

// MARK: - Позиция заказа (СТРОГО struct для GRDB и SwiftUI)

struct OrderItem: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "orderItems"

    var id: String
    var orderId: String
    var menuItemId: String
    var menuItemName: String
    var unitPrice: Double
    var quantity: Int
    var course: Int
    var comment: String
    var isServed: Bool
    var createdAt: Date

    enum Columns: String, ColumnExpression {
        case id
        case orderId
        case menuItemId
        case menuItemName
        case unitPrice
        case quantity
        case course
        case comment
        case isServed
        case createdAt
    }

    init(
        id: String = UUID().uuidString,
        orderId: String,
        menuItemId: String,
        menuItemName: String,
        unitPrice: Double,
        quantity: Int = 1,
        course: Int = 1,
        comment: String = "",
        isServed: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.orderId = orderId
        self.menuItemId = menuItemId
        self.menuItemName = menuItemName
        self.unitPrice = unitPrice
        self.quantity = quantity
        self.course = course
        self.comment = comment
        self.isServed = isServed
        self.createdAt = createdAt
    }

    var subtotal: Double {
        unitPrice * Double(quantity)
    }
}
