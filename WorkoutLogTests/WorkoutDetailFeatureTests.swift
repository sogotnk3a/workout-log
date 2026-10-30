//
//  WorkoutDetailFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct WorkoutDetailFeatureTests {
    let calendar = Calendar.tokyo

    @Test
    func 削除を確認すると履歴から消えて詳細ページが閉じる() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 2), exercises: [.preset("bench-press")])
        @Shared(.workoutHistory) var history = [workout]
        let isDismissed = LockIsolated(false)
        let store = TestStore(initialState: WorkoutDetailFeature.State(workoutID: workout.id)) {
            WorkoutDetailFeature()
        } withDependencies: {
            $0.calendar = calendar
            $0.dismiss = DismissEffect { isDismissed.setValue(true) }
        }

        await store.send(.deleteButtonTapped) {
            $0.destination = .deleteAlert(.deleteWorkout(workout, calendar: calendar, action: .confirmButtonTapped))
        }
        await store.send(.destination(.presented(.deleteAlert(.confirmButtonTapped)))) {
            $0.destination = nil
            $0.$history.withLock { $0 = [] }
        }
        #expect(isDismissed.value)
    }

    @Test
    func 削除をキャンセルすると履歴は変わらない() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 2), exercises: [.preset("bench-press")])
        @Shared(.workoutHistory) var history = [workout]
        let store = TestStore(initialState: WorkoutDetailFeature.State(workoutID: workout.id)) {
            WorkoutDetailFeature()
        } withDependencies: {
            $0.calendar = calendar
        }

        await store.send(.deleteButtonTapped) {
            $0.destination = .deleteAlert(.deleteWorkout(workout, calendar: calendar, action: .confirmButtonTapped))
        }
        await store.send(.destination(.dismiss)) {
            $0.destination = nil
        }
        #expect(history == [workout])
    }

    @Test
    func 編集して保存すると履歴が書き換わり開始日時の新しい順に並び直す() async {
        let older = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 10, 19, 0), exercises: [.preset("squat")])
        let newer = Workout.sample(id: UUID(2), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        @Shared(.workoutHistory) var history = [newer, older]
        var state = WorkoutDetailFeature.State(workoutID: older.id)
        state.destination = .edit(EditWorkoutFeature.State(workout: older))
        let store = TestStore(initialState: state) {
            WorkoutDetailFeature()
        }

        // 古いほうの記録を、新しいほうより後の日時に変える
        let movedStart = calendar.date(2026, 10, 16, 7, 0)
        await store.send(.destination(.presented(.edit(.startedAtChanged(movedStart))))) {
            $0.destination?.modify(\.edit) {
                $0.$workout.withLock {
                    $0.startedAt = movedStart
                    $0.endedAt = movedStart.addingTimeInterval(3600)
                }
            }
        }
        var moved = older
        moved.startedAt = movedStart
        moved.endedAt = movedStart.addingTimeInterval(3600)
        await store.send(.destination(.presented(.edit(.saveButtonTapped))))
        await store.receive(\.destination.edit.delegate.saved) {
            $0.$history.withLock { $0 = [moved, newer] }
        }
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
    }

    @Test
    func 編集をキャンセルすると元の記録は変わらない() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        @Shared(.workoutHistory) var history = [workout]
        let store = TestStore(initialState: WorkoutDetailFeature.State(workoutID: workout.id)) {
            WorkoutDetailFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.editButtonTapped) {
            $0.destination = .edit(EditWorkoutFeature.State(workout: workout))
        }
        await store.send(.destination(.presented(.edit(.deleteExerciseSwiped(workout.exercises[0].id))))) {
            $0.destination?.modify(\.edit) {
                $0.$workout.withLock { $0.exercises = [] }
            }
        }
        await store.send(.destination(.presented(.edit(.cancelButtonTapped))))
        await store.receive(\.destination.dismiss) {
            $0.destination = nil
        }
        #expect(history == [workout])
    }
}
