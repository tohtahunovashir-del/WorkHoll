import Foundation
import Combine
import GRDB

struct TopDishMetric: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let count: Int
    let revenue: Double
}

struct PaymentBreakdownMetric: Identifiable, Equatable {
    var id: String { method.rawValue }
    let method: PaymentMethod
    let count: Int
    let amount: Double
}

@MainActor
final class StatsViewModel: ObservableObject {
    @Published private(set) var todayRevenue: Double = 0
    @Published private(set) var weekRevenue: Double = 0
    @Published private(set) var monthRevenue: Double = 0
    @Published private(set) var activePipelineAmount: Double = 0
    @Published private(set) var todayClosedCount: Int = 0
    @Published private(set) var averageCheck: Double = 0
    @Published private(set) var todayTips: Double = 0
    @Published private(set) var topDishes: [TopDishMetric] = []
    @Published private(set) var paymentBreakdown: [PaymentBreakdownMetric] = []

    private let orderRepository: OrderRepository
    private let exportService: ExportService
    private var ordersCancellable: AnyDatabaseCancellable?

    init(
        orderRepository: OrderRepository = .shared,
        exportService: ExportService = .shared
    ) {
        self.orderRepository = orderRepository
        self.exportService = exportService
        startReactiveObservation()
    }

    private func startReactiveObservation() {
        ordersCancellable = orderRepository
            .observeOrdersWithItems()
            .start(
                in: DatabaseManager.shared.dbQueue,
                onError: { _ in },
                onChange: { [weak self] allOrders in
                    Task { @MainActor in
                        self?.recomputeMetrics(from: allOrders)
                    }
                }
            )
    }

    private func recomputeMetrics(from allOrders: [OrderWithItems]) {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfDay) ?? startOfDay
        let startOfMonth = calendar.date(byAdding: .day, value: -30, to: startOfDay) ?? startOfDay

        let closedOrders = allOrders.filter { $0.order.status == .closed }
        let activeOrders = allOrders.filter { $0.order.status.isActive }

        let todayClosed = closedOrders.filter { ($0.order.closedAt ?? $0.order.createdAt) >= startOfDay }
        let weekClosed = closedOrders.filter { ($0.order.closedAt ?? $0.order.createdAt) >= startOfWeek }
        let monthClosed = closedOrders.filter { ($0.order.closedAt ?? $0.order.createdAt) >= startOfMonth }

        todayRevenue = todayClosed.reduce(0) { $0 + $1.total }
        weekRevenue = weekClosed.reduce(0) { $0 + $1.total }
        monthRevenue = monthClosed.reduce(0) { $0 + $1.total }
        activePipelineAmount = activeOrders.reduce(0) { $0 + $1.total }

        todayClosedCount = todayClosed.count
        averageCheck = todayClosed.isEmpty ? 0 : (todayRevenue / Double(todayClosed.count))
        todayTips = todayClosed.reduce(0) { $0 + $1.tipAmount }

        // Считаем популярные позиции по всем не отменённым заказам
        var dishStats: [String: (count: Int, revenue: Double)] = [:]
        for detail in allOrders where detail.order.status != .cancelled {
            for item in detail.items {
                let current = dishStats[item.menuItemName] ?? (0, 0)
                dishStats[item.menuItemName] = (
                    current.count + item.quantity,
                    current.revenue + item.subtotal
                )
            }
        }
        var mappedDishes: [TopDishMetric] = []
        for (dishName, stat) in dishStats {
            mappedDishes.append(TopDishMetric(name: dishName, count: stat.count, revenue: stat.revenue))
        }
        mappedDishes.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.revenue > rhs.revenue
            }
            return lhs.count > rhs.count
        }
        topDishes = Array(mappedDishes.prefix(6))

        // Разбивка по способам оплаты
        var paymentStats: [PaymentMethod: (count: Int, amount: Double)] = [:]
        for detail in closedOrders {
            let current = paymentStats[detail.order.paymentMethod] ?? (0, 0)
            paymentStats[detail.order.paymentMethod] = (
                current.count + 1,
                current.amount + detail.total
            )
        }
        paymentBreakdown = PaymentMethod.allCases.map { method in
            let entry = paymentStats[method] ?? (0, 0)
            return PaymentBreakdownMetric(method: method, count: entry.count, amount: entry.amount)
        }
    }

    func generateShiftReportText() -> String {
        exportService.formatShiftReport(
            todayRevenue: todayRevenue,
            weekRevenue: weekRevenue,
            monthRevenue: monthRevenue,
            closedOrdersCount: todayClosedCount,
            averageCheck: averageCheck,
            totalTips: todayTips,
            topDishes: topDishes.map { ($0.name, $0.count, $0.revenue) }
        )
    }
}
