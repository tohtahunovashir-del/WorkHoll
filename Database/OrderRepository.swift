import Foundation
import GRDB

final class OrderRepository {
    static let shared = OrderRepository()
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = DatabaseManager.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // Реактивное наблюдение за заказами и их позициями через GRDB ValueObservation
    func observeOrdersWithItems() -> ValueObservation<ValueReducers.Fetch<[OrderWithItems]>> {
        ValueObservation.tracking { db in
            let orders = try Order
                .order(Order.Columns.createdAt.desc)
                .fetchAll(db)
            let allItems = try OrderItem
                .order(OrderItem.Columns.course.asc, OrderItem.Columns.createdAt.asc)
                .fetchAll(db)
            let grouped = Dictionary(grouping: allItems, by: \.orderId)
            return orders.map { order in
                OrderWithItems(order: order, items: grouped[order.id] ?? [])
            }
        }
    }

    func fetchAllOrdersWithItems() throws -> [OrderWithItems] {
        try dbQueue.read { db in
            let orders = try Order
                .order(Order.Columns.createdAt.desc)
                .fetchAll(db)
            let allItems = try OrderItem
                .order(OrderItem.Columns.course.asc, OrderItem.Columns.createdAt.asc)
                .fetchAll(db)
            let grouped = Dictionary(grouping: allItems, by: \.orderId)
            return orders.map { order in
                OrderWithItems(order: order, items: grouped[order.id] ?? [])
            }
        }
    }

    func createOrder(_ order: Order, initialItems: [OrderItem] = []) throws {
        try dbQueue.write { db in
            try order.insert(db)
            for item in initialItems {
                try item.insert(db)
            }
        }
    }

    func updateOrder(_ order: Order) throws {
        try dbQueue.write { db in
            try order.update(db)
        }
    }

    func deleteOrder(id: String) throws {
        try dbQueue.write { db in
            _ = try Order.deleteOne(db, key: id)
        }
    }

    func addOrIncrementItem(
        orderId: String,
        menuItem: MenuItem,
        quantity: Int = 1,
        course: Int = 1,
        comment: String = ""
    ) throws {
        try dbQueue.write { db in
            let cleanComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            if var existing = try OrderItem
                .filter(OrderItem.Columns.orderId == orderId)
                .filter(OrderItem.Columns.menuItemId == menuItem.id)
                .filter(OrderItem.Columns.course == course)
                .filter(OrderItem.Columns.comment == cleanComment)
                .filter(OrderItem.Columns.isServed == false)
                .fetchOne(db) {
                existing.quantity += quantity
                try existing.update(db)
            } else {
                let newItem = OrderItem(
                    orderId: orderId,
                    menuItemId: menuItem.id,
                    menuItemName: menuItem.name,
                    unitPrice: menuItem.price,
                    quantity: max(1, quantity),
                    course: course,
                    comment: cleanComment
                )
                try newItem.insert(db)
            }
        }
    }

    func updateItemQuantity(itemId: String, quantity: Int) throws {
        try dbQueue.write { db in
            guard var item = try OrderItem.fetchOne(db, key: itemId) else { return }
            if quantity <= 0 {
                _ = try item.delete(db)
            } else {
                item.quantity = quantity
                try item.update(db)
            }
        }
    }

    func toggleItemServed(itemId: String) throws {
        try dbQueue.write { db in
            guard var item = try OrderItem.fetchOne(db, key: itemId) else { return }
            item.isServed.toggle()
            try item.update(db)
        }
    }

    func updateItemCourseAndComment(itemId: String, course: Int, comment: String) throws {
        try dbQueue.write { db in
            guard var item = try OrderItem.fetchOne(db, key: itemId) else { return }
            item.course = course
            item.comment = comment
            try item.update(db)
        }
    }

    func removeItem(itemId: String) throws {
        try dbQueue.write { db in
            _ = try OrderItem.deleteOne(db, key: itemId)
        }
    }
}
