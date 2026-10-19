import Foundation

final class ExportService {
    static let shared = ExportService()

    private init() {}

    func formatReceipt(for detail: OrderWithItems) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"

        var lines: [String] = []
        lines.append("══════════════════════════════")
        lines.append("           WORKHOLL           ")
        lines.append("     Премиальный сервис       ")
        lines.append("══════════════════════════════")
        lines.append("Стол №\(detail.order.tableNumber) • Гостей: \(detail.order.guestCount)")
        if !detail.order.guestName.isEmpty {
            lines.append("Гость: \(detail.order.guestName)")
        }
        lines.append("Открыт: \(formatter.string(from: detail.order.createdAt))")
        lines.append("Статус: \(detail.order.status.rawValue)")
        lines.append("──────────────────────────────")

        for item in detail.items {
            let lineTotal = item.subtotal.formattedCurrency
            lines.append("\(item.menuItemName)")
            lines.append("  \(item.quantity) × \(item.unitPrice.formattedCurrency) = \(lineTotal)")
            if !item.comment.isEmpty {
                lines.append("  * \(item.comment)")
            }
        }

        lines.append("──────────────────────────────")
        lines.append("Подытог: \(detail.subtotal.formattedCurrency)")
        if detail.order.discountPercent > 0 {
            lines.append("Скидка (\(Int(detail.order.discountPercent))%): -\(detail.discountAmount.formattedCurrency)")
        }
        if detail.order.tipPercent > 0 {
            lines.append("Чаевые (\(Int(detail.order.tipPercent))%): +\(detail.tipAmount.formattedCurrency)")
        }
        lines.append("══════════════════════════════")
        lines.append("ИТОГО К ОПЛАТЕ: \(detail.total.formattedCurrency)")
        if detail.order.splitCount > 1 {
            lines.append("На гостя (\(detail.order.splitCount) чел.): \(detail.perGuestAmount.formattedCurrency)")
        }
        lines.append("Оплата: \(detail.order.paymentMethod.rawValue)")
        lines.append("══════════════════════════════")
        lines.append("Спасибо за визит! Ждём вас снова.")
        return lines.joined(separator: "\n")
    }

    func formatShiftReport(
        todayRevenue: Double,
        weekRevenue: Double,
        monthRevenue: Double,
        closedOrdersCount: Int,
        averageCheck: Double,
        totalTips: Double,
        topDishes: [(name: String, count: Int, revenue: Double)]
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd MMMM yyyy, HH:mm"

        var lines: [String] = []
        lines.append("ОТЧЁТ СМЕНЫ WORKHOLL")
        lines.append("Сформирован: \(formatter.string(from: Date()))")
        lines.append("──────────────────────────────")
        lines.append("Выручка за сегодня: \(todayRevenue.formattedCurrency)")
        lines.append("Выручка за 7 дней: \(weekRevenue.formattedCurrency)")
        lines.append("Выручка за 30 дней: \(monthRevenue.formattedCurrency)")
        lines.append("Закрытых заказов сегодня: \(closedOrdersCount)")
        lines.append("Средний чек: \(averageCheck.formattedCurrency)")
        lines.append("Чаевые за смену: \(totalTips.formattedCurrency)")
        lines.append("──────────────────────────────")
        lines.append("ТОП ПОЗИЦИЙ:")
        for (idx, dish) in topDishes.enumerated() {
            lines.append("\(idx + 1). \(dish.name) — \(dish.count) шт. (\(dish.revenue.formattedCurrency))")
        }
        return lines.joined(separator: "\n")
    }
}
