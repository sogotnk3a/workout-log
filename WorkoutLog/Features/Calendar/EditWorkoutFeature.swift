//
//  EditWorkoutFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 保存した記録を編集する画面。記録画面と同じく、種目一覧から種目ごとの入力ページに進む。
/// 写しを編集し、「保存」を押したときだけ元の記録に反映する
@Reducer
struct EditWorkoutFeature {
    @Reducer
    enum Destination {
        case exercisePicker(ExercisePickerFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var path = StackState<ExerciseSetsFeature.State>()
        @Shared var workout: Workout
        /// 編集前の開始日時。入力ページの「前回」に、この記録より前のトレーニングだけを出すため
        let originalStartedAt: Date

        init(workout: Workout) {
            _workout = Shared(value: workout)
            originalStartedAt = workout.startedAt
        }

        /// 回数を入力したセットが1つもなければ保存できない
        var canSave: Bool { !workout.recordedOnly.exercises.isEmpty }
    }

    enum Action {
        case addExerciseButtonTapped
        case cancelButtonTapped
        case delegate(Delegate)
        case deleteExerciseSwiped(WorkoutExercise.ID)
        case destination(PresentationAction<Destination.Action>)
        case endedAtChanged(Date)
        case exerciseTapped(WorkoutExercise.ID)
        case exercisesMoved(IndexSet, Int)
        case path(StackActionOf<ExerciseSetsFeature>)
        case saveButtonTapped
        case startedAtChanged(Date)

        @CasePathable
        enum Delegate: Equatable {
            case saved(Workout)
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addExerciseButtonTapped:
                state.destination = .exercisePicker(ExercisePickerFeature.State())
                return .none

            case .cancelButtonTapped:
                return .run { _ in await dismiss() }

            case .delegate:
                return .none

            case let .deleteExerciseSwiped(id):
                _ = state.$workout.withLock { $0.exercises.remove(id: id) }
                return .none

            case let .destination(.presented(.exercisePicker(.delegate(.select(exercise))))):
                let entry = WorkoutExercise(
                    id: uuid(),
                    exercise: exercise,
                    sets: [WorkoutSet(id: uuid(), weight: nil, reps: nil)]
                )
                state.$workout.withLock { $0.exercises.append(entry) }
                state.path.removeAll()
                state.openExercise(entry.id)
                return .none

            case .destination:
                return .none

            case let .endedAtChanged(date):
                state.$workout.withLock { $0.endedAt = max(date, $0.startedAt) }
                return .none

            case let .exerciseTapped(id):
                state.openExercise(id)
                return .none

            case let .exercisesMoved(source, destination):
                state.$workout.withLock { $0.exercises.move(fromOffsets: source, toOffset: destination) }
                return .none

            case .path(.element(id: _, action: .delegate(.addNextExercise))):
                state.destination = .exercisePicker(ExercisePickerFeature.State())
                return .none

            case .path:
                return .none

            case .saveButtonTapped:
                guard state.canSave else { return .none }
                let workout = state.workout.recordedOnly
                return .run { send in
                    await send(.delegate(.saved(workout)))
                    await dismiss()
                }

            case let .startedAtChanged(date):
                // 開始をずらしたら、長さが変わらないよう終了も同じだけずらす
                state.$workout.withLock {
                    let shift = date.timeIntervalSince($0.startedAt)
                    $0.startedAt = date
                    $0.endedAt = $0.endedAt?.addingTimeInterval(shift)
                }
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            ExerciseSetsFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension EditWorkoutFeature.Destination.State: Equatable {}

extension EditWorkoutFeature.State {
    mutating func openExercise(_ id: WorkoutExercise.ID) {
        guard let entry = Shared($workout.exercises[id: id]) else { return }
        path.append(ExerciseSetsFeature.State(entry: entry, startedBefore: originalStartedAt))
    }
}

struct EditWorkoutView: View {
    @Bindable var store: StoreOf<EditWorkoutFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section("日時") {
                    DatePicker(
                        "開始",
                        selection: Binding(
                            get: { store.workout.startedAt },
                            set: { store.send(.startedAtChanged($0)) }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    if let endedAt = store.workout.endedAt {
                        DatePicker(
                            "終了",
                            selection: Binding(
                                get: { endedAt },
                                set: { store.send(.endedAtChanged($0)) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("種目") {
                    ForEach(store.workout.exercises) { entry in
                        Button {
                            store.send(.exerciseTapped(entry.id))
                        } label: {
                            ExerciseSummaryRow(entry: entry)
                        }
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                store.send(.deleteExerciseSwiped(entry.id), animation: .default)
                            }
                        }
                    }
                    .onMove { store.send(.exercisesMoved($0, $1)) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.send(.addExerciseButtonTapped)
                } label: {
                    Label("種目を追加", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { store.send(.cancelButtonTapped) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { store.send(.saveButtonTapped) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!store.canSave)
                }
            }
        } destination: { store in
            ExerciseSetsView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.exercisePicker, action: \.destination.exercisePicker)) { pickerStore in
            NavigationStack {
                ExercisePickerView(store: pickerStore)
            }
        }
    }
}
