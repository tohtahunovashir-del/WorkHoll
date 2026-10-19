import SwiftUI

@main
struct WorkHollApp: App {
    init() {
        // Гарантируем инициализацию синглтона базы данных GRDB и выполнение миграций при старте
        _ = DatabaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
