//
//  WorkoutDetailFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 保存した記録の詳細。ここから編集・削除する
@Reducer
struct WorkoutDetailFeature {
    @Reducer
    enum Destination {
        case deleteAlert(AlertState<DeleteAlert>)
        case edit(EditWorkoutFeature)

        @CasePathable
        enum DeleteAlert: Equatable {
            case confirmButtonTapped
        }
    }

    @ObservableState
    struct State: Equatable {
        let workoutID: Workout.ID
        @Presents var destination: Destination.State?
        @Shared(.workoutHistory) var history

        var workout: Workout? { history[id: workoutID] }

        init(workoutID: Workout.ID) {
            self.workoutID = workoutID
        }
    }

    enum Action {
        case deleteButtonTapped
        case destination(PresentationAction<Destination.Action>)
        case editButtonTapped
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped:
                guard let workout = state.workout else { return .none }
                state.destination = .deleteAlert(.deleteWorkout(workout, calendar: calendar, action: .confirmButtonTapped))
                return .none

            case .destination(.presented(.deleteAlert(.confirmButtonTapped))):
                _ = state.$history.withLock { [id = state.workoutID] in $0.remove(id: id) }
                return .run { _ in await dismiss() }

            case let .destination(.presented(.edit(.delegate(.saved(workout))))):
                // 開始日時を変えても新しい順が崩れないよう、並べ直す
                state.$history.withLock {
                    $0[id: workout.id] = workout
                    $0.sort { $0.startedAt > $1.startedAt }
                }
                return .none

            case .destination:
                return .none

            case .editButtonTapped:
                guard let workout = state.workout else { return .none }
                state.destination = .edit(EditWorkoutFeature.State(workout: workout))
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension WorkoutDetailFeature.Destination.State: Equatable {}

struct WorkoutDetailView: View {
    @Bindable var store: StoreOf<WorkoutDetailFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        Group {
            if let workout = store.workout {
                content(workout)
                    .navigationTitle(workout.startedAt.dayTitle(calendar: calendar))
            } else {
                ContentUnavailableView("記録がありません", systemImage: "calendar")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.workout != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編集") { store.send(.editButtonTapped) }
                }
            }
        }
        .alert($store.scope(state: \.destination?.deleteAlert, action: \.destination.deleteAlert))
        .fullScreenCover(item: $store.scope(state: \.destination?.edit, action: \.destination.edit)) { store in
            EditWorkoutView(store: store)
        }
    }

    private func content(_ workout: Workout) -> some View {
        List {
            Section {
                HStack(alignment: .top) {
                    SummaryItem(title: "時間", value: workout.timeRange(calendar: calendar))
                    SummaryItem(title: "長さ", value: workout.durationMinutes.map { "\($0)分" } ?? "-")
                    SummaryItem(title: "セット", value: "\(workout.exercises.count)種目 \(workout.recordedSetCount)セット")
                }
                BodyPartBadges(parts: workout.bodyParts)
            }

            ForEach(workout.exercises) { entry in
                Section(entry.exercise.name) {
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)
                            Text(set.weight.map { "\(WorkoutSet.formatted(weight: $0)) kg" } ?? "-")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(set.reps.map { "\($0) 回" } ?? "-")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.body.weight(.semibold).monospacedDigit())
                    }
                }
            }

            Section {
                Button("この記録を削除", role: .destructive) {
                    store.send(.deleteButtonTapped)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct SummaryItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
