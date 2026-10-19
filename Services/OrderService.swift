import Foundation

final class OrderService {
    static let shared = OrderService()

    private let orderRepository: OrderRepository
    private let tableRepository: TableRepository
    private let menuRepository: MenuRepository

    init(
        orderRepository: OrderRepository = .shared,
        tableRepository: TableRepository = .shared,
        menuRepository: MenuRepository = .shared
    ) {
        self.orderRepository = orderRepository
        self.tableRepository = tableRepository
        self.menuRepository = menuRepository
    }

    @discardableResult
    func createOrder(
        tableNumber: Int,
        guestCount: Int,
        guestName: String = "",
        notes: String = ""
    ) throws -> Order {
        let order = Order(
            tableNumber: tableNumber,
            guestCount: max(1, guestCount),
            guestName: guestName.trimmingCharacters(in: .whitespacesAndNewlines),
            status: .new,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try orderRepository.createOrder(order)
        try tableRepository.updateStatus(
            tableNumber: tableNumber,
            status: .occupied,
            guestCount: max(1, guestCount),
            note: notes.isEmpty ? nil : notes
        )
        return order
    }

    func addItem(
        to orderId: String,
        menuItem: MenuItem,
        quantity: Int = 1,
        course: Int = 1,
        comment: String = ""
    ) throws {
        try orderRepository.addOrIncrementItem(
            orderId: orderId,
            menuItem: menuItem,
            quantity: quantity,
            course: course,
            comment: comment
        )
    }

    func updateItemQuantity(itemId: String, quantity: Int) throws {
        try orderRepository.updateItemQuantity(itemId: itemId, quantity: quantity)
    }

    func toggleItemServed(itemId: String) throws {
        try orderRepository.toggleItemServed(itemId: itemId)
    }

    func removeItem(itemId: String) throws {
        try orderRepository.removeItem(itemId: itemId)
    }

    func updateOrderStatus(_ order: Order, newStatus: OrderStatus) throws {
        var updated = order
        updated.status = newStatus
        if newStatus == .closed || newStatus == .cancelled {
            updated.closedAt = Date()
        }
        try orderRepository.updateOrder(updated)

        // Синхронизируем статус стола
        switch newStatus {
        case .new, .preparing, .served:
            try tableRepository.updateStatus(tableNumber: order.tableNumber, status: .occupied)
        case .ready:
            try tableRepository.updateStatus(tableNumber: order.tableNumber, status: .waitingBill)
        case .closed, .cancelled:
            let allOrders = try orderRepository.fetchAllOrdersWithItems()
            let hasOtherActive = allOrders.contains {
                $0.order.id != order.id &&
                $0.order.tableNumber == order.tableNumber &&
                $0.order.status.isActive
            }
            if !hasOtherActive {
                try tableRepository.updateStatus(tableNumber: order.tableNumber, status: .free)
            }
            if newStatus == .closed,
               let closedFull = allOrders.first(where: { $0.order.id == order.id }) {
                let ids = closedFull.items.map(\.menuItemId)
                try menuRepository.incrementPopularity(itemIds: ids)
            }
        }
    }

    func updateOrderParameters(
        _ order: Order,
        guestCount: Int? = nil,
        guestName: String? = nil,
        notes: String? = nil,
        discountPercent: Double? = nil,
        tipPercent: Double? = nil,
        splitCount: Int? = nil,
        paymentMethod: PaymentMethod? = nil
    ) throws {
        var updated = order
        if let guestCount { updated.guestCount = max(1, guestCount) }
        if let guestName { updated.guestName = guestName }
        if let notes { updated.notes = notes }
        if let discountPercent { updated.discountPercent = min(100, max(0, discountPercent)) }
        if let tipPercent { updated.tipPercent = min(50, max(0, tipPercent)) }
        if let splitCount { updated.splitCount = max(1, splitCount) }
        if let paymentMethod { updated.paymentMethod = paymentMethod }
        try orderRepository.updateOrder(updated)
    }

    func deleteOrder(_ order: Order) throws {
        try orderRepository.deleteOrder(id: order.id)
    }
}
