import SwiftUI

struct MainTabView: View {
    @StateObject private var tableVM = TableMapViewModel()
    @StateObject private var ordersVM = OrdersViewModel()
    @StateObject private var menuVM = MenuViewModel()
    @StateObject private var statsVM = StatsViewModel()

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TableMapView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Зал", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            OrdersView()
                .tabItem {
                    Label("Заказы", systemImage: "list.clipboard.fill")
                }
                .badge(ordersVM.activeOrdersCount)
                .tag(1)

            MenuView()
                .tabItem {
                    Label("Меню", systemImage: "menucard.fill")
                }
                .tag(2)

            ScannerView()
                .tabItem {
                    Label("OCR Сканер", systemImage: "doc.text.viewfinder")
                }
                .tag(3)

            StatsView()
                .tabItem {
                    Label("Аналитика", systemImage: "chart.bar.xaxis")
                }
                .tag(4)
        }
        .tint(AppTheme.primary)
        .environmentObject(tableVM)
        .environmentObject(ordersVM)
        .environmentObject(menuVM)
        .environmentObject(statsVM)
    }
}
