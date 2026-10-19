import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var ordersVM: OrdersViewModel
    @EnvironmentObject private var tableVM: TableMapViewModel

    @State private var showNewOrderSheet = false
    @State private var pathOrderId: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    segmentSelector

                    statusChipsBar

                    if ordersVM.filteredOrders.isEmpty {
                        EmptyStateCard(
                            icon: "list.clipboard",
                            title: ordersVM.showArchived ? "Архив заказов пуст" : "Нет активных заказов",
                            message: ordersVM.showArchived
                                ? "Закрытые и отменённые заказы за смену будут отображаться здесь."
                                : "Создайте новый заказ для любого стола, чтобы начать обслуживание.",
                            buttonTitle: ordersVM.showArchived ? nil : "Создать новый заказ"
                        ) {
                            showNewOrderSheet = true
                        }
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(ordersVM.filteredOrders) { detail in
                                NavigationLink(value: detail.order.id) {
                                    OrderCardView(detail: detail) { nextStatus in
                                        ordersVM.advanceStatus(detail.order, to: nextStatus)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: ordersVM.filteredOrders)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Заказы")
            .searchable(text: $ordersVM.searchText, prompt: "Поиск по столу, гостю или блюду")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.impact(.medium)
                        showNewOrderSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Новый")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .navigationDestination(for: String.self) { orderId in
                OrderDetailView(orderId: orderId)
            }
            .sheet(isPresented: $showNewOrderSheet) {
                NewOrderSheet(tables: tableVM.tables) { createdOrder in
                    ordersVM.selectedOrderId = createdOrder.id
                }
            }
        }
    }

    private var segmentSelector: some View {
        HStack(spacing: 10) {
            FilterChip(
                title: "В работе (\(ordersVM.activeOrdersCount))",
                icon: "flame.fill",
                isSelected: !ordersVM.showArchived
            ) {
                ordersVM.showArchived = false
                ordersVM.statusFilter = nil
            }

            FilterChip(
                title: "Закрытые / Архив",
                icon: "archivebox.fill",
                isSelected: ordersVM.showArchived
            ) {
                ordersVM.showArchived = true
                ordersVM.statusFilter = nil
            }
            Spacer()
        }
    }

    private var statusChipsBar: some View {
        let relevantStatuses: [OrderStatus] = ordersVM.showArchived
            ? [.closed, .cancelled]
            : [.new, .preparing, .ready, .served]

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все статусы",
                    isSelected: ordersVM.statusFilter == nil
                ) {
                    ordersVM.statusFilter = nil
                }

                ForEach(relevantStatuses) { status in
                    FilterChip(
                        title: status.rawValue,
                        icon: status.icon,
                        isSelected: ordersVM.statusFilter == status,
                        activeColor: AppTheme.statusColor(for: status)
                    ) {
                        ordersVM.statusFilter = status
                    }
                }
            }
        }
    }
}

// MARK: - Премиальная карточка заказа

struct OrderCardView: View {
    let detail: OrderWithItems
    let onStatusAction: (OrderStatus) -> Void

    private var statusColor: Color {
        AppTheme.statusColor(for: detail.order.status)
    }

    var body: some View {
        PremiumCard(padding: 16, borderColor: statusColor.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 46, height: 46)
                            Text("№\(detail.order.tableNumber)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(statusColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(detail.order.guestName.isEmpty ? "Стол №\(detail.order.tableNumber)" : detail.order.guestName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Гостей: \(detail.order.guestCount) • Открыт в \(detail.order.createdAt.shortRussianTime)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    StatusBadge(
                        text: detail.order.status.rawValue,
                        icon: detail.order.status.icon,
                        color: statusColor
                    )
                }

                if detail.items.isEmpty {
                    Text("Позиции ещё не добавлены — нажмите, чтобы наполнить заказ")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(detail.items.prefix(3)) { item in
                            HStack {
                                Image(systemName: item.isServed ? "checkmark.circle.fill" : "circle.dotted")
                                    .foregroundColor(item.isServed ? AppTheme.success : AppTheme.warning)
                                    .font(.system(size: 13))
                                Text("\(item.quantity)× \(item.menuItemName)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(item.subtotal.formattedCurrency)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if detail.items.count > 3 {
                            Text("+ ещё позиций: \(detail.items.count - 3)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                    .padding(10)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !detail.order.notes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.accent)
                        Text(detail.order.notes)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("К оплате (с чаевыми \(Int(detail.order.tipPercent))%)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(detail.total.formattedCurrency)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if let next = nextStep(for: detail.order.status) {
                        Button {
                            onStatusAction(next.status)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: next.icon)
                                Text(next.title)
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(next.color)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func nextStep(for status: OrderStatus) -> (status: OrderStatus, title: String, icon: String, color: Color)? {
        switch status {
        case .new:
            return (.preparing, "На кухню", "flame.fill", AppTheme.primary)
        case .preparing:
            return (.ready, "Готов", "bell.badge.fill", AppTheme.accent)
        case .ready:
            return (.served, "Подано", "fork.knife", AppTheme.success)
        case .served:
            return (.closed, "Закрыть счёт", "checkmark.seal.fill", AppTheme.primary)
        case .closed, .cancelled:
            return nil
        }
    }
}

// MARK: - Создание нового заказа

struct NewOrderSheet: View {
    @EnvironmentObject private var ordersVM: OrdersViewModel
    let tables: [Table]
    let onCreated: (Order) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTableNumber: Int = 1
    @State private var guestCount: Int = 2
    @State private var guestName: String = ""
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Выберите стол")
                                .font(.system(size: 16, weight: .bold))

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                                ForEach(tables) { table in
                                    Button {
                                        HapticManager.selection()
                                        selectedTableNumber = table.number
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("№\(table.number)")
                                                .font(.system(size: 16, weight: .bold))
                                            Text("\(table.seats) м.")
                                                .font(.system(size: 11))
                                        }
                                        .foregroundColor(selectedTableNumber == table.number ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .frame(minHeight: 54)
                                        .background(
                                            selectedTableNumber == table.number
                                                ? AppTheme.primary
                                                : Color.primary.opacity(0.06)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Stepper("Количество гостей: \(guestCount)", value: $guestCount, in: 1...20)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minHeight: 44)

                            TextField("Имя гостя или название компании", text: $guestName)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Комментарий к заказу (аллергии, пожелания)", text: $notes)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    PrimaryActionButton(
                        title: "Открыть заказ для стола №\(selectedTableNumber)",
                        icon: "checkmark.circle.fill",
                        color: AppTheme.primary
                    ) {
                        if let created = ordersVM.createOrder(
                            tableNumber: selectedTableNumber,
                            guestCount: guestCount,
                            guestName: guestName,
                            notes: notes
                        ) {
                            onCreated(created)
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Новый заказ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onAppear {
                if let firstFree = tables.first(where: { $0.status == .free }) {
                    selectedTableNumber = firstFree.number
                } else if let first = tables.first {
                    selectedTableNumber = first.number
                }
            }
        }
    }
}
