import Foundation
import UIKit
import Combine
import GRDB

enum MenuSortOption: String, CaseIterable, Identifiable {
    case popularity = "По популярности"
    case nameAsc = "По алфавиту"
    case priceAsc = "Сначала дешевле"
    case priceDesc = "Сначала дороже"

    var id: String { rawValue }
}

@MainActor
final class MenuViewModel: ObservableObject {
    @Published private(set) var allItems: [MenuItem] = []
    @Published var selectedCategory: MenuCategory? = nil
    @Published var searchText: String = ""
    @Published var sortOption: MenuSortOption = .popularity
    @Published var showOnlyAvailable: Bool = false

    // Состояние OCR-сканера меню
    @Published var scannedImage: UIImage? = nil
    @Published var recognizedItems: [MenuItem] = []
    @Published var selectedOCRIds: Set<String> = []
    @Published var isScanning: Bool = false
    @Published var ocrStatusMessage: String? = nil
    @Published var errorMessage: String? = nil

    private let menuRepository: MenuRepository
    private let menuService: MenuService
    private let ocrService: OCRService
    private var menuCancellable: AnyDatabaseCancellable?

    init(
        menuRepository: MenuRepository = .shared,
        menuService: MenuService = .shared,
        ocrService: OCRService = .shared
    ) {
        self.menuRepository = menuRepository
        self.menuService = menuService
        self.ocrService = ocrService
        startReactiveObservation()
    }

    var filteredItems: [MenuItem] {
        var result = allItems.filter { item in
            if showOnlyAvailable && !item.isAvailable {
                return false
            }
            if let selectedCategory, item.category != selectedCategory {
                return false
            }
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return true }
            return item.name.lowercased().contains(query) ||
                   item.itemDescription.lowercased().contains(query) ||
                   item.category.rawValue.lowercased().contains(query)
        }

        switch sortOption {
        case .popularity:
            result.sort { $0.popularity > $1.popularity }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .priceAsc:
            result.sort { $0.price < $1.price }
        case .priceDesc:
            result.sort { $0.price > $1.price }
        }
        return result
    }

    var stopListCount: Int {
        allItems.filter { !$0.isAvailable }.count
    }

    private func startReactiveObservation() {
        menuCancellable = menuRepository
            .observeAll()
            .start(
                in: DatabaseManager.shared.dbQueue,
                onError: { [weak self] error in
                    Task { @MainActor in
                        self?.errorMessage = error.localizedDescription
                    }
                },
                onChange: { [weak self] freshItems in
                    Task { @MainActor in
                        self?.allItems = freshItems
                    }
                }
            )
    }

    // MARK: - Операции с позициями меню (реактивное обновление через GRDB)

    func saveItem(_ item: MenuItem) {
        do {
            try menuService.saveMenuItem(item)
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }

    func toggleAvailability(_ item: MenuItem) {
        do {
            try menuService.toggleAvailability(item)
            HapticManager.impact(.medium)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleHit(_ item: MenuItem) {
        do {
            try menuService.toggleHit(item)
            HapticManager.selection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: MenuItem) {
        do {
            try menuService.deleteMenuItem(item)
            HapticManager.notification(.warning)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - OCR распознавание фото меню через Vision + Regex

    func scanMenuImage(_ image: UIImage) {
        scannedImage = image
        isScanning = true
        errorMessage = nil
        ocrStatusMessage = nil

        ocrService.recognizeMenu(from: image) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isScanning = false
                switch result {
                case .success(let items):
                    self.recognizedItems = items
                    self.selectedOCRIds = Set(items.map(\.id))
                    if items.isEmpty {
                        self.ocrStatusMessage = "Не удалось распознать позиции по шаблону «Название Цена руб». Попробуйте более чёткое фото."
                        HapticManager.notification(.warning)
                    } else {
                        self.ocrStatusMessage = "Распознано позиций: \(items.count)"
                        HapticManager.notification(.success)
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    HapticManager.notification(.error)
                }
            }
        }
    }

    func runDemoOCRScan() {
        let demoImage = ocrService.generateDemoMenuImage()
        scanMenuImage(demoImage)
    }

    func toggleOCRSelection(_ item: MenuItem) {
        if selectedOCRIds.contains(item.id) {
            selectedOCRIds.remove(item.id)
        } else {
            selectedOCRIds.insert(item.id)
        }
        HapticManager.selection()
    }

    func updateRecognizedItem(_ updated: MenuItem) {
        if let index = recognizedItems.firstIndex(where: { $0.id == updated.id }) {
            recognizedItems[index] = updated
        }
    }

    func importSelectedOCRItems() {
        let itemsToImport = recognizedItems.filter { selectedOCRIds.contains($0.id) }
        guard !itemsToImport.isEmpty else { return }
        do {
            try menuService.importOCRItems(itemsToImport)
            ocrStatusMessage = "Успешно добавлено в меню: \(itemsToImport.count) поз."
            recognizedItems.removeAll()
            selectedOCRIds.removeAll()
            HapticManager.notification(.success)
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.notification(.error)
        }
    }
}
