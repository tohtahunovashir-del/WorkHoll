import SwiftUI
import PhotosUI

struct ScannerView: View {
    @EnvironmentObject private var menuVM: MenuViewModel

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCameraPicker: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    scannerHeroCard

                    actionButtonsRow

                    if menuVM.isScanning {
                        PremiumCard {
                            HStack(spacing: 14) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Распознавание текста через Vision...")
                                        .font(.system(size: 15, weight: .bold))
                                    Text("Применяется Regex-парсер позиций и цен")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    if let status = menuVM.ocrStatusMessage {
                        PremiumCard(borderColor: AppTheme.primary.opacity(0.3)) {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(AppTheme.primary)
                                    .font(.title3)
                                Text(status)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }

                    if !menuVM.recognizedItems.isEmpty {
                        recognizedItemsList
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("OCR Сканер меню")
            .sheet(isPresented: $showCameraPicker) {
                CameraImagePicker(sourceType: .camera) { image in
                    menuVM.scanMenuImage(image)
                }
            }
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        menuVM.scanMenuImage(image)
                    }
                }
            }
        }
    }

    private var scannerHeroCard: some View {
        PremiumCard {
            VStack(spacing: 14) {
                if let image = menuVM.scannedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.primary.opacity(0.08))
                            .frame(height: 190)

                        VStack(spacing: 10) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundColor(AppTheme.primary)
                            Text("Интеллектуальный парсер меню")
                                .font(.system(size: 17, weight: .bold))
                            Text("Сфотографируйте печатное меню или загрузите снимок из галереи — Vision распознает блюда и цены автоматически.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.primary)
                    Text("Regex: ^(.+?)\\s+(\\d{2,5})\\s*(руб|р\\.?)?$")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var actionButtonsRow: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                PrimaryActionButton(
                    title: "Камера",
                    icon: "camera.fill",
                    color: AppTheme.primary
                ) {
                    showCameraPicker = true
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Галерея")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonCornerRadius, style: .continuous))
                    .shadow(color: AppTheme.accent.opacity(0.28), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }

            SecondaryActionButton(
                title: "Протестировать Vision OCR на демо-меню",
                icon: "wand.and.stars"
            ) {
                menuVM.runDemoOCRScan()
            }
        }
    }

    private var recognizedItemsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Распознанные блюда (\(menuVM.recognizedItems.count))")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("Выбрано: \(menuVM.selectedOCRIds.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.primary)
            }

            ForEach(menuVM.recognizedItems) { item in
                OCRRecognizedItemCard(
                    item: item,
                    isSelected: menuVM.selectedOCRIds.contains(item.id),
                    onToggleSelect: {
                        menuVM.toggleOCRSelection(item)
                    },
                    onUpdate: { updated in
                        menuVM.updateRecognizedItem(updated)
                    }
                )
            }

            PrimaryActionButton(
                title: "Импортировать в меню (\(menuVM.selectedOCRIds.count))",
                icon: "square.and.arrow.down.fill",
                color: AppTheme.success,
                isDisabled: menuVM.selectedOCRIds.isEmpty
            ) {
                menuVM.importSelectedOCRItems()
            }
        }
    }
}

// MARK: - Карточка распознанной позиции (с возможностью правки перед импортом)

struct OCRRecognizedItemCard: View {
    let item: MenuItem
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onUpdate: (MenuItem) -> Void

    var body: some View {
        PremiumCard(
            padding: 14,
            borderColor: isSelected ? AppTheme.primary.opacity(0.4) : AppTheme.subtleBorder
        ) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    onToggleSelect()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? AppTheme.primary : .secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    TextField(
                        "Название блюда",
                        text: Binding(
                            get: { item.name },
                            set: { newName in
                                var copy = item
                                copy.name = newName
                                onUpdate(copy)
                            }
                        )
                    )
                    .font(.system(size: 16, weight: .bold))
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            TextField(
                                "Цена",
                                text: Binding(
                                    get: { "\(Int(item.price))" },
                                    set: { newPrice in
                                        var copy = item
                                        if let p = Double(newPrice) {
                                            copy.price = p
                                            onUpdate(copy)
                                        }
                                    }
                                )
                            )
                            .keyboardType(.numberPad)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 72)

                            Text("₽")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .frame(minHeight: 40)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Spacer()

                        Menu {
                            ForEach(MenuCategory.allCases) { cat in
                                Button {
                                    var copy = item
                                    copy.category = cat
                                    onUpdate(copy)
                                } label: {
                                    Label(cat.rawValue, systemImage: cat.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: item.category.icon)
                                Text(item.category.rawValue)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 40)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }
}
