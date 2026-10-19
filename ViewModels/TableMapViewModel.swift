import Foundation
import Combine
import GRDB

@MainActor
final class TableMapViewModel: ObservableObject {
    @Published private(set) var tables: [Table] = []
    @Published private(set) var activeOrdersByTable: [Int: OrderWithItems] = [:]
    @Published var selectedZone: HallZone? = nil
    @Published var selectedTable: Table? = nil
    @Published var errorMessage: String? = nil

    private let tableRepository: TableRepository
    private let orderRepository: OrderRepository
    private let orderService: OrderService
    private var tablesCancellable: AnyDatabaseCancellable?
    private var ordersCancellable: AnyDatabaseCancellable?

    init(
        tableRepository: TableRepository = .shared,
        orderRepository: OrderRepository = .shared,
        orderService: OrderService = .shared
    ) {
        self.tableRepository = tableRepository
        self.orderRepository = orderRepository
        self.orderService = orderService
        startReactiveObservations()
    }

    var filteredTables: [Table] {
        guard let zone = selectedZone else { return tables }
        return tables.filter { $0.zone == zone }
    }

    var occupiedCount: Int {
        tables.filter { $0.status == .occupied || $0.status == .waitingBill }.count
    }

    var freeCount: Int {
        tables.filter { $0.status == .free }.count
    }

    var totalGuestsInHall: Int {
        tables.reduce(0) { $0 + $1.guestCount }
    }

    private func startReactiveObservations() {
        tablesCancellable = tableRepository
            .observeAll()
            .start(
                in: DatabaseManager.shared.dbQueue,
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                },
                onChange: { [weak self] freshTables in
                    Task { @MainActor in
                        guard let self else { return }
                        self.tables = freshTables
                        if let current = self.selectedTable {
                            self.selectedTable = freshTables.first(where: { $0.id == current.id })
                        }
                    }
                }
            )

        ordersCancellable = orderRepository
            .observeOrdersWithItems()
            .start(
                in: DatabaseManager.shared.dbQueue,
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                },
                onChange: { [weak self] allOrders in
                    Task { @MainActor in
                        var mapping: [Int: OrderWithItems] = [:]
                        for entry in allOrders where entry.order.status.isActive {
                            if mapping[entry.order.tableNumber] == nil {
                                mapping[entry.order.tableNumber] = entry
                            }
                        }
                        self?.activeOrdersByTable = mapping
                    }
                }
            )
    }

    func updateTableStatus(
        table: Table,
        status: TableStatus,
        guestCount: Int,
        note: String
    ) {
        do {
            try tableRepository.updateStatus(
                tableNumber: table.number,
                status: status,
                guestCount: status == .free ? 0 : max(1, guestCount),
                note: note
            )
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }

    func createQuickOrder(
        for table: Table,
        guestCount: Int,
        guestName: String,
        notes: String
    ) -> Order? {
        do {
            let order = try orderService.createOrder(
                tableNumber: table.number,
                guestCount: guestCount,
                guestName: guestName,
                notes: notes
            )
            HapticManager.notification(.success)
            return order
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
            return nil
        }
    }

    func addNewTable(seats: Int, zone: HallZone) {
        let nextNumber = (tables.map(\.number).max() ?? 0) + 1
        let newTable = Table(number: nextNumber, seats: seats, zone: zone, status: .free)
        do {
            try tableRepository.save(newTable)
            HapticManager.impact(.medium)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
