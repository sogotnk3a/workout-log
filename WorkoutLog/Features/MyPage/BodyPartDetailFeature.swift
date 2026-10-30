//
//  BodyPartDetailFeature.swift
//  WorkoutLog
//

import Charts
import ComposableArchitecture
import SwiftUI

/// 分析画面で部位をタップして開く、その部位の種目内訳
@Reducer
struct BodyPartDetailFeature {
    @ObservableState
    struct State: Equatable, Identifiable {
        let part: BodyPart
        @Shared(.workoutHistory) var history
        var range: TrendRange = .oneMonth
        var metric: StatsMetric = .count
        /// 集計の基準日。分析画面で←→で遡っていた期間をそのまま引き継ぐために、呼び出し側が明示的に渡す
        var referenceDate = Date.distantPast

        var id: BodyPart { part }
    }

    enum Action {
        case delegate(Delegate)
        case exerciseTapped(Exercise.ID)
        case nextMetricButtonTapped
        case previousMetricButtonTapped
        case rangeButtonTapped(TrendRange)

        @CasePathable
        enum Delegate: Equatable {
            case exerciseTapped(Exercise.ID)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .delegate:
                return .none

            case let .exerciseTapped(id):
                return .send(.delegate(.exerciseTapped(id)))

            case .nextMetricButtonTapped:
                state.metric = state.metric.next
                return .none

            case .previousMetricButtonTapped:
                state.metric = state.metric.previous
                return .none

            case let .rangeButtonTapped(range):
                state.range = range
                return .none
            }
        }
    }
}

struct BodyPartDetailView: View {
    @Bindable var store: StoreOf<BodyPartDetailFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        let stats = store.history.exerciseStats(metric: store.metric, in: store.range.bucketPeriod, calendar: calendar, now: store.referenceDate)
            .filter { $0.exercise.bodyPart == store.part && $0.value > 0 }

        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
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

                    if stats.isEmpty {
                        Text("この期間の記録はありません")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(stats, id: \.exercise.id) { item in
                            BarMark(
                                x: .value(store.metric.label, item.value),
                                y: .value("種目", item.exercise.name)
                            )
                            .foregroundStyle(store.part.color)
                            .annotation(position: .trailing) {
                                Text(store.metric.formattedValue(item.value))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: CGFloat(max(stats.count, 1)) * 40 + 10)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("\(store.part.label)の種目内訳")
            }

            if !stats.isEmpty {
                Section {
                    ForEach(stats, id: \.exercise.id) { item in
                        Button {
                            store.send(.exerciseTapped(item.exercise.id))
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseIcon(exercise: item.exercise, size: 32)
                                Text(item.exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(store.metric.formattedValue(item.value))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("種目をタップすると重量の推移を見られます")
                }
            }
        }
        .navigationTitle(store.part.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}
