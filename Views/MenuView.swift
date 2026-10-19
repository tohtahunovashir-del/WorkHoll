import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var menuVM: MenuViewModel

    @State private var showEditorSheet = false
    @State private var editingItem: MenuItem? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    menuControlBar

                    categoryBar

                    if menuVM.filteredItems.isEmpty {
                        EmptyStateCard(
                            icon: "menucard",
                            title: "Позиции не найдены",
                            message: "Попробуйте изменить категорию, поисковый запрос или добавьте новое блюдо.",
                            buttonTitle: "Добавить позицию"
                        ) {
                            editingItem = nil
                            showEditorSheet = true
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(menuVM.filteredItems) { item in
                                MenuItemCardView(
                                    item: item,
                                    onToggleStopList: {
                                        menuVM.toggleAvailability(item)
                                    },
                                    onEdit: {
                                        editingItem = item
                                        showEditorSheet = true
                                    },
                                    onDelete: {
                                        menuVM.deleteItem(item)
                                    }
                                )
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: menuVM.filteredItems)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Меню (\(menuVM.allItems.count))")
            .searchable(text: $menuVM.searchText, prompt: "Поиск блюда или ингредиента")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Сортировка", selection: $menuVM.sortOption) {
                            ForEach(MenuSortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                            Text("Сортировка")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.impact(.medium)
                        editingItem = nil
                        showEditorSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Блюдо")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .sheet(isPresented: $showEditorSheet) {
                MenuItemEditorSheet(existingItem: editingItem)
            }
        }
    }

    private var menuControlBar: some View {
        HStack {
            FilterChip(
                title: "Только в наличии",
                icon: "checkmark.circle.fill",
                isSelected: menuVM.showOnlyAvailable,
                activeColor: AppTheme.success
            ) {
                menuVM.showOnlyAvailable.toggle()
            }

            if menuVM.stopListCount > 0 {
                StatusBadge(
                    text: "Стоп-лист: \(menuVM.stopListCount)",
                    icon: "nosign",
                    color: AppTheme.danger
                )
            }

            Spacer()
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Все категории",
                    icon: "square.grid.2x2.fill",
                    isSelected: menuVM.selectedCategory == nil
                ) {
                    menuVM.selectedCategory = nil
                }

                ForEach(MenuCategory.allCases) { category in
                    FilterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: menuVM.selectedCategory == category
                    ) {
                        menuVM.selectedCategory = category
                    }
                }
            }
        }
    }
}

// MARK: - Премиальная карточка позиции меню

struct MenuItemCardView: View {
    let item: MenuItem
    let onToggleStopList: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        PremiumCard(
            padding: 16,
            borderColor: item.isAvailable ? AppTheme.subtleBorder : AppTheme.danger.opacity(0.35)
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(item.isAvailable ? .primary : .secondary)
                                .strikethrough(!item.isAvailable, color: AppTheme.danger)

                            if item.isHit {
                                StatusBadge(text: "ХИТ", icon: "flame.fill", color: AppTheme.accent)
                            }
                            if item.isNewItem {
                                StatusBadge(text: "НОВОЕ", icon: "sparkles", color: AppTheme.primary)
                            }
                        }

                        HStack(spacing: 8) {
                            Label(item.category.rawValue, systemImage: item.category.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppTheme.primary)

                            if !item.weight.isEmpty {
                                Text("• \(item.weight)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            if item.popularity > 0 {
                                Text("• Заказов: \(item.popularity)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Text(item.price.formattedCurrency)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(item.isAvailable ? AppTheme.primary : .secondary)
                }

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        onToggleStopList()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.isAvailable ? "pause.circle.fill" : "play.circle.fill")
                            Text(item.isAvailable ? "В стоп-лист" : "Вернуть в меню")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(item.isAvailable ? AppTheme.warning : AppTheme.success)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background((item.isAvailable ? AppTheme.warning : AppTheme.success).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.danger)
                            .frame(width: 44, height: 44)
                            .background(AppTheme.danger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Редактор позиции меню

struct MenuItemEditorSheet: View {
    @EnvironmentObject private var menuVM: MenuViewModel
    let existingItem: MenuItem?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var itemDescription: String = ""
    @State private var priceText: String = ""
    @State private var weight: String = ""
    @State private var category: MenuCategory = .mains
    @State private var isHit: Bool = false
    @State private var isNewItem: Bool = false
    @State private var isAvailable: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Основная информация")
                                .font(.system(size: 17, weight: .bold))

                            TextField("Название блюда (например, Стейк Рибай)", text: $name)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            HStack(spacing: 12) {
                                TextField("Цена (₽)", text: $priceText)
                                    .keyboardType(.decimalPad)
                                    .padding(12)
                                    .frame(minHeight: 48)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                TextField("Выход (250 г / 300 мл)", text: $weight)
                                    .padding(12)
                                    .frame(minHeight: 48)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            TextField("Описание состава и подачи", text: $itemDescription)
                                .padding(12)
                                .frame(minHeight: 48)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    PremiumCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Категория и метки")
                                .font(.system(size: 17, weight: .bold))

                            Picker("Категория", selection: $category) {
                                ForEach(MenuCategory.allCases) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(minHeight: 44)

                            Toggle("Доступно для заказа (не в стоп-листе)", isOn: $isAvailable)
                                .frame(minHeight: 44)
                            Toggle("Отметить как «Хит продаж»", isOn: $isHit)
                                .frame(minHeight: 44)
                            Toggle("Отметить как «Новинка»", isOn: $isNewItem)
                                .frame(minHeight: 44)
                        }
                    }

                    PrimaryActionButton(
                        title: existingItem == nil ? "Добавить блюдо в меню" : "Сохранить изменения",
                        icon: "checkmark.circle.fill",
                        isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || (Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0
                    ) {
                        let parsedPrice = Double(priceText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let item = MenuItem(
                            id: existingItem?.id ?? UUID().uuidString,
                            name: name,
                            itemDescription: itemDescription,
                            price: parsedPrice,
                            weight: weight,
                            category: category,
                            isAvailable: isAvailable,
                            isHit: isHit,
                            isNewItem: isNewItem,
                            popularity: existingItem?.popularity ?? 0,
                            createdAt: existingItem?.createdAt ?? Date()
                        )
                        menuVM.saveItem(item)
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle(existingItem == nil ? "Новое блюдо" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .onAppear {
                if let existingItem {
                    name = existingItem.name
                    itemDescription = existingItem.itemDescription
                    priceText = "\(Int(existingItem.price))"
                    weight = existingItem.weight
                    category = existingItem.category
                    isHit = existingItem.isHit
                    isNewItem = existingItem.isNewItem
                    isAvailable = existingItem.isAvailable
                }
            }
        }
    }
}
