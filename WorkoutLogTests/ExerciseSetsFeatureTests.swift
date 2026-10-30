//
//  ExerciseSetsFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct ExerciseSetsFeatureTests {
    let bench = Exercise.presets[0]

    @Test
    func セットを追加すると直前のセットの重量と回数を引き継ぐ() async {
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench, sets: [WorkoutSet(id: UUID(101), weight: 60, reps: 10)]))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addSetButtonTapped) {
            $0.$entry.withLock { $0.sets.append(WorkoutSet(id: UUID(0), weight: 60, reps: 10)) }
        }
    }

    @Test
    func セットがない種目にセットを追加すると空欄のセットになる() async {
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addSetButtonTapped) {
            $0.$entry.withLock { $0.sets = [WorkoutSet(id: UUID(0), weight: nil, reps: nil)] }
        }
    }

    @Test
    func 重量と回数は負の値にならず0になる() async {
        let set = WorkoutSet(id: UUID(1), weight: nil, reps: nil)
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench, sets: [set]))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        }

        await store.send(.weightChanged(set.id, -2.5)) {
            $0.$entry.withLock { $0.sets[id: set.id]?.weight = 0 }
        }
        await store.send(.repsChanged(set.id, 8)) {
            $0.$entry.withLock { $0.sets[id: set.id]?.reps = 8 }
        }
        await store.send(.repsChanged(set.id, -1)) {
            $0.$entry.withLock { $0.sets[id: set.id]?.reps = 0 }
        }
        await store.send(.repsChanged(set.id, nil)) {
            $0.$entry.withLock { $0.sets[id: set.id]?.reps = nil }
        }
    }

    @Test
    func 削除したセットは元に戻すで同じ位置に戻り6秒経っても何も起きない() async {
        let clock = TestClock()
        let sets: IdentifiedArrayOf<WorkoutSet> = [
            WorkoutSet(id: UUID(1), weight: 60, reps: 10),
            WorkoutSet(id: UUID(2), weight: 60, reps: 8),
            WorkoutSet(id: UUID(3), weight: 60, reps: 6),
        ]
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench, sets: sets))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.deleteSetSwiped(UUID(2))) {
            $0.deletedSet = ExerciseSetsFeature.DeletedSet(index: 1, set: sets[1])
            $0.$entry.withLock { _ = $0.sets.remove(id: UUID(2)) }
        }
        await clock.advance(by: .seconds(5))
        await store.send(.undoDeleteButtonTapped) {
            $0.deletedSet = nil
            $0.$entry.withLock { $0.sets = sets }
        }
        await clock.run()
    }

    @Test
    func 元に戻すは削除から6秒で消える() async {
        let clock = TestClock()
        let set = WorkoutSet(id: UUID(1), weight: 60, reps: 10)
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench, sets: [set]))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.deleteSetSwiped(set.id)) {
            $0.deletedSet = ExerciseSetsFeature.DeletedSet(index: 0, set: set)
            $0.$entry.withLock { $0.sets = [] }
        }
        await clock.advance(by: .seconds(6))
        await store.receive(\.undoExpired) {
            $0.deletedSet = nil
        }
    }

    @Test
    func 別のセットを削除すると元に戻すの6秒は数え直しになる() async {
        let clock = TestClock()
        let sets: IdentifiedArrayOf<WorkoutSet> = [
            WorkoutSet(id: UUID(1), weight: 60, reps: 10),
            WorkoutSet(id: UUID(2), weight: 60, reps: 8),
        ]
        let entry = Shared(value: WorkoutExercise(id: UUID(100), exercise: bench, sets: sets))
        let store = TestStore(initialState: ExerciseSetsFeature.State(entry: entry)) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.deleteSetSwiped(UUID(1))) {
            $0.deletedSet = ExerciseSetsFeature.DeletedSet(index: 0, set: sets[0])
            $0.$entry.withLock { _ = $0.sets.remove(id: UUID(1)) }
        }
        await clock.advance(by: .seconds(4))
        await store.send(.deleteSetSwiped(UUID(2))) {
            $0.deletedSet = ExerciseSetsFeature.DeletedSet(index: 0, set: sets[1])
            $0.$entry.withLock { $0.sets = [] }
        }
        await clock.advance(by: .seconds(4))
        await clock.advance(by: .seconds(2))
        await store.receive(\.undoExpired) {
            $0.deletedSet = nil
        }
    }

    @Test
    func 前回の値はその種目を最後にやったトレーニングから取る() {
        let newer = Workout(
            id: UUID(1),
            startedAt: .distantPast,
            exercises: [WorkoutExercise(id: UUID(2), exercise: bench, sets: [WorkoutSet(id: UUID(3), weight: 70, reps: 5)])]
        )
        let older = Workout(
            id: UUID(4),
            startedAt: .distantPast,
            exercises: [WorkoutExercise(id: UUID(5), exercise: bench, sets: [WorkoutSet(id: UUID(6), weight: 60, reps: 10)])]
        )
        @Shared(.workoutHistory) var history = [newer, older]
        let state = ExerciseSetsFeature.State(entry: Shared(value: WorkoutExercise(id: UUID(100), exercise: bench)))

        #expect(state.previousSets == [WorkoutSet(id: UUID(3), weight: 70, reps: 5)])
    }

    @Test
    func 前回の値を入力すると前回のセット数まで行を足して入力済みは上書きせず空欄だけを埋める() async {
        let previous = Workout(
            id: UUID(50),
            startedAt: .distantPast,
            exercises: [
                WorkoutExercise(
                    id: UUID(51),
                    exercise: bench,
                    sets: [
                        WorkoutSet(id: UUID(52), weight: 60, reps: 10),
                        WorkoutSet(id: UUID(53), weight: 60, reps: 8),
                        WorkoutSet(id: UUID(54), weight: 55, reps: 8),
                    ]
                )
            ]
        )
        let entry = Shared(
            value: WorkoutExercise(
                id: UUID(100),
                exercise: bench,
                sets: [WorkoutSet(id: UUID(101), weight: 62.5, reps: nil)]
            )
        )
        @Shared(.workoutHistory) var history = [previous]
        let state = ExerciseSetsFeature.State(entry: entry)
        let store = TestStore(initialState: state) {
            ExerciseSetsFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.fillPreviousButtonTapped) {
            $0.$entry.withLock {
                $0.sets = [
                    WorkoutSet(id: UUID(101), weight: 62.5, reps: 10),
                    WorkoutSet(id: UUID(0), weight: 60, reps: 8),
                    WorkoutSet(id: UUID(1), weight: 55, reps: 8),
                ]
            }
        }
    }

    @Test
    func 前回よりセットが多いときに前回の値を入力しても行は減らない() async {
        let previous = Workout(
            id: UUID(50),
            startedAt: .distantPast,
            exercises: [
                WorkoutExercise(id: UUID(51), exercise: bench, sets: [WorkoutSet(id: UUID(52), weight: 60, reps: 10)])
            ]
        )
        let entry = Shared(
            value: WorkoutExercise(
                id: UUID(100),
                exercise: bench,
                sets: [
                    WorkoutSet(id: UUID(101), weight: nil, reps: nil),
                    WorkoutSet(id: UUID(102), weight: nil, reps: nil),
                ]
            )
        )
        @Shared(.workoutHistory) var history = [previous]
        let state = ExerciseSetsFeature.State(entry: entry)
        let store = TestStore(initialState: state) {
            ExerciseSetsFeature()
        }

        await store.send(.fillPreviousButtonTapped) {
            $0.$entry.withLock { $0.sets[0] = WorkoutSet(id: UUID(101), weight: 60, reps: 10) }
        }
    }
}
