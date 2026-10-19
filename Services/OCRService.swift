import Foundation
import Vision
import UIKit

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Не удалось обработать изображение меню."
        case .recognitionFailed(let reason):
            return "Ошибка распознавания текста: \(reason)"
        }
    }
}

final class OCRService {
    static let shared = OCRService()

    /// Строгий паттерн Regex по техническому заданию: (Название блюда, цена, валюта)
    static let menuItemPattern = #"^(.+?)\s+(\d{2,5})\s*(руб|р\.?)?$"#

    private init() {}

    // MARK: - Распознавание фото меню через Vision (возвращает [MenuItem])

    func recognizeMenu(
        from image: UIImage,
        completion: @escaping (Result<[MenuItem], Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async {
                    completion(.failure(OCRError.recognitionFailed(error.localizedDescription)))
                }
                return
            }

            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let rawLines = observations.compactMap { $0.topCandidates(1).first?.string }
            let menuItems = self.parseLinesToMenuItems(rawLines)

            DispatchQueue.main.async {
                completion(.success(menuItems))
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ru-RU", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(OCRError.recognitionFailed(error.localizedDescription)))
                }
            }
        }
    }

    func recognizeMenu(from image: UIImage) async throws -> [MenuItem] {
        try await withCheckedThrowingContinuation { continuation in
            recognizeMenu(from: image) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Умный пост-обработчик с Regex #"^(.+?)\s+(\d{2,5})\s*(руб|р\.?)?$"#

    func parseLinesToMenuItems(_ rawLines: [String]) -> [MenuItem] {
        guard let regex = try? NSRegularExpression(
            pattern: Self.menuItemPattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let priceOnlyRegex = try? NSRegularExpression(
            pattern: #"^(\d{2,5})\s*(руб|р\.?|₽)?$"#,
            options: [.caseInsensitive]
        )

        var parsedItems: [MenuItem] = []
        var currentCategory: MenuCategory? = nil
        var pendingTitle: String? = nil
        var seenNames = Set<String>()

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Проверяем, не является ли строка заголовком категории
            if let detectedCategory = detectCategoryHeader(trimmed) {
                currentCategory = detectedCategory
                pendingTitle = nil
                continue
            }

            // Извлекаем граммовку (если указана) и нормализуем строку под Regex
            let (normalizedLine, extractedWeight) = preprocessLine(trimmed)

            // Если строка содержит только цену, а на предыдущей строке было название блюда
            if let pending = pendingTitle,
               let priceOnlyRegex,
               priceOnlyRegex.firstMatch(
                   in: normalizedLine,
                   range: NSRange(normalizedLine.startIndex..., in: normalizedLine)
               ) != nil {
                let combined = "\(pending) \(normalizedLine)"
                if let item = matchMenuItem(
                    in: combined,
                    regex: regex,
                    weight: extractedWeight,
                    explicitCategory: currentCategory
                ) {
                    let key = item.name.lowercased()
                    if seenNames.insert(key).inserted {
                        parsedItems.append(item)
                    }
                    pendingTitle = nil
                    continue
                }
            }

            // Прямое сопоставление с паттерном #"^(.+?)\s+(\d{2,5})\s*(руб|р\.?)?$"#
            if let item = matchMenuItem(
                in: normalizedLine,
                regex: regex,
                weight: extractedWeight,
                explicitCategory: currentCategory
            ) {
                let key = item.name.lowercased()
                if seenNames.insert(key).inserted {
                    parsedItems.append(item)
                }
                pendingTitle = nil
            } else if isLikelyDishName(normalizedLine) {
                pendingTitle = normalizedLine
            }
        }

        return parsedItems
    }

    private func matchMenuItem(
        in line: String,
        regex: NSRegularExpression,
        weight: String,
        explicitCategory: MenuCategory?
    ) -> MenuItem? {
        let nsRange = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, range: nsRange),
              match.numberOfRanges >= 3,
              let nameRange = Range(match.range(at: 1), in: line),
              let priceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let rawName = String(line[nameRange])
        let cleanTitle = cleanDishName(rawName)
        guard cleanTitle.count >= 2,
              let price = Double(line[priceRange]),
              (20...99999).contains(price) else {
            return nil
        }

        let category = explicitCategory ?? guessCategory(for: cleanTitle)
        return MenuItem(
            name: cleanTitle,
            itemDescription: weight.isEmpty ? "Распознано через Vision OCR" : "Выход: \(weight)",
            price: price,
            weight: weight,
            category: category,
            isAvailable: true,
            isNewItem: true
        )
    }

    private func preprocessLine(_ line: String) -> (String, String) {
        var working = line
            .replacingOccurrences(of: "₽", with: "руб")
            .replacingOccurrences(of: "РУБ.", with: "руб")
            .replacingOccurrences(of: "руб.", with: "руб")

        // Извлекаем вес/объём (например, "250 г", "300мл", "200 гр")
        var extractedWeight = ""
        if let weightRegex = try? NSRegularExpression(
            pattern: #"(\d{2,4}\s*(?:г|гр|мл|л)\.?)"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(working.startIndex..., in: working)
            if let match = weightRegex.firstMatch(in: working, range: range),
               let swiftRange = Range(match.range(at: 1), in: working) {
                extractedWeight = String(working[swiftRange]).trimmingCharacters(in: .whitespaces)
                working.removeSubrange(swiftRange)
            }
        }

        // Убираем отточия ("......"), тире и лишние пробелы между названием и ценой
        working = working.replacingOccurrences(
            of: #"[\.\-–—_]{2,}"#,
            with: " ",
            options: .regularExpression
        )
        working = working.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return (working.trimmingCharacters(in: .whitespacesAndNewlines), extractedWeight)
    }

    private func cleanDishName(_ name: String) -> String {
        var result = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // Убираем ведущую нумерацию вроде "1.", "2)"
        result = result.replacingOccurrences(
            of: #"^\d+[\.\)]\s*"#,
            with: "",
            options: .regularExpression
        )
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: ".-–—:/•* "))
        return result
    }

    private func detectCategoryHeader(_ line: String) -> MenuCategory? {
        let lower = line.lowercased().trimmingCharacters(in: .punctuationCharacters)
        switch lower {
        case "закуски", "холодные закуски", "горячие закуски":
            return .appetizers
        case "салаты":
            return .salads
        case "супы", "первые блюда":
            return .soups
        case "горячее", "основные блюда", "горячие блюда", "мясо и рыба", "стейки", "паста":
            return .mains
        case "гарниры":
            return .sides
        case "напитки", "бар", "кофе и чай", "лимонады":
            return .drinks
        case "десерты", "сладкое", "выпечка":
            return .desserts
        default:
            return nil
        }
    }

    private func isLikelyDishName(_ line: String) -> Bool {
        let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        return letters >= 3 && line.count <= 70
    }

    func guessCategory(for dishName: String) -> MenuCategory {
        let lower = dishName.lowercased()
        if lower.contains("салат") || lower.contains("цезарь") || lower.contains("греческий") || lower.contains("буратта") {
            return .salads
        }
        if lower.contains("суп") || lower.contains("борщ") || lower.contains("том ям") || lower.contains("бульон") || lower.contains("солянка") || lower.contains("уха") {
            return .soups
        }
        if lower.contains("тартар") || lower.contains("брускетта") || lower.contains("карпаччо") || lower.contains("паштет") || lower.contains("сыр") || lower.contains("антипасти") {
            return .appetizers
        }
        if lower.contains("гарнир") || lower.contains("пюре") || lower.contains("фри") || lower.contains("спаржа") || lower.contains("овощи гриль") {
            return .sides
        }
        if lower.contains("лимонад") || lower.contains("чай") || lower.contains("кофе") || lower.contains("эспрессо") || lower.contains("капучино") || lower.contains("морс") || lower.contains("сок") || lower.contains("вода") || lower.contains("коктейль") {
            return .drinks
        }
        if lower.contains("чизкейк") || lower.contains("тирамису") || lower.contains("торт") || lower.contains("мильфей") || lower.contains("мороженое") || lower.contains("фондан") || lower.contains("медовик") || lower.contains("десерт") {
            return .desserts
        }
        if lower.contains("стейк") || lower.contains("рибай") || lower.contains("паста") || lower.contains("лосось") || lower.contains("утка") || lower.contains("котлет") || lower.contains("филе") || lower.contains("бургер") || lower.contains("ризотто") {
            return .mains
        }
        return .other
    }

    // MARK: - Генератор демо-фото меню для мгновенного тестирования Vision OCR

    func generateDemoMenuImage() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let cgContext = context.cgContext
            UIColor.white.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.darkGray
            ]
            let lineAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.black
            ]

            let lines: [(String, Bool)] = [
                ("СЕЗОННОЕ МЕНЮ WORKHOLL", true),
                ("Закуски", true),
                ("Карпаччо из говядины с пармезаном 790 руб", false),
                ("Брускетта с ростбифом и трюфелем 650 р.", false),
                ("Салаты", true),
                ("Салат Нисуаз с тунцом 840 руб", false),
                ("Тёплый салат с телятиной 760 р.", false),
                ("Супы", true),
                ("Крем-суп из белых грибов 540 руб", false),
                ("Тыквенный суп с креветками 590 р.", false),
                ("Горячее", true),
                ("Медальоны из телятины с соусом Порто 1690 руб", false),
                ("Ризотто с белыми грибами 820 р.", false),
                ("Палтус на пару с муссом из пармезана 1390 руб", false),
                ("Напитки", true),
                ("Раф Лавандовый 380 руб", false),
                ("Лимонад Малина-Базилик 360 р.", false),
                ("Десерты", true),
                ("Шоколадный фондан с пломбиром 520 руб", false)
            ]

            var y: CGFloat = 60
            for (index, entry) in lines.enumerated() {
                let attrs = index == 0 ? titleAttrs : (entry.1 ? sectionAttrs : lineAttrs)
                let rect = CGRect(x: 60, y: y, width: size.width - 120, height: 48)
                (entry.0 as NSString).draw(in: rect, withAttributes: attrs)
                y += entry.1 ? 56 : 50
            }
        }
    }
}
