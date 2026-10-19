import SwiftUI

enum AppConstants {
    static let appTitle = "WorkHoll"
    static let appSubtitle = "Премиальный терминал официанта"
    static let minimumTouchTarget: CGFloat = 48
    static let cardCornerRadius: CGFloat = 20
    static let buttonCornerRadius: CGFloat = 16
    static let defaultTipOptions: [Double] = [0, 5, 10, 15, 20]
    static let defaultDiscountOptions: [Double] = [0, 5, 10, 15, 20]
}

enum AppTheme {
    static let primary = Color(red: 0.14, green: 0.36, blue: 0.92)
    static let accent = Color(red: 0.88, green: 0.45, blue: 0.12)
    static let success = Color(red: 0.13, green: 0.68, blue: 0.38)
    static let warning = Color(red: 0.94, green: 0.62, blue: 0.11)
    static let danger = Color(red: 0.89, green: 0.24, blue: 0.24)
    static let vipPurple = Color(red: 0.48, green: 0.27, blue: 0.88)

    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let screenBackground = Color(UIColor.systemGroupedBackground)
    static let subtleBorder = Color.primary.opacity(0.08)

    static func statusColor(for tableStatus: TableStatus) -> Color {
        switch tableStatus {
        case .free: return success
        case .occupied: return primary
        case .waitingBill: return warning
        case .reserved: return vipPurple
        }
    }

    static func statusColor(for orderStatus: OrderStatus) -> Color {
        switch orderStatus {
        case .new: return primary
        case .preparing: return warning
        case .ready: return accent
        case .served: return success
        case .closed: return Color.secondary
        case .cancelled: return danger
        }
    }
}
