//
//  ExerciseTrendFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// 種目ごとの自己ベストをタップして開く、重量の推移の詳細画面
@Reducer
struct ExerciseTrendFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let exercise: Exercise
        @Shared(.workoutHistory) var history
        var metric: WeightMetric
        var range: TrendRange = .oneMonth
        var periodOffset = 0

        var id: Exercise.ID { exercise.id }

        init(exercise: Exercise) {
            self.exercise = exercise
            metric = exercise.supportsOneRepMax ? .oneRepMax : .volume
        }
    }

    enum Action {
        case metricButtonTapped(WeightMetric)
        case nextPeriodButtonTapped
        case periodOffsetSet(Int)
        case previousPeriodButtonTapped
        case rangeButtonTapped(TrendRange)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .metricButtonTapped(metric):
                state.metric = metric
                return .none

            case .nextPeriodButtonTapped:
                state.periodOffset = max(0, state.periodOffset - 1)
                return .none

            case let .periodOffsetSet(offset):
                state.periodOffset = max(0, offset)
                return .none

            case .previousPeriodButtonTapped:
                state.periodOffset += 1
                return .none

            case let .rangeButtonTapped(range):
                state.range = range
                state.periodOffset = 0
                return .none
            }
        }
    }
}

struct ExerciseTrendView: View {
    @Bindable var store: StoreOf<ExerciseTrendFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        let exercise = store.exercise
        let reference = referenceDate(calendar: calendar)
        let trend = trend(calendar: calendar)
        let best = store.history.exerciseBests.first { $0.exercise.id == exercise.id }

        List {
            if let best {
                Section("自己ベスト") {
                    HStack {
                        Text("\(WorkoutSet.formatted(weight: best.weight))kg × \(best.reps)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Spacer()
                        Text(best.date.dayTitle(calendar: calendar))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section {
                HStack(spacing: 12) {
                    ExerciseStatCard(label: StatsMetric.count.label, value: statsValue(for: exercise, metric: .count, referenceDate: reference))
                    ExerciseStatCard(label: StatsMetric.volume.label, value: statsValue(for: exercise, metric: .volume, referenceDate: reference))
                    ExerciseStatCard(label: StatsMetric.setCount.label, value: statsValue(for: exercise, metric: .setCount, referenceDate: reference))
                }
                .padding(.vertical, 2)
            } header: {
                Text("\(store.range.label)の実績")
            }

            Section {
                VStack(alignment: .leading, spacing: 14) {
                    if exercise.supportsOneRepMax {
                        Picker("指標", selection: Binding(
                            get: { store.metric },
                            set: { store.send(.metricButtonTapped($0), animation: .default) }
                        )) {
                            ForEach(WeightMetric.allCases, id: \.self) { metric in
                                Text(metric.label).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Picker("期間", selection: Binding(
                        get: { store.range },
                        set: { store.send(.rangeButtonTapped($0), animation: .default) }
                    )) {
                        ForEach(TrendRange.allCases, id: \.self) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 2) {
                        if let latest = trend.latestTwoValues {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(WorkoutSet.formatted(weight: latest.current))kg")
                                    .font(.title2.weight(.bold).monospacedDigit())
                                if let previous = latest.previous, previous > 0 {
                                    let change = Int(((latest.current - previous) / previous * 100).rounded())
                                    Text(change >= 0 ? "+\(change)%" : "\(change)%")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(change >= 0 ? .green : .red)
                                    Text(store.range.comparisonLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Text(store.metric.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TrendLineChart(
                        data: trend,
                        seriesLabel: "重量",
                        label: \.label,
                        value: \.value,
                        selectedLabel: selectedLabelBinding(trend: trend),
                        canNavigatePeriod: canNavigatePeriod,
                        onSwipePrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                        onSwipeNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                    )
                    .frame(height: 160)

                    if canNavigatePeriod {
                        CaptionedArrowNavigator(
                            caption: "点をタップ、または左右にスワイプすると期間を切り替えられます",
                            label: store.range.periodRangeLabel(referenceDate: reference, calendar: calendar),
                            canGoNext: store.periodOffset > 0,
                            onPrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                            onNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("重量の推移")
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 全期間は区切りがないので←→で移動できない
    private var canNavigatePeriod: Bool {
        store.range != .all
    }

    /// ←→の移動量を加味した基準日
    private func referenceDate(calendar: Calendar) -> Date {
        store.range.referenceDate(calendar: calendar, now: .now, offset: store.periodOffset)
    }

    /// 重量の推移グラフに並べる区間の値（古い順）。選んでいる期間に応じた本数
    private func trend(calendar: Calendar) -> [WeightTrendPoint] {
        store.history.weightTrend(for: store.exercise, metric: store.metric, range: store.range, calendar: calendar, now: referenceDate(calendar: calendar))
    }

    /// 選んでいる期間全体の、その種目の回数・ボリューム・セット数
    private func statsValue(for exercise: Exercise, metric: StatsMetric, referenceDate: Date) -> String {
        let value = store.history.exerciseStats(metric: metric, in: store.range, calendar: calendar, referenceDate: referenceDate)
            .first { $0.exercise.id == exercise.id }?.value ?? 0
        return metric.formattedValue(value)
    }

    /// 推移グラフの点のタップを、選んでいる期間（periodOffset）と同期させる
    private func selectedLabelBinding(trend: [WeightTrendPoint]) -> Binding<String?> {
        Binding(
            get: { trend.last?.label },
            set: { newLabel in
                guard let newLabel, let index = trend.firstIndex(where: { $0.label == newLabel }) else { return }
                let bucketCount = store.range.bucketCount
                store.send(.periodOffsetSet(store.periodOffset + (bucketCount - 1 - index)), animation: .default)
            }
        )
    }
}

private struct ExerciseStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
