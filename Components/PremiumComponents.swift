import SwiftUI
import UIKit

// MARK: - Премиальная карточка с тенью и скруглением

struct PremiumCard<Content: View>: View {
    var padding: CGFloat = 16
    var borderColor: Color = AppTheme.subtleBorder
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Крупная основная кнопка (минимум 52pt высоты >= 44x44pt HIG)

struct PrimaryActionButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = AppTheme.primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.medium)
            action()
        } label: {
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .background(isDisabled ? Color.gray.opacity(0.45) : color)
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonCornerRadius, style: .continuous))
            .shadow(color: (isDisabled ? Color.clear : color.opacity(0.28)), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Вторичная кнопка (минимум 48pt высоты >= 44x44pt HIG)

struct SecondaryActionButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = AppTheme.primary
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.impact(.light)
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppConstants.minimumTouchTarget)
            .padding(.horizontal, 14)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppConstants.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Бейдж статуса

struct StatusBadge: View {
    let text: String
    var icon: String? = nil
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

// MARK: - Интерактивный чип фильтра (высота >= 44pt по iOS HIG)

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    var activeColor: Color = AppTheme.primary
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(isSelected ? activeColor : AppTheme.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? activeColor : AppTheme.subtleBorder, lineWidth: 1)
            )
            .shadow(color: isSelected ? activeColor.opacity(0.25) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Карточка метрики

struct MetricSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        PremiumCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(tint)
                    }
                    Spacer()
                }
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tint)
                }
            }
        }
    }
}

// MARK: - Пустое состояние экрана

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        PremiumCard(padding: 28) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 68, height: 68)
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(AppTheme.primary)
                }
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if let buttonTitle, let action {
                    PrimaryActionButton(title: buttonTitle, icon: "plus.circle.fill", action: action)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Системное окно Поделиться (UIActivityViewController)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Камера / Фотогалерея (UIImagePickerController для iOS 16+)

struct CameraImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .camera
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
