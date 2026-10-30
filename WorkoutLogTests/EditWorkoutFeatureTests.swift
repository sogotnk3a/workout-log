//
//  EditWorkoutFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct EditWorkoutFeatureTests {
    let calendar = Calendar.tokyo

    @Test
    func 開始日時を変えると長さが変わらないよう終了日時も同じだけずれる() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), minutes: 68, exercises: [.preset("bench-press")])
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: workout)) {
            EditWorkoutFeature()
        }

        await store.send(.startedAtChanged(calendar.date(2026, 10, 14, 18, 30))) {
            $0.$workout.withLock {
                $0.startedAt = calendar.date(2026, 10, 14, 18, 30)
                $0.endedAt = calendar.date(2026, 10, 14, 19, 38)
            }
        }
    }

    @Test
    func 終了日時は開始日時より前にならない() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: workout)) {
            EditWorkoutFeature()
        }

        await store.send(.endedAtChanged(calendar.date(2026, 10, 15, 18, 0))) {
            $0.$workout.withLock { $0.endedAt = calendar.date(2026, 10, 15, 19, 0) }
        }
        await store.send(.endedAtChanged(calendar.date(2026, 10, 15, 20, 15))) {
            $0.$workout.withLock { $0.endedAt = calendar.date(2026, 10, 15, 20, 15) }
        }
    }

    @Test
    func 保存すると回数を入力したセットだけを親に渡して閉じる() async {
        var workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        let entryID = workout.exercises[0].id
        workout.exercises[id: entryID]?.sets.append(WorkoutSet(id: UUID(9), weight: 60, reps: nil))
        let isDismissed = LockIsolated(false)
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: workout)) {
            EditWorkoutFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { isDismissed.setValue(true) }
        }

        await store.send(.saveButtonTapped)
        await store.receive(\.delegate.saved, workout.recordedOnly)
        #expect(workout.recordedOnly.exercises[id: entryID]?.sets.count == 1)
        #expect(isDismissed.value)
    }

    @Test
    func 回数を入力したセットがなければ保存できない() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: workout)) {
            EditWorkoutFeature()
        }

        await store.send(.deleteExerciseSwiped(workout.exercises[0].id)) {
            $0.$workout.withLock { $0.exercises = [] }
        }
        #expect(!store.state.canSave)
        await store.send(.saveButtonTapped)
    }

    @Test
    func 種目を追加すると空のセットを1つ持った入力ページが開く() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("bench-press")])
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: workout)) {
            EditWorkoutFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addExerciseButtonTapped) {
            $0.destination = .exercisePicker(ExercisePickerFeature.State())
        }
        await store.send(.destination(.presented(.exercisePicker(.delegate(.select(.preset("crunch"))))))) {
            $0.$workout.withLock {
                $0.exercises.append(
                    WorkoutExercise(id: UUID(0), exercise: .preset("crunch"), sets: [WorkoutSet(id: UUID(1), weight: nil, reps: nil)])
                )
            }
            $0.path[id: 0] = ExerciseSetsFeature.State(
                entry: Shared($0.$workout.exercises[id: UUID(0)])!,
                startedBefore: calendar.date(2026, 10, 15, 19, 0)
            )
        }
    }

    @Test
    func 編集中の入力ページでは編集している記録より前のトレーニングを前回として出す() async {
        let bench = Exercise.preset("bench-press")
        var editing = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [bench])
        editing.exercises[0].sets[0].weight = 70
        var before = Workout.sample(id: UUID(2), startedAt: calendar.date(2026, 10, 10, 19, 0), exercises: [bench])
        before.exercises[0].sets[0].weight = 65
        var after = Workout.sample(id: UUID(3), startedAt: calendar.date(2026, 10, 16, 19, 0), exercises: [bench])
        after.exercises[0].sets[0].weight = 75
        @Shared(.workoutHistory) var history = [after, editing, before]
        let store = TestStore(initialState: EditWorkoutFeature.State(workout: editing)) {
            EditWorkoutFeature()
        }

        await store.send(.exerciseTapped(editing.exercises[0].id)) {
            $0.path[id: 0] = ExerciseSetsFeature.State(
                entry: Shared($0.$workout.exercises[id: editing.exercises[0].id])!,
                startedBefore: calendar.date(2026, 10, 15, 19, 0)
            )
        }
        #expect(store.state.path[id: 0]?.previousSets.map(\.weight) == [65])
    }
}
