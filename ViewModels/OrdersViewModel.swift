import Foundation
import Combine
import GRDB

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published private(set) var allOrders: [OrderWithItems] = []
    @Published var selectedOrderId: String? = nil
    @Published var statusFilter: OrderStatus? = nil
    @Published var showArchived: Bool = false
    @Published var searchText: String = ""
    @Published var errorMessage: String? = nil

    private let orderRepository: OrderRepository
    private let orderService: OrderService
    private var ordersCancellable: AnyDatabaseCancellable?

    init(
        orderRepository: OrderRepository = .shared,
        orderService: OrderService = .shared
    ) {
        self.orderRepository = orderRepository
        self.orderService = orderService
        startReactiveObservation()
    }

    var filteredOrders: [OrderWithItems] {
        allOrders.filter { detail in
            let matchesArchive = showArchived ? !detail.order.status.isActive : detail.order.status.isActive
            guard matchesArchive else { return false }

            if let statusFilter, detail.order.status != statusFilter {
                return false
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }

            let tableMatch = "стол \(detail.order.tableNumber)".contains(query) || "\(detail.order.tableNumber)" == query
            let guestMatch = detail.order.guestName.lowercased().contains(query)
            let itemMatch = detail.items.contains { $0.menuItemName.lowercased().contains(query) }
            return tableMatch || guestMatch || itemMatch
        }
    }

    var selectedOrderDetail: OrderWithItems? {
        guard let id = selectedOrderId else { return nil }
        return allOrders.first(where: { $0.id == id })
    }

    var activeOrdersCount: Int {
        allOrders.filter { $0.order.status.isActive }.count
    }

    private func startReactiveObservation() {
        ordersCancellable = orderRepository
            .observeOrdersWithItems()
            .start(
                in: DatabaseManager.shared.dbQueue,
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                },
                onChange: { [weak self] freshOrders in
                    Task { @MainActor in
                        self?.allOrders = freshOrders
                    }
                }
            )
    }

    @discardableResult
    func createOrder(
        tableNumber: Int,
        guestCount: Int,
        guestName: String,
        notes: String
    ) -> Order? {
        do {
            let created = try orderService.createOrder(
                tableNumber: tableNumber,
                guestCount: guestCount,
                guestName: guestName,
                notes: notes
            )
            selectedOrderId = created.id
            HapticManager.notification(.success)
            return created
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return nil
        }
    }

    func addItem(
        to orderId: String,
        menuItem: MenuItem,
        quantity: Int = 1,
        course: Int = 1,
        comment: String = ""
    ) {
        do {
            try orderService.addItem(
                to: orderId,
                menuItem: menuItem,
                quantity: quantity,
                course: course,
                comment: comment
            )
            HapticManager.impact(.medium)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateQuantity(item: OrderItem, quantity: Int) {
        do {
            try orderService.updateItemQuantity(itemId: item.id, quantity: quantity)
            HapticManager.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleServed(item: OrderItem) {
        do {
            try orderService.toggleItemServed(itemId: item.id)
            HapticManager.impact(.light)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeItem(item: OrderItem) {
        do {
            try orderService.removeItem(itemId: item.id)
            HapticManager.impact(.rigid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func advanceStatus(_ order: Order, to newStatus: OrderStatus) {
        do {
            try orderService.updateOrderStatus(order, newStatus: newStatus)
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }

    func updateBillingParameters(
        order: Order,
        discountPercent: Double? = nil,
        tipPercent: Double? = nil,
        splitCount: Int? = nil,
        paymentMethod: PaymentMethod? = nil,
        notes: String? = nil
    ) {
        do {
            try orderService.updateOrderParameters(
                order,
                notes: notes,
                discountPercent: discountPercent,
                tipPercent: tipPercent,
                splitCount: splitCount,
                paymentMethod: paymentMethod
            )
            HapticManager.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteOrder(_ order: Order) {
        do {
            try orderService.deleteOrder(order)
            if selectedOrderId == order.id {
                selectedOrderId = nil
            }
            HapticManager.notification(.warning)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
