//
//  RecordWorkoutFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct RecordWorkoutFeatureTests {
    let bench = Exercise.presets[0]
    let squat = Exercise.presets[6]

    @Test
    func 種目を選ぶと空のセットを1つ持った入力ページが開く() async {
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.addExerciseButtonTapped) {
            $0.destination = .exercisePicker(ExercisePickerFeature.State())
        }
        await store.send(.destination(.presented(.exercisePicker(.delegate(.select(bench)))))) {
            $0.$workout.withLock {
                $0.exercises = [
                    WorkoutExercise(id: UUID(0), exercise: bench, sets: [WorkoutSet(id: UUID(1), weight: nil, reps: nil)])
                ]
            }
            $0.path[id: 0] = ExerciseSetsFeature.State(entry: Shared($0.$workout.exercises[id: UUID(0)])!)
        }
    }

    @Test
    func 入力ページから次の種目を選ぶと前の種目のページは閉じて戻ると一覧になる() async {
        let entry = WorkoutExercise(id: UUID(10), exercise: bench, sets: [WorkoutSet(id: UUID(11), weight: 60, reps: 10)])
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast, exercises: [entry]))
        var state = RecordWorkoutFeature.State(workout: workout)
        state.openExercise(entry.id)
        let store = TestStore(initialState: state) {
            RecordWorkoutFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.path(.element(id: 0, action: .nextExerciseButtonTapped)))
        await store.receive(\.path[id: 0].delegate.addNextExercise) {
            $0.destination = .exercisePicker(ExercisePickerFeature.State())
        }
        await store.send(.destination(.presented(.exercisePicker(.delegate(.select(squat)))))) {
            $0.$workout.withLock {
                $0.exercises.append(
                    WorkoutExercise(id: UUID(0), exercise: squat, sets: [WorkoutSet(id: UUID(1), weight: nil, reps: nil)])
                )
            }
                $0.path.removeAll()
            $0.path[id: 1] = ExerciseSetsFeature.State(entry: Shared($0.$workout.exercises[id: UUID(0)])!)
        }
    }

    @Test
    func 一覧の種目をタップするとその種目の入力ページが開く() async {
        let entry = WorkoutExercise(id: UUID(10), exercise: bench)
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast, exercises: [entry]))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        }

        await store.send(.exerciseTapped(entry.id)) {
            $0.path[id: 0] = ExerciseSetsFeature.State(entry: Shared($0.$workout.exercises[id: entry.id])!)
        }
    }

    @Test
    func 種目を並べ替えたり削除したりできる() async {
        let a = WorkoutExercise(id: UUID(1), exercise: bench)
        let b = WorkoutExercise(id: UUID(2), exercise: squat)
        let c = WorkoutExercise(id: UUID(3), exercise: Exercise.presets[3])
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast, exercises: [a, b, c]))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        }

        await store.send(.exercisesMoved([2], 0)) {
            $0.$workout.withLock { $0.exercises = [c, a, b] }
        }
        await store.send(.deleteExerciseSwiped(a.id)) {
            $0.$workout.withLock { $0.exercises = [c, b] }
        }
    }

    @Test
    func 回数を入力したセットがあれば終了時に保存して終了できる() async {
        let entry = WorkoutExercise(id: UUID(1), exercise: bench, sets: [WorkoutSet(id: UUID(2), weight: 60, reps: 10)])
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast, exercises: [entry]))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        }

        await store.send(.finishButtonTapped) {
            $0.destination = .finishAlert(.finish(hasRecordedSets: true))
        }
        await store.send(.destination(.presented(.finishAlert(.saveButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate.finished)
    }

    @Test
    func 回数を入力したセットがなければ終了時は破棄しか選べない() async {
        let entry = WorkoutExercise(id: UUID(1), exercise: bench, sets: [WorkoutSet(id: UUID(2), weight: 60, reps: nil)])
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast, exercises: [entry]))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        }

        await store.send(.finishButtonTapped) {
            $0.destination = .finishAlert(.finish(hasRecordedSets: false))
        }
        await store.send(.destination(.presented(.finishAlert(.discardButtonTapped)))) {
            $0.destination = nil
        }
        await store.receive(\.delegate.discarded)
    }

    @Test
    func 最小化すると記録画面は閉じるが記録中のトレーニングは残る() async {
        let isDismissed = LockIsolated(false)
        let workout = Shared(value: Workout(id: UUID(0), startedAt: .distantPast))
        let store = TestStore(initialState: RecordWorkoutFeature.State(workout: workout)) {
            RecordWorkoutFeature()
        } withDependencies: {
            $0.dismiss = DismissEffect { isDismissed.setValue(true) }
        }

        await store.send(.minimizeButtonTapped)
        #expect(isDismissed.value)
        #expect(store.state.workout == Workout(id: UUID(0), startedAt: .distantPast))
    }
}
