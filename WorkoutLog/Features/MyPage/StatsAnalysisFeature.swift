//
//  StatsAnalysisFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// マイページの「分析」で種目一覧から種目を選ぶと開く、その種目の推定1RMをグラフで見る画面
@Reducer
struct StatsAnalysisFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.workoutHistory) var history
        var exercise: Exercise
        var range: TrendRange = .oneMonth
        var periodOffset = 0
        /// グラフの点をタップ・スワイプ、または←→で期間を選ぶまでは、下のベストセットを出さない
        var hasSelectedPeriod = false

        /// 期間の基準にする「今」。実際の今日ではなく、その種目を最後にやった日時を使う
        /// （しばらく記録していない種目だと、今日からの1ヶ月では直近の記録が入らないため）
        var latestRecordDate: Date {
            for workout in history {
                let hasExercise = workout.exercises.contains { entry in entry.exercise.id == exercise.id }
                if hasExercise { return workout.startedAt }
            }
            return Date()
        }

        /// ←→の移動量（periodOffset）を加味した、今選んでいる期間の基準日
        func referenceDate(calendar: Calendar, offset: Int? = nil) -> Date {
            range.referenceDate(calendar: calendar, now: latestRecordDate, offset: offset ?? periodOffset)
        }
    }

    enum Action {
        case nextPeriodButtonTapped
        case periodOffsetSet(Int)
        case previousPeriodButtonTapped
        case rangeButtonTapped(TrendRange)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextPeriodButtonTapped:
                state.periodOffset = max(0, state.periodOffset - 1)
                state.hasSelectedPeriod = true
                return .none

            case let .periodOffsetSet(offset):
                state.periodOffset = max(0, offset)
                state.hasSelectedPeriod = true
                return .none

            case .previousPeriodButtonTapped:
                state.periodOffset += 1
                state.hasSelectedPeriod = true
                return .none

            case let .rangeButtonTapped(range):
                state.range = range
                state.periodOffset = 0
                state.hasSelectedPeriod = false
                return .none
            }
        }
    }
}

struct StatsAnalysisView: View {
    @Bindable var store: StoreOf<StatsAnalysisFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        List {
            bestEverSection

            Section("推定1RMの推移") {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("期間", selection: Binding(
                        get: { store.range },
                        set: { store.send(.rangeButtonTapped($0), animation: .default) }
                    )) {
                        ForEach(TrendRange.allCases, id: \.self) { range in
                            Text(range.label).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    let buckets = trendBuckets(calendar: calendar)
                    TrendLineChart(
                        data: buckets,
                        seriesLabel: "推定1RM",
                        label: \.label,
                        value: \.value,
                        selectedLabel: selectedBucketLabelBinding(buckets: buckets),
                        canNavigatePeriod: canNavigatePeriod,
                        onSwipePrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                        onSwipeNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                    )
                    .frame(height: 180)

                    if let growth = growth(buckets: buckets) {
                        GrowthLabel(first: growth.first, last: growth.last)
                    }

                    if canNavigatePeriod {
                        CaptionedArrowNavigator(
                            caption: "点をタップ、または左右にスワイプすると期間を切り替えられます",
                            label: periodRangeLabel(calendar: calendar),
                            canGoNext: store.periodOffset > 0,
                            onPrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                            onNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            if store.hasSelectedPeriod,
               let entry = store.history.best1RMEntry(of: store.exercise.id, in: store.range.bucketPeriod, calendar: calendar, now: referenceDate(calendar: calendar)) {
                Section("この期間のベスト") {
                    Best1RMRow(entry: entry, calendar: calendar)
                }
            }
        }
        .navigationTitle("分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 種目名と、全期間を通した自己ベストを出すセクション
    @ViewBuilder
    private var bestEverSection: some View {
        let bestEntry = store.history.best1RMEntry(of: store.exercise.id, in: .all, calendar: calendar, now: .now)
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.exercise.name)
                    .font(.title2.weight(.bold))

                if let bestEntry {
                    Best1RMRow(entry: bestEntry, calendar: calendar)
                } else {
                    Text("まだ記録がありません")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("自己ベスト")
        }
    }

    /// 全期間は区切りがないので←→で移動できない
    private var canNavigatePeriod: Bool {
        store.range != .all
    }

    /// ←→の移動量を加味した基準日
    private func referenceDate(calendar: Calendar) -> Date {
        referenceDate(calendar: calendar, offset: store.periodOffset)
    }

    /// 指定した個数分、最後にやった日から遡った基準日
    private func referenceDate(calendar: Calendar, offset: Int) -> Date {
        store.range.referenceDate(calendar: calendar, now: store.latestRecordDate, offset: offset)
    }

    /// 推移グラフに並べる区間の値（古い順）。選んでいる期間に応じた本数
    private func trendBuckets(calendar: Calendar) -> [TrendBucket] {
        let bucketCount = store.range.bucketCount
        return (0..<bucketCount).map { i in
            let offset = store.periodOffset + (bucketCount - 1 - i)
            let reference = referenceDate(calendar: calendar, offset: offset)
            let value = store.history.best1RM(of: store.exercise.id, in: store.range.bucketPeriod, calendar: calendar, now: reference)
            return TrendBucket(offset: offset, label: bucketLabel(for: reference, calendar: calendar), value: value)
        }
    }

    /// 表示している区間での伸び（最初に記録がある点から最後に記録がある点まで）。点が1つ以下なら nil
    private func growth(buckets: [TrendBucket]) -> (first: Double, last: Double)? {
        let values = buckets.compactMap(\.value)
        guard let first = values.first, let last = values.last, values.count >= 2 else { return nil }
        return (first, last)
    }

    /// 推移グラフの棒のタップを、選んでいる期間（periodOffset）と同期させる
    private func selectedBucketLabelBinding(buckets: [TrendBucket]) -> Binding<String?> {
        Binding(
            get: { buckets.first { $0.offset == store.periodOffset }?.label },
            set: { newLabel in
                guard let newLabel, let bucket = buckets.first(where: { $0.label == newLabel }) else { return }
                store.send(.periodOffsetSet(bucket.offset), animation: .default)
            }
        )
    }

    /// 「10/4」「9月」「2026年」のような、推移グラフの棒につけるラベル
    private func bucketLabel(for date: Date, calendar: Calendar) -> String {
        store.range.bucketPeriod.dateLabel(for: date, calendar: calendar)
    }

    /// 「10/25〜10/31」のような、今選んでいる期間の範囲ラベル（具体的な日付で出す）
    private func periodRangeLabel(calendar: Calendar) -> String {
        store.range.periodRangeLabel(referenceDate: referenceDate(calendar: calendar), calendar: calendar)
    }
}

/// 表示している区間での伸びをkgと%で出す。「+15.0kg（+12.1%）」のように、プラスなら緑、マイナスなら赤
private struct GrowthLabel: View {
    let first: Double
    let last: Double

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text("\(sign)\(WorkoutSet.formatted(weight: abs(diff)))kg（\(sign)\(String(format: "%.1f", abs(percent)))%）")
        }
        .font(.title3.weight(.bold))
        .foregroundStyle(diff >= 0 ? Color.green : Color.red)
    }

    private var diff: Double { last - first }
    private var percent: Double { first == 0 ? 0 : diff / first * 100 }
    private var sign: String { diff >= 0 ? "+" : "-" }
}

/// 推移グラフの1本分のデータ。記録がない区間は `value` が nil
private struct TrendBucket: Equatable, Identifiable {
    let offset: Int
    let label: String
    let value: Double?

    var id: Int { offset }
}

private struct Best1RMRow: View {
    let entry: Best1RMEntry
    let calendar: Calendar

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.subheadline.weight(.semibold))
                if let weight = entry.set.weight, let reps = entry.set.reps {
                    Text("\(WorkoutSet.formatted(weight: weight))kg × \(reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("推定1RM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(WorkoutSet.formatted(weight: entry.value))kg")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var dateLabel: String {
        let components = calendar.dateComponents([.month, .day], from: entry.date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }
}
