//
//  StatsAnalysisFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// マイページの「分析」ボタンから開く、部位・種目ごとの回数/ボリューム/セット数をグラフで見る画面
@Reducer
struct StatsAnalysisFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.workoutHistory) var history
        var bodyPartChartFilter: BodyPart?
        var exerciseBodyPartFilter: BodyPart?
        var range: TrendRange = .oneMonth
        var periodOffset = 0
        var mode: StatsMode = .bodyPart
        var metric: StatsMetric = .count
        /// グラフの点をタップ・スワイプ、または←→で期間を選ぶまでは、下の部位ごとの内訳を出さない
        var hasSelectedPeriod = false

        /// ←→の移動量（periodOffset）を加味した、今選んでいる期間の基準日
        func referenceDate(calendar: Calendar, now: Date) -> Date {
            range.referenceDate(calendar: calendar, now: now, offset: periodOffset)
        }
    }

    enum Action {
        case bodyPartChartFilterTapped(BodyPart?)
        case bodyPartTapped(BodyPart)
        case delegate(Delegate)
        case exerciseBodyPartFilterTapped(BodyPart?)
        case exerciseTapped(Exercise.ID)
        case modeButtonTapped(StatsMode)
        case nextMetricButtonTapped
        case nextPeriodButtonTapped
        case periodOffsetSet(Int)
        case previousMetricButtonTapped
        case previousPeriodButtonTapped
        case rangeButtonTapped(TrendRange)

        @CasePathable
        enum Delegate: Equatable {
            case bodyPartTapped(BodyPart)
            case exerciseTapped(Exercise.ID)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .bodyPartChartFilterTapped(part):
                state.bodyPartChartFilter = part
                return .none

            case let .bodyPartTapped(part):
                return .send(.delegate(.bodyPartTapped(part)))

            case .delegate:
                return .none

            case let .exerciseBodyPartFilterTapped(part):
                state.exerciseBodyPartFilter = part
                return .none

            case let .exerciseTapped(id):
                return .send(.delegate(.exerciseTapped(id)))

            case let .modeButtonTapped(mode):
                state.mode = mode
                state.periodOffset = 0
                state.bodyPartChartFilter = nil
                state.hasSelectedPeriod = false
                return .none

            case .nextMetricButtonTapped:
                state.metric = state.metric.next
                return .none

            case .nextPeriodButtonTapped:
                state.periodOffset = max(0, state.periodOffset - 1)
                state.hasSelectedPeriod = true
                return .none

            case let .periodOffsetSet(offset):
                state.periodOffset = max(0, offset)
                state.hasSelectedPeriod = true
                return .none

            case .previousMetricButtonTapped:
                state.metric = state.metric.previous
                return .none

            case .previousPeriodButtonTapped:
                state.periodOffset += 1
                state.hasSelectedPeriod = true
                return .none

            case let .rangeButtonTapped(range):
                state.range = range
                state.periodOffset = 0
                state.bodyPartChartFilter = nil
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
            Section {
                ModeTabBar(
                    selected: store.mode,
                    action: { store.send(.modeButtonTapped($0), animation: .default) }
                )
                .listRowInsets(EdgeInsets())
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    switch store.mode {
                    case .bodyPart:
                        CaptionedArrowNavigator(
                            caption: "左右の矢印をタップすると指標を切り替えられます",
                            label: store.metric.label,
                            canGoNext: true,
                            onPrevious: { store.send(.previousMetricButtonTapped, animation: .default) },
                            onNext: { store.send(.nextMetricButtonTapped, animation: .default) }
                        )

                        Picker("期間", selection: Binding(
                            get: { store.range },
                            set: { store.send(.rangeButtonTapped($0), animation: .default) }
                        )) {
                            ForEach(TrendRange.allCases, id: \.self) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        BodyPartFilterChips(
                            selected: store.bodyPartChartFilter,
                            action: { store.send(.bodyPartChartFilterTapped($0), animation: .default) }
                        )

                        let buckets = trendBuckets(calendar: calendar)
                        TrendLineChart(
                            data: buckets,
                            seriesLabel: store.metric.label,
                            label: \.label,
                            value: \.value,
                            selectedLabel: selectedBucketLabelBinding(buckets: buckets),
                            canNavigatePeriod: canNavigatePeriod,
                            onSwipePrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                            onSwipeNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                        )
                        .frame(height: 180)

                        if canNavigatePeriod {
                            CaptionedArrowNavigator(
                                caption: "点をタップ、または左右にスワイプすると期間を切り替えられます",
                                label: periodRangeLabel(calendar: calendar),
                                canGoNext: store.periodOffset > 0,
                                onPrevious: { store.send(.previousPeriodButtonTapped, animation: .default) },
                                onNext: { store.send(.nextPeriodButtonTapped, animation: .default) }
                            )
                        }

                    case .exercise:
                        BodyPartFilterChips(
                            selected: store.exerciseBodyPartFilter,
                            action: { store.send(.exerciseBodyPartFilterTapped($0), animation: .default) }
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                if store.mode == .bodyPart {
                    Text("部位ごとの\(store.metric.label)")
                } else {
                    Text("種目")
                }
            }

            switch store.mode {
            case .bodyPart:
                if store.hasSelectedPeriod {
                    let allStats = store.history.bodyPartStats(metric: store.metric, in: store.range.bucketPeriod, calendar: calendar, now: referenceDate(calendar: calendar))
                    let filteredStats = store.bodyPartChartFilter.map { filter in allStats.filter { $0.part == filter } } ?? allStats
                    let stats = filteredStats.filter { $0.value > 0 }
                    if !stats.isEmpty {
                        Section {
                            ForEach(stats, id: \.part) { item in
                                Button {
                                    store.send(.bodyPartTapped(item.part))
                                } label: {
                                    BodyPartStatsRow(part: item.part, value: item.value, metric: store.metric)
                                }
                                .foregroundStyle(.primary)
                            }
                        } footer: {
                            Text("部位をタップするとその部位の種目内訳を見られます")
                        }
                    }
                }

            case .exercise:
                if !recentExercises.isEmpty {
                    Section {
                        ForEach(recentExercises) { exercise in
                            Button {
                                store.send(.exerciseTapped(exercise.id))
                            } label: {
                                ExerciseListRow(exercise: exercise)
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("最近の種目")
                    }
                }

                let exercises = Exercise.presets.filter { store.exerciseBodyPartFilter == nil || $0.bodyPart == store.exerciseBodyPartFilter }
                Section {
                    ForEach(exercises) { exercise in
                        Button {
                            store.send(.exerciseTapped(exercise.id))
                        } label: {
                            ExerciseListRow(exercise: exercise)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("種目をタップすると推移などの詳細を見られます")
                }
            }
        }
        .navigationTitle("分析")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 直近1回のトレーニングに含まれる種目（部位の絞り込みがあればそれも適用する）
    private var recentExercises: [Exercise] {
        let exercises = store.history.recentExercises
        return store.exerciseBodyPartFilter.map { filter in exercises.filter { $0.bodyPart == filter } } ?? exercises
    }

    /// 全期間は区切りがないので←→で移動できない
    private var canNavigatePeriod: Bool {
        store.range != .all
    }

    /// ←→の移動量を加味した基準日
    private func referenceDate(calendar: Calendar) -> Date {
        referenceDate(calendar: calendar, offset: store.periodOffset)
    }

    /// 指定した個数分、今から遡った基準日
    private func referenceDate(calendar: Calendar, offset: Int) -> Date {
        store.range.referenceDate(calendar: calendar, now: .now, offset: offset)
    }

    /// 推移グラフに並べる区間の値（古い順）。選んでいる期間に応じた本数
    private func trendBuckets(calendar: Calendar) -> [TrendBucket] {
        let bucketCount = store.range.bucketCount
        return (0..<bucketCount).map { i in
            let offset = store.periodOffset + (bucketCount - 1 - i)
            let reference = referenceDate(calendar: calendar, offset: offset)
            let stats = store.history.bodyPartStats(metric: store.metric, in: store.range.bucketPeriod, calendar: calendar, now: reference)
            let value = store.bodyPartChartFilter.map { part in stats.first { $0.part == part }?.value ?? 0 }
                ?? stats.reduce(0) { $0 + $1.value }
            return TrendBucket(offset: offset, label: bucketLabel(for: reference, calendar: calendar), value: value > 0 ? value : nil)
        }
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

/// 部位・種目を切り替えるタブ。選んでいる方に下線がつく
private struct ModeTabBar: View {
    let selected: StatsMode
    let action: (StatsMode) -> Void

    var body: some View {
        HStack(spacing: 24) {
            ForEach(StatsMode.allCases, id: \.self) { mode in
                Button {
                    action(mode)
                } label: {
                    VStack(spacing: 8) {
                        Text(mode.label)
                            .font(.headline)
                            .foregroundStyle(selected == mode ? .primary : .secondary)
                        Rectangle()
                            .fill(selected == mode ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

/// 推移グラフの1本分のデータ。記録がない区間は `value` が nil
private struct TrendBucket: Equatable, Identifiable {
    let offset: Int
    let label: String
    let value: Double?

    var id: Int { offset }
}

private struct BodyPartStatsRow: View {
    let part: BodyPart
    let value: Double
    let metric: StatsMetric

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(part.color)
                .frame(width: 10, height: 10)
            Text(part.label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(metric.formattedValue(value))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

/// 種目名と部位だけを出す、指標・期間に依存しない行
private struct ExerciseListRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseIcon(exercise: exercise, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                Text(exercise.bodyPart.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
