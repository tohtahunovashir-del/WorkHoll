# WorkHoll — Премиальный iOS-терминал для официантов (iOS 16.0+)

**WorkHoll** — нативное iOS-приложение на SwiftUI, спроектированное специально для скоростной работы официантов в ресторанах и кафе. Поддерживает **iOS 16.0+** (включая iOS 16.7.x), реактивное хранение данных через **GRDB (SQLite)** и интеллектуальное распознавание печатного меню с помощью **Vision OCR + Regex**.

---

## Технический стек и архитектурные гарантии

- **Платформа:** iOS 16.0+ (`IPHONEOS_DEPLOYMENT_TARGET = 16.0`). Полный отказ от `SwiftData` и макроса `@Observable` (требующих iOS 17).
- **Хранение данных:** Только **GRDB.swift** (`https://github.com/groue/GRDB.swift.git`) поверх SQLite.
- **Модели данных:** Исключительно `struct`, реализующие `Codable`, `Identifiable`, `Equatable`, `Hashable`, `FetchableRecord`, `PersistableRecord`.
- **Реактивный стейт-менеджмент:** `@Published` + `ObservableObject` в связке с `GRDB.ValueObservation`. Любые мутации в базе данных реактивно обновляют UI без ручных вызовов `load()`.
- **OCR и парсинг меню:** Фреймворк `Vision` (`VNRecognizeTextRequest`) + умный пост-обработчик с регулярным выражением:
  ```swift
  #"^(.+?)\s+(\d{2,5})\s*(руб|р\.?)?$"#
  ```
- **Интерфейс и UX:** Полностью на русском языке, соответствие iOS Human Interface Guidelines (крупные тач-зоны `>= 44x44pt`, кастомные карточки с тенями, адаптивная поддержка тёмной и светлой темы, тактильный отклик через `UIImpactFeedbackGenerator` и `UINotificationFeedbackGenerator`).

---

## Структура проекта

```text
WorkHoll/
├── WorkHollApp.swift                 # Точка входа, инициализация DatabaseManager
├── project.yml                       # Конфигурация XcodeGen (с excludes: ['.github'])
├── Info.plist                        # Разрешения камеры и фотогалереи (на русском)
├── LaunchScreen.storyboard           # Экран запуска
├── Assets.xcassets/                  # Иконка приложения 1024x1024 и AccentColor
├── .github/workflows/ios-build.yml   # GitHub Actions: сборка без подписи (.app.zip и .ipa)
├── Models/
│   ├── MenuItem.swift                # struct MenuItem, enum MenuCategory
│   ├── Table.swift                   # struct Table, enum HallZone, enum TableStatus
│   ├── Order.swift                   # struct Order, struct OrderWithItems, enum OrderStatus
│   └── OrderItem.swift               # struct OrderItem
├── Database/
│   ├── DatabaseManager.swift         # Singleton, миграции GRDB (menuItems, tables, orders, orderItems)
│   ├── MenuRepository.swift          # Репозиторий меню + ValueObservation
│   ├── TableRepository.swift         # Репозиторий столов + ValueObservation
│   └── OrderRepository.swift         # Репозиторий заказов и позиций + ValueObservation
├── Services/
│   ├── OCRService.swift              # Vision OCR + Regex парсер -> [MenuItem]
│   ├── MenuService.swift             # Бизнес-логика каталога и стоп-листа
│   ├── OrderService.swift            # Координация заказов, столов и популярности блюд
│   └── ExportService.swift           # Генерация пречеков и Z-отчёта смены
├── ViewModels/
│   ├── TableMapViewModel.swift       # Реактивная ViewModel карты зала
│   ├── OrdersViewModel.swift         # Реактивная ViewModel заказов и расчёта
│   ├── MenuViewModel.swift           # Реактивная ViewModel меню и OCR-импорта
│   └── StatsViewModel.swift          # Реактивная ViewModel аналитики смены
├── Views/
│   ├── MainTabView.swift             # Главный TabView (Зал, Заказы, Меню, OCR Сканер, Аналитика)
│   ├── TableMapView.swift            # Интерактивная карта зала по зонам
│   ├── OrdersView.swift              # Активные и архивные заказы
│   ├── OrderDetailView.swift         # Карточка заказа, курсы подачи, разделение счёта, чаевые
│   ├── MenuView.swift                # Каталог блюд и управление стоп-листом
│   ├── ScannerView.swift             # Экран сканирования меню через камеру / фото / демо
│   └── StatsView.swift               # Дашборд выручки, чаевых и популярных блюд
├── Components/
│   └── PremiumComponents.swift       # Кастомные UI-компоненты по iOS HIG
└── Utilities/
    ├── Constants.swift               # Цветовая палитра и константы
    ├── Extensions.swift              # Форматирование валюты и дат
    └── HapticManager.swift           # Менеджер тактильного отклика
```
