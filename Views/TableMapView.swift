import SwiftUI

struct TableMapView: View {
    @EnvironmentObject private var tableVM: TableMapViewModel
    @EnvironmentObject private var ordersVM: OrdersViewModel
    @Binding var selectedTab: Int

    @State private var showTableSheet = false
    @State private var showAddTableSheet = false
    @State private var showActiveOrderDetail = false
    @State private var activeOrderIdToOpen: String? = nil

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hallSummaryHeader

                    zoneFilterBar

                    LazyVGrid(columns: gridColumns, spacing: 14) {
                        ForEach(tableVM.filteredTables) { table in
                            TableCardView(
                                table: table,
                                activeOrder: tableVM.activeOrdersByTable[table.number]
                            ) {
                                HapticManager.impact(.medium)
                                tableVM.selectedTable = table
                                showTableSheet = true
                            } onOpenOrder: { orderDetail in
                                HapticManager.impact(.medium)
                                activeOrderIdToOpen = orderDetail.order.id
                                showActiveOrderDetail = true
                            }
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tableVM.filteredTables)
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Карта зала")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.impact(.light)
                        showAddTableSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Стол")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .sheet(isPresented: $showTableSheet) {
                if let selected = tableVM.selectedTable {
                    TableDetailSheet(
                        table: selected,
                        activeOrder: tableVM.activeOrdersByTable[selected.number]
                    ) { createdOrderId in
                        ordersVM.selectedOrderId = createdOrderId
                        selectedTab = 1
                    }
                }
            }
            .sheet(isPresented: $showAddTableSheet) {
                AddTableSheet()
            }
            .navigationDestination(isPresented: $showActiveOrderDetail) {
                if let orderId = activeOrderIdToOpen {
                    OrderDetailView(orderId: orderId)
                }
            }
        }
    }

    private var hallSummaryHeader: some View {
        HStack(spacing: 12) {
            MetricSummaryCard(
                title: "Свободно",
                value: "\(tableVM.freeCount)",
                subtitle: "Готовы к посадке",
                icon: "checkmark.circle.fill",
                tint: AppTheme.success
            )
            MetricSummaryCard(
                title: "Занято",
                value: "\(tableVM.occupiedCount)",
                subtitle: "Активные столы",
                icon: "person.2.fill",
                tint: AppTheme.primary
            )
            MetricSummaryCard(
                title: "Гостей",
                value: "\(tableVM.totalGuestsInHall)",
                subtitle: "Сейчас в зале",
                icon: "sparkles",
                tint: AppTheme.accent
            )
        }
    }

    private var zoneFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(
                    title: "Весь зал (\(tableVM.tables.count))",
                    icon: "square.grid.2x2.fill",
                    isSelected: tableVM.selectedZone == nil
                ) {
                    tableVM.selectedZone = nil
                }

                ForEach(HallZone.allCases) { zone in
                    FilterChip(
                        title: zone.rawValue,
                        icon: zone.icon,
                        isSelected: tableVM.selectedZone == zone
                    ) {
                        tableVM.selectedZone = zone
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Карточка стола на карте зала

struct TableCardView: View {
    let table: Table
    let activeOrder: OrderWithItems?
    let onTap: () -> Void
    let onOpenOrder: (OrderWithItems) -> Void

    private var statusColor: Color {
        AppTheme.statusColor(for: table.status)
    }

    var body: some View {
        PremiumCard(padding: 16, borderColor: statusColor.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Стол №\(table.number)")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                        Text("\(table.zone.rawValue) • \(table.seats) мест")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(statusColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: statusColor.opacity(0.6), radius: 5)
                }

                StatusBadge(
                    text: table.status.rawValue,
                    icon: table.status.icon,
                    color: statusColor
                )

                if let activeOrder {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Счёт:")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(activeOrder.total.formattedCurrency)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.primary)
                        }
                        Text("Позиций: \(activeOrder.totalQuantity) • \(table.elapsedMinutes) мин")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(AppTheme.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if !table.waiterNote.isEmpty {
                    Text(table.waiterNote)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text(table.status == .free ? "Нажмите для посадки гостей" : "Активен • \(table.elapsedMinutes) мин")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        onTap()
                    } label: {
                        Text("Статус")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let activeOrder {
                        Button {
                            onOpenOrder(activeOrder)
                        } label: {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Модальное окно управления столом и быстрой посадки

struct TableDetailSheet: View {
    @EnvironmentObject private var tableVM: TableMapViewModel
    let table: Table
    let activeOrder: OrderWithItems?
    let onOrderCreated: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: TableStatus
    @State private var guestCount: Int
    @State private var guestName: String = ""
    @State private var note: String

    init(
        table: Table,
        activeOrder: OrderWithItems?,
        onOrderCreated: @escaping (String) -> Void
    ) {
        self.table = table
        self.activeOrder = activeOrder
        self.onOrderCreated = onOrderCreated
        _selectedStatus = State(initialValue: table.status)
        _guestCount = State(initialValue: max(2, table.guestCount > 0 ? table.guestCount : 2))
        _note = State(initialValue: table.waiterNote)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Стол №\(table.number)")
                                    .font(.system(size: 22, weight: .bold))
                                Spacer()
                                StatusBadge(
                                    text: table.zone.rawValue,
                                    icon: table.zone.icon,
                                    color: AppTheme.primary
                                )
                            }

                            Text("Выберите статус стола")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            ForEach(TableStatus.allCases) { status in
                                Button {
                                    HapticManager.selection()
                                    selectedStatus = status
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: status.icon)
                                            .foregroundColor(AppTheme.statusColor(for: status))
                                            .frame(width: 24)
                                        Text(status.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedStatus == status {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppTheme.primary)
                                                .font(.title3)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 48)
                                    .background(
                                        selectedStatus == status
                                            ? AppTheme.primary.opacity(0.1)
                                            : Color.primary.opacity(0.04)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Stepper("Количество гостей: \(guestCount)", value: $guestCount, in: 1...20)
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minHeight: 44)

                            TextField("Имя гостя или комментарий к броне", text: $guestName)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            TextField("Заметка официанта (например, у окна)", text: $note)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    VStack(spacing: 12) {
                        PrimaryActionButton(
                            title: "Сохранить статус стола",
                            icon: "checkmark.circle.fill",
                            color: AppTheme.primary
                        ) {
                            tableVM.updateTableStatus(
                                table: table,
                                status: selectedStatus,
                                guestCount: guestCount,
                                note: note
                            )
                            dismiss()
                        }

                        if activeOrder == nil {
                            PrimaryActionButton(
                                title: "Посадить гостей и открыть заказ",
                                icon: "plus.rectangle.on.rectangle.fill",
                                color: AppTheme.success
                            ) {
                                if let created = tableVM.createQuickOrder(
                                    for: table,
                                    guestCount: guestCount,
                                    guestName: guestName,
                                    notes: note
                                ) {
                                    dismiss()
                                    onOrderCreated(created.id)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Управление столом")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}

// MARK: - Модальное окно добавления нового стола

struct AddTableSheet: View {
    @EnvironmentObject private var tableVM: TableMapViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var seats: Int = 4
    @State private var zone: HallZone = .main

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Параметры нового стола")
                            .font(.system(size: 18, weight: .bold))

                        Stepper("Посадочных мест: \(seats)", value: $seats, in: 2...16, step: 2)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(minHeight: 44)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Зона размещения")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)

                            Picker("Зона", selection: $zone) {
                                ForEach(HallZone.allCases) { item in
                                    Text(item.rawValue).tag(item)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                PrimaryActionButton(title: "Добавить стол в зал", icon: "plus.circle.fill") {
                    tableVM.addNewTable(seats: seats, zone: zone)
                    dismiss()
                }

                Spacer()
            }
            .padding(16)
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Новый стол")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}
