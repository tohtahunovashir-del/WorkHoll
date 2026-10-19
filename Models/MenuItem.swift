import Foundation
import GRDB

// MARK: - Категория меню

enum MenuCategory: String, CaseIterable, Codable, Identifiable, DatabaseValueConvertible {
    case appetizers = "Закуски"
    case salads = "Салаты"
    case soups = "Супы"
    case mains = "Горячее"
    case sides = "Гарниры"
    case drinks = "Напитки"
    case desserts = "Десерты"
    case other = "Прочее"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appetizers: return "sparkles"
        case .salads: return "leaf.fill"
        case .soups: return "flame.circle.fill"
        case .mains: return "flame.fill"
        case .sides: return "takeoutbag.and.cup.and.straw.fill"
        case .drinks: return "cup.and.saucer.fill"
        case .desserts: return "birthday.cake.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - Модель позиции меню (СТРОГО struct для GRDB и SwiftUI)

struct MenuItem: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "menuItems"

    var id: String
    var name: String
    var itemDescription: String
    var price: Double
    var weight: String
    var category: MenuCategory
    var isAvailable: Bool
    var isHit: Bool
    var isNewItem: Bool
    var popularity: Int
    var createdAt: Date

    enum Columns: String, ColumnExpression {
        case id
        case name
        case itemDescription
        case price
        case weight
        case category
        case isAvailable
        case isHit
        case isNewItem
        case popularity
        case createdAt
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        itemDescription: String = "",
        price: Double,
        weight: String = "",
        category: MenuCategory = .other,
        isAvailable: Bool = true,
        isHit: Bool = false,
        isNewItem: Bool = false,
        popularity: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.price = price
        self.weight = weight
        self.category = category
        self.isAvailable = isAvailable
        self.isHit = isHit
        self.isNewItem = isNewItem
        self.popularity = popularity
        self.createdAt = createdAt
    }
}
