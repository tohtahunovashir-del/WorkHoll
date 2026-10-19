import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var statsVM: StatsViewModel

    @State private var showExportSheet = false
    @State private var reportText: String = ""

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    kpiGrid

                    activePipelineCard

                    topDishesCard

                    paymentMethodsCard

                    PrimaryActionButton(
                        title: "Экспортировать Z-отчёт смены",
                        icon: "square.and.arrow.up.fill",
                        color: AppTheme.primary
                    ) {
                        reportText = statsVM.generateShiftReportText()
                        showExportSheet = true
                    }
                }
                .padding(16)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Аналитика смены")
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(activityItems: [reportText])
            }
        }
    }

    private var kpiGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            MetricSummaryCard(
                title: "Выручка сегодня",
                value: statsVM.todayRevenue.formattedCurrency,
                subtitle: "Закрыто чеков: \(statsVM.todayClosedCount)",
                icon: "rublesign.circle.fill",
                tint: AppTheme.success
            )

            MetricSummaryCard(
                title: "Средний чек",
                value: statsVM.averageCheck.formattedCurrency,
                subtitle: "За текущую смену",
                icon: "chart.line.uptrend.xyaxis",
                tint: AppTheme.primary
            )

            MetricSummaryCard(
                title: "Чаевые смены",
                value: statsVM.todayTips.formattedCurrency,
                subtitle: "Начислено официанту",
                icon: "heart.circle.fill",
                tint: AppTheme.accent
            )

            MetricSummaryCard(
                title: "За 7 дней",
                value: statsVM.weekRevenue.formattedCurrency,
                subtitle: "Месяц: \(statsVM.monthRevenue.formattedCurrency)",
                icon: "calendar.badge.clock",
                tint: AppTheme.vipPurple
            )
        }
    }

    private var activePipelineCard: some View {
        PremiumCard(borderColor: AppTheme.primary.opacity(0.3)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Открытые столы (в работе)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(statsVM.activePipelineAmount.formattedCurrency)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppTheme.primary)
            }
        }
    }

    private var topDishesCard: some View {
        let maxCount = max(1, statsVM.topDishes.map(\.count).max() ?? 1)

        return PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Топ продаваемых позиций")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppTheme.accent)
                }

                if statsVM.topDishes.isEmpty {
                    Text("Данные появятся после добавления позиций в заказы.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(statsVM.topDishes.enumerated()), id: \.element.id) { index, dish in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(index + 1). \(dish.name)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(dish.count) шт. • \(dish.revenue.formattedCurrency)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.08))
                                        .frame(height: 8)
                                    Capsule()
                                        .fill(AppTheme.primary)
                                        .frame(
                                            width: geo.size.width * CGFloat(dish.count) / CGFloat(maxCount),
                                            height: 8
                                        )
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
    }

    private var paymentMethodsCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Способы оплаты (закрытые чеки)")
                    .font(.system(size: 17, weight: .bold))

                ForEach(statsVM.paymentBreakdown) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.method.icon)
                            .foregroundColor(AppTheme.primary)
                            .frame(width: 24)
                        Text(item.method.rawValue)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        Text("\(item.count) чек.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(item.amount.formattedCurrency)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
