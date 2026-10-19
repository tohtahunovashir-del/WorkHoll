import SwiftUI

struct OrderDetailView: View {
    @EnvironmentObject private var ordersVM: OrdersViewModel
    @EnvironmentObject private var menuVM: MenuViewModel
    let orderId: String

    @State private var showAddDishSheet = false
    @State private var showShareReceipt = false
    @State private var receiptText: String = ""

    private var detail: OrderWithItems? {
        ordersVM.allOrders.first(where: { $0.id == orderId })
    }

    var body: some View {
        Group {
            if let detail {
                ScrollView {
                    VStack(spacing: 16) {
                        orderHeaderCard(detail)

                        dishesSection(detail)

                        billingConfigCard(detail)

                        financialSummaryCard(detail)

                        actionButtonsSection(detail)
                    }
                    .padding(16)
                }
                .background(AppTheme.screenBackground.ignoresSafeArea())
                .navigationTitle("Стол №\(detail.order.tableNumber)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            receiptText = ExportService.shared.formatReceipt(for: detail)
                            showShareReceipt = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
                .sheet(isPresented: $showAddDishSheet) {
                    OrderMenuPickerSheet(orderId: detail.order.id)
                }
                .sheet(isPresented: $showShareReceipt) {
                    ShareSheet(activityItems: [receiptText])
                }
            } else {
                EmptyStateCard(
                    icon: "doc.text.magnifyingglass",
                    title: "Заказ не найден",
                    message: "Возможно, заказ был удалён."
                )
                .padding(16)
            }
        }
    }

    private func orderHeaderCard(_ detail: OrderWithItems) -> some View {
        let color = AppTheme.statusColor(for: detail.order.status)
        return PremiumCard(borderColor: color.opacity(0.35)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.order.guestName.isEmpty ? "Стол №\(detail.order.tableNumber)" : detail.order.guestName)
                            .font(.system(size: 20, weight: .bold))
                        Text("Гостей: \(detail.order.guestCount) • Создан \(detail.order.createdAt.russianDateTime)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(
                        text: detail.order.status.rawValue,
                        icon: detail.order.status.icon,
                        color: color
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(OrderStatus.allCases) { status in
                            FilterChip(
                                title: status.rawValue,
                                icon: status.icon,
                                isSelected: detail.order.status == status,
                                activeColor: AppTheme.statusColor(for: status)
                            ) {
                                ordersVM.advanceStatus(detail.order, to: status)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dishesSection(_ detail: OrderWithItems) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Позиции заказа (\(detail.totalQuantity))")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Button {
                        HapticManager.impact(.medium)
                        showAddDishSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Добавить блюдо")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(AppTheme.primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if detail.items.isEmpty {
                    Text("В заказе пока нет блюд. Нажмите «Добавить блюдо», чтобы выбрать позиции из меню.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(detail.items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    ordersVM.toggleServed(item: item)
                                } label: {
                                    Image(systemName: item.isServed ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundColor(item.isServed ? AppTheme.success : .secondary)
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.menuItemName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .strikethrough(item.isServed, color: .secondary)
                                    HStack(spacing: 8) {
                                        Text("Курс \(item.course)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(AppTheme.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(AppTheme.primary.opacity(0.12))
                                            .clipShape(Capsule())

                                        Text("\(item.unitPrice.formattedCurrency) / шт.")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    if !item.comment.isEmpty {
                                        Text("Комментарий: \(item.comment)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppTheme.accent)
                                    }
                                }

                                Spacer()

                                Text(item.subtotal.formattedCurrency)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }

                            HStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        ordersVM.updateQuantity(item: item, quantity: item.quantity - 1)
                                    } label: {
                                        Image(systemName: item.quantity <= 1 ? "trash.fill" : "minus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(item.quantity <= 1 ? AppTheme.danger : .primary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)

                                    Text("\(item.quantity)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .frame(minWidth: 28)

                                    Button {
                                        ordersVM.updateQuantity(item: item, quantity: item.quantity + 1)
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(AppTheme.primary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private func billingConfigCard(_ detail: OrderWithItems) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Параметры расчёта и разделение счёта")
                    .font(.system(size: 17, weight: .bold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Способ оплаты")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PaymentMethod.allCases) { method in
                                FilterChip(
                                    title: method.rawValue,
                                    icon: method.icon,
                                    isSelected: detail.order.paymentMethod == method
                                ) {
                                    ordersVM.updateBillingParameters(
                                        order: detail.order,
                                        paymentMethod: method
                                    )
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Чаевые официанту")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(AppConstants.defaultTipOptions, id: \.self) { tip in
                            Button {
                                ordersVM.updateBillingParameters(order: detail.order, tipPercent: tip)
                            } label: {
                                Text("\(Int(tip))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(detail.order.tipPercent == tip ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(
                                        detail.order.tipPercent == tip
                                            ? AppTheme.accent
                                            : Color.primary.opacity(0.06)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Скидка лояльности")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(AppConstants.defaultDiscountOptions, id: \.self) { discount in
                            Button {
                                ordersVM.updateBillingParameters(order: detail.order, discountPercent: discount)
                            } label: {
                                Text("\(Int(discount))%")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(detail.order.discountPercent == discount ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(
                                        detail.order.discountPercent == discount
                                            ? AppTheme.primary
                                            : Color.primary.opacity(0.06)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Stepper(
                    "Разделить счёт на гостей: \(detail.order.splitCount)",
                    value: Binding(
                        get: { detail.order.splitCount },
                        set: { newCount in
                            ordersVM.updateBillingParameters(order: detail.order, splitCount: newCount)
                        }
                    ),
                    in: 1...20
                )
                .font(.system(size: 15, weight: .semibold))
                .frame(minHeight: 44)
            }
        }
    }

    private func financialSummaryCard(_ detail: OrderWithItems) -> some View {
        PremiumCard(borderColor: AppTheme.primary.opacity(0.25)) {
            VStack(spacing: 10) {
                summaryRow(title: "Сумма блюд", value: detail.subtotal.formattedCurrency)
                if detail.order.discountPercent > 0 {
                    summaryRow(
                        title: "Скидка (\(Int(detail.order.discountPercent))%)",
                        value: "-\(detail.discountAmount.formattedCurrency)",
                        color: AppTheme.success
                    )
                }
                if detail.order.tipPercent > 0 {
                    summaryRow(
                        title: "Чаевые (\(Int(detail.order.tipPercent))%)",
                        value: "+\(detail.tipAmount.formattedCurrency)",
                        color: AppTheme.accent
                    )
                }
                Divider()
                HStack {
                    Text("ИТОГО К ОПЛАТЕ")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Text(detail.total.formattedCurrency)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                }
                if detail.order.splitCount > 1 {
                    HStack {
                        Text("На каждого гостя (\(detail.order.splitCount) чел.)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(detail.perGuestAmount.formattedCurrency)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
        }
    }

    private func summaryRow(title: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
    }

    private func actionButtonsSection(_ detail: OrderWithItems) -> some View {
        VStack(spacing: 12) {
            if detail.order.status.isActive {
                PrimaryActionButton(
                    title: "Закрыть счёт и рассчитать стол",
                    icon: "checkmark.seal.fill",
                    color: AppTheme.success
                ) {
                    ordersVM.advanceStatus(detail.order, to: .closed)
                }
            }

            SecondaryActionButton(
                title: "Экспортировать пречек для гостя",
                icon: "doc.plaintext.fill"
            ) {
                receiptText = ExportService.shared.formatReceipt(for: detail)
                showShareReceipt = true
            }
        }
    }
}

// MARK: - Модальное окно быстрого подбора блюд в заказ

struct OrderMenuPickerSheet: View {
    @EnvironmentObject private var ordersVM: OrdersViewModel
    @EnvironmentObject private var menuVM: MenuViewModel
    let orderId: String

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCourse: Int = 1
    @State private var kitchenComment: String = ""
    @State private var localSearch: String = ""
    @State private var localCategory: MenuCategory? = nil

    private var availableDishes: [MenuItem] {
        menuVM.allItems.filter { item in
            guard item.isAvailable else { return false }
            if let localCategory, item.category != localCategory { return false }
            let q = localSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !q.isEmpty else { return true }
            return item.name.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    HStack {
                        Text("Курс подачи:")
                            .font(.system(size: 14, weight: .semibold))
                        Picker("Курс подачи", selection: $selectedCourse) {
                            Text("1 курс").tag(1)
                            Text("2 курс").tag(2)
                            Text("3 курс").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }

                    TextField("Комментарий для кухни (без лука, Medium, соус отдельно)", text: $kitchenComment)
                        .padding(10)
                        .frame(minHeight: 44)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Все", isSelected: localCategory == nil) {
                                localCategory = nil
                            }
                            ForEach(MenuCategory.allCases) { cat in
                                FilterChip(
                                    title: cat.rawValue,
                                    icon: cat.icon,
                                    isSelected: localCategory == cat
                                ) {
                                    localCategory = cat
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(availableDishes) { dish in
                            PremiumCard(padding: 14) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(dish.name)
                                            .font(.system(size: 16, weight: .bold))
                                        Text("\(dish.category.rawValue) • \(dish.price.formattedCurrency)")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppTheme.primary)
                                    }
                                    Spacer()
                                    Button {
                                        ordersVM.addItem(
                                            to: orderId,
                                            menuItem: dish,
                                            quantity: 1,
                                            course: selectedCourse,
                                            comment: kitchenComment
                                        )
                                        kitchenComment = ""
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus")
                                            Text("В заказ")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 44)
                                        .background(AppTheme.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Подбор блюд")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $localSearch, prompt: "Быстрый поиск блюда")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
    }
}
