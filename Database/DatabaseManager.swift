import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbURL = appSupportURL.appendingPathComponent("workholl.sqlite")
            var config = Configuration()
            config.foreignKeysEnabled = true
            dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)
            try migrator.migrate(dbQueue)
            try seedInitialDataIfNeeded()
        } catch {
            // Fallback на in-memory базу в случае проблем с файловой системой (например, в превью)
            dbQueue = try! DatabaseQueue()
            try? migrator.migrate(dbQueue)
            try? seedInitialDataIfNeeded()
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_workholl_tables") { db in
            // 1. Таблица позиций меню (menuItems)
            try db.create(table: "menuItems") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("itemDescription", .text).notNull().defaults(to: "")
                t.column("price", .double).notNull()
                t.column("weight", .text).notNull().defaults(to: "")
                t.column("category", .text).notNull()
                t.column("isAvailable", .boolean).notNull().defaults(to: true)
                t.column("isHit", .boolean).notNull().defaults(to: false)
                t.column("isNewItem", .boolean).notNull().defaults(to: false)
                t.column("popularity", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
            }

            // 2. Таблица столов зала (tables)
            try db.create(table: "tables") { t in
                t.column("id", .text).primaryKey()
                t.column("number", .integer).notNull().unique()
                t.column("seats", .integer).notNull().defaults(to: 4)
                t.column("zone", .text).notNull()
                t.column("status", .text).notNull()
                t.column("guestCount", .integer).notNull().defaults(to: 0)
                t.column("occupiedSince", .datetime)
                t.column("waiterNote", .text).notNull().defaults(to: "")
            }

            // 3. Таблица заказов (orders)
            try db.create(table: "orders") { t in
                t.column("id", .text).primaryKey()
                t.column("tableNumber", .integer).notNull().indexed()
                t.column("guestCount", .integer).notNull().defaults(to: 2)
                t.column("guestName", .text).notNull().defaults(to: "")
                t.column("status", .text).notNull().indexed()
                t.column("paymentMethod", .text).notNull().defaults(to: PaymentMethod.card.rawValue)
                t.column("notes", .text).notNull().defaults(to: "")
                t.column("discountPercent", .double).notNull().defaults(to: 0)
                t.column("tipPercent", .double).notNull().defaults(to: 10)
                t.column("splitCount", .integer).notNull().defaults(to: 1)
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("closedAt", .datetime)
            }

            // 4. Таблица позиций заказа (orderItems)
            try db.create(table: "orderItems") { t in
                t.column("id", .text).primaryKey()
                t.column("orderId", .text)
                    .notNull()
                    .indexed()
                    .references("orders", onDelete: .cascade)
                t.column("menuItemId", .text).notNull()
                t.column("menuItemName", .text).notNull()
                t.column("unitPrice", .double).notNull()
                t.column("quantity", .integer).notNull().defaults(to: 1)
                t.column("course", .integer).notNull().defaults(to: 1)
                t.column("comment", .text).notNull().defaults(to: "")
                t.column("isServed", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }
        }

        return migrator
    }

    private func seedInitialDataIfNeeded() throws {
        try dbQueue.write { db in
            let menuCount = try MenuItem.fetchCount(db)
            if menuCount == 0 {
                let initialMenu: [MenuItem] = [
                    MenuItem(name: "Тартар из говядины Black Angus", itemDescription: "С перепелиным желтком, каперсами и трюфельным маслом", price: 890, weight: "190 г", category: .appetizers, isHit: true, popularity: 38),
                    MenuItem(name: "Брускетта с камчатским крабом", itemDescription: "На ремесленном хлебе с гуакамоле и томатами конкассе", price: 950, weight: "160 г", category: .appetizers, isNewItem: true, popularity: 27),
                    MenuItem(name: "Плато фермерских сыров", itemDescription: "Камамбер, горгонзола, пармезан, трюфельный мёд и орехи", price: 1250, weight: "240 г", category: .appetizers, popularity: 19),
                    MenuItem(name: "Цезарь с тигровыми креветками", itemDescription: "Романо, соус анчоус, пармезан 24 мес., гренки бриошь", price: 780, weight: "230 г", category: .salads, isHit: true, popularity: 45),
                    MenuItem(name: "Салат с уткой и инжиром", itemDescription: "Микс салата, утиная грудка су-вид, малиновый винегрет", price: 720, weight: "210 г", category: .salads, popularity: 22),
                    MenuItem(name: "Том Ям с морепродуктами", itemDescription: "На кокосовом молоке с креветками, кальмаром и рисом жасмин", price: 790, weight: "380 мл", category: .soups, isHit: true, popularity: 41),
                    MenuItem(name: "Борщ с томлёной уткой", itemDescription: "Подаётся с пампушками, копчёной сметаной и смальцем", price: 590, weight: "350 мл", category: .soups, popularity: 33),
                    MenuItem(name: "Стейк Рибай Prime", itemDescription: "Мраморная говядина зернового откорма, перечный соус Демиглас", price: 2890, weight: "320 г", category: .mains, isHit: true, popularity: 52),
                    MenuItem(name: "Филе лосося с пюре из батата", itemDescription: "С соусом шампань и красной икрой", price: 1490, weight: "260 г", category: .mains, popularity: 36),
                    MenuItem(name: "Утиная ножка Конфи", itemDescription: "С кремом из печёного корня сельдерея и вишнёвым жу", price: 1190, weight: "280 г", category: .mains, isNewItem: true, popularity: 24),
                    MenuItem(name: "Паста Карбонара с гуанчале", itemDescription: "Домашние спагетти, пекорино романо, желток", price: 690, weight: "250 г", category: .mains, popularity: 48),
                    MenuItem(name: "Спаржа на гриле с пармезаном", itemDescription: "Зелёная спаржа с оливковым маслом Extra Virgin", price: 490, weight: "150 г", category: .sides, popularity: 17),
                    MenuItem(name: "Авторский лимонад Манго-Маракуйя", itemDescription: "Натуральное пюре тропических фруктов, содовая, мята", price: 390, weight: "400 мл", category: .drinks, isHit: true, popularity: 64),
                    MenuItem(name: "Эспрессо-тоник Сицилия", itemDescription: "Двойной эспрессо, крафтовый тоник, розмарин и грейпфрут", price: 360, weight: "300 мл", category: .drinks, isNewItem: true, popularity: 29),
                    MenuItem(name: "Баскский чизкейк Сан-Себастьян", itemDescription: "С тёплым бельгийским шоколадом и свежей голубикой", price: 540, weight: "170 г", category: .desserts, isHit: true, popularity: 44),
                    MenuItem(name: "Мильфей с фисташковым кремом", itemDescription: "Хрустящее слоёное тесто и свежая малина", price: 580, weight: "160 г", category: .desserts, popularity: 26)
                ]
                for item in initialMenu {
                    try item.insert(db)
                }

                // Сидируем 12 столов
                let tableConfigs: [(Int, Int, HallZone, TableStatus, Int, String)] = [
                    (1, 2, .main, .occupied, 2, "Гости у окна, подача напитков сразу"),
                    (2, 4, .main, .free, 0, ""),
                    (3, 4, .main, .waitingBill, 3, "Оплата по QR"),
                    (4, 6, .main, .free, 0, ""),
                    (5, 2, .main, .free, 0, ""),
                    (6, 4, .main, .reserved, 4, "Бронь на 20:00 — Алексей"),
                    (7, 4, .terrace, .occupied, 2, "Пледы принесли"),
                    (8, 2, .terrace, .free, 0, ""),
                    (9, 6, .terrace, .free, 0, ""),
                    (10, 6, .vip, .occupied, 5, "День рождения, свеча в десерт"),
                    (11, 8, .vip, .free, 0, ""),
                    (12, 10, .vip, .free, 0, "")
                ]

                let now = Date()
                for cfg in tableConfigs {
                    let table = Table(
                        number: cfg.0,
                        seats: cfg.1,
                        zone: cfg.2,
                        status: cfg.3,
                        guestCount: cfg.4,
                        occupiedSince: cfg.3 == .free ? nil : now.addingTimeInterval(-Double.random(in: 900...3200)),
                        waiterNote: cfg.5
                    )
                    try table.insert(db)
                }

                // Создаём стартовые заказы для наглядности аналитики и активного зала
                if initialMenu.count >= 12 {
                    // Активный заказ — Стол 1
                    let order1 = Order(
                        tableNumber: 1,
                        guestCount: 2,
                        guestName: "Стол у окна",
                        status: .preparing,
                        paymentMethod: .card,
                        notes: "Стейк прожарки Medium",
                        discountPercent: 0,
                        tipPercent: 10,
                        splitCount: 1,
                        createdAt: now.addingTimeInterval(-1800)
                    )
                    try order1.insert(db)
                    try OrderItem(orderId: order1.id, menuItemId: initialMenu[7].id, menuItemName: initialMenu[7].name, unitPrice: initialMenu[7].price, quantity: 1, course: 2, comment: "Medium").insert(db)
                    try OrderItem(orderId: order1.id, menuItemId: initialMenu[3].id, menuItemName: initialMenu[3].name, unitPrice: initialMenu[3].price, quantity: 1, course: 1, isServed: true).insert(db)
                    try OrderItem(orderId: order1.id, menuItemId: initialMenu[12].id, menuItemName: initialMenu[12].name, unitPrice: initialMenu[12].price, quantity: 2, course: 1, isServed: true).insert(db)

                    // Ожидает счёт — Стол 3
                    let order2 = Order(
                        tableNumber: 3,
                        guestCount: 3,
                        guestName: "Компания (3 гостя)",
                        status: .ready,
                        paymentMethod: .qr,
                        notes: "Попросили разделить счёт на троих",
                        discountPercent: 5,
                        tipPercent: 10,
                        splitCount: 3,
                        createdAt: now.addingTimeInterval(-2700)
                    )
                    try order2.insert(db)
                    try OrderItem(orderId: order2.id, menuItemId: initialMenu[0].id, menuItemName: initialMenu[0].name, unitPrice: initialMenu[0].price, quantity: 1, course: 1, isServed: true).insert(db)
                    try OrderItem(orderId: order2.id, menuItemId: initialMenu[5].id, menuItemName: initialMenu[5].name, unitPrice: initialMenu[5].price, quantity: 2, course: 1, isServed: true).insert(db)
                    try OrderItem(orderId: order2.id, menuItemId: initialMenu[10].id, menuItemName: initialMenu[10].name, unitPrice: initialMenu[10].price, quantity: 1, course: 2, isServed: true).insert(db)
                    try OrderItem(orderId: order2.id, menuItemId: initialMenu[14].id, menuItemName: initialMenu[14].name, unitPrice: initialMenu[14].price, quantity: 2, course: 3, isServed: true).insert(db)

                    // Заказ VIP — Стол 10
                    let order3 = Order(
                        tableNumber: 10,
                        guestCount: 5,
                        guestName: "VIP Банкет",
                        status: .new,
                        paymentMethod: .card,
                        notes: "День рождения — вынести десерт со свечой",
                        discountPercent: 10,
                        tipPercent: 15,
                        splitCount: 1,
                        createdAt: now.addingTimeInterval(-900)
                    )
                    try order3.insert(db)
                    try OrderItem(orderId: order3.id, menuItemId: initialMenu[1].id, menuItemName: initialMenu[1].name, unitPrice: initialMenu[1].price, quantity: 2, course: 1).insert(db)
                    try OrderItem(orderId: order3.id, menuItemId: initialMenu[2].id, menuItemName: initialMenu[2].name, unitPrice: initialMenu[2].price, quantity: 1, course: 1).insert(db)
                    try OrderItem(orderId: order3.id, menuItemId: initialMenu[7].id, menuItemName: initialMenu[7].name, unitPrice: initialMenu[7].price, quantity: 2, course: 2).insert(db)
                    try OrderItem(orderId: order3.id, menuItemId: initialMenu[8].id, menuItemName: initialMenu[8].name, unitPrice: initialMenu[8].price, quantity: 2, course: 2).insert(db)

                    // Закрытый заказ смены (для статистики)
                    let closedOrder = Order(
                        tableNumber: 4,
                        guestCount: 2,
                        guestName: "Обеденный сет",
                        status: .closed,
                        paymentMethod: .card,
                        notes: "",
                        discountPercent: 0,
                        tipPercent: 10,
                        splitCount: 1,
                        createdAt: now.addingTimeInterval(-7200),
                        closedAt: now.addingTimeInterval(-4800)
                    )
                    try closedOrder.insert(db)
                    try OrderItem(orderId: closedOrder.id, menuItemId: initialMenu[3].id, menuItemName: initialMenu[3].name, unitPrice: initialMenu[3].price, quantity: 2, course: 1, isServed: true).insert(db)
                    try OrderItem(orderId: closedOrder.id, menuItemId: initialMenu[8].id, menuItemName: initialMenu[8].name, unitPrice: initialMenu[8].price, quantity: 2, course: 2, isServed: true).insert(db)
                    try OrderItem(orderId: closedOrder.id, menuItemId: initialMenu[12].id, menuItemName: initialMenu[12].name, unitPrice: initialMenu[12].price, quantity: 2, course: 1, isServed: true).insert(db)
                }
            }
        }
    }
}
