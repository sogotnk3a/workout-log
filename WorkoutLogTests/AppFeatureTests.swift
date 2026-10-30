//
//  AppFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct AppFeatureTests {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let endedAt = Date(timeIntervalSince1970: 1_003_600)

    /// カレンダータブの初期状態が今日の日付を使うので、日付と暦を固定して作る
    private func makeState() -> AppFeature.State {
        withDependencies {
            $0.calendar = .tokyo
            $0.date.now = now
        } operation: {
            AppFeature.State()
        }
    }

    @Test
    func 記録中でなければ記録ボタンで開始シートが開く() async {
        let store = TestStore(initialState: makeState()) {
            AppFeature()
        }

        await store.send(.recordButtonTapped) {
            $0.destination = .startWorkout(StartWorkoutFeature.State())
        }
    }

    @Test
    func 空で始めると新しいトレーニングが作られて記録画面と種目の選択が開く() async {
        var state = makeState()
        state.destination = .startWorkout(StartWorkoutFeature.State())
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = now
            $0.uuid = .incrementing
        }

        // @Shared は参照なので、delegate で書き換えた値は send の時点で見えている
        await store.send(.destination(.presented(.startWorkout(.startEmptyButtonTapped)))) {
            $0.$activeWorkout.withLock { $0 = Workout(id: UUID(0), startedAt: now) }
        }
        await store.receive(\.destination.startWorkout.delegate.startEmpty) {
            var record = RecordWorkoutFeature.State(workout: Shared($0.$activeWorkout)!)
            record.destination = .exercisePicker(ExercisePickerFeature.State())
            $0.destination = .recordWorkout(record)
        }
    }

    @Test
    func 記録中なら記録ボタンで記録画面に戻る() async {
        var state = makeState()
        state.$activeWorkout.withLock { $0 = Workout(id: UUID(0), startedAt: now) }
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.recordButtonTapped) {
            $0.destination = .recordWorkout(RecordWorkoutFeature.State(workout: Shared($0.$activeWorkout)!))
        }
    }

    @Test
    func 最小化中のバーをタップすると記録画面に戻る() async {
        var state = makeState()
        state.$activeWorkout.withLock { $0 = Workout(id: UUID(0), startedAt: now) }
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.activeWorkoutBarTapped) {
            $0.destination = .recordWorkout(RecordWorkoutFeature.State(workout: Shared($0.$activeWorkout)!))
        }
    }

    @Test
    func 保存して終了すると回数を入力したセットだけが終了日時付きで履歴の先頭に入る() async {
        let bench = WorkoutExercise(
            id: UUID(1),
            exercise: Exercise.presets[0],
            sets: [
                WorkoutSet(id: UUID(2), weight: 60, reps: 10),
                WorkoutSet(id: UUID(3), weight: 60, reps: nil),
            ]
        )
        let squat = WorkoutExercise(
            id: UUID(4),
            exercise: Exercise.presets[6],
            sets: [WorkoutSet(id: UUID(5), weight: 100, reps: nil)]
        )
        let older = Workout(id: UUID(9), startedAt: Date(timeIntervalSince1970: 0))
        var state = makeState()
        state.$workoutHistory.withLock { $0 = [older] }
        state.$activeWorkout.withLock { $0 = Workout(id: UUID(0), startedAt: now, exercises: [bench, squat]) }
        state.openActiveWorkout()
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = endedAt
        }

        await store.send(.destination(.presented(.recordWorkout(.delegate(.finished))))) {
            var saved = Workout(id: UUID(0), startedAt: now, endedAt: endedAt)
            saved.exercises = [
                WorkoutExercise(id: UUID(1), exercise: Exercise.presets[0], sets: [WorkoutSet(id: UUID(2), weight: 60, reps: 10)])
            ]
            $0.$workoutHistory.withLock { $0 = [saved, older] }
            $0.destination = nil
            $0.$activeWorkout.withLock { $0 = nil }
        }
    }

    @Test
    func 記録を破棄すると履歴に残さずに記録中のトレーニングが消える() async {
        var state = makeState()
        state.$activeWorkout.withLock { $0 = Workout(id: UUID(0), startedAt: now) }
        state.openActiveWorkout()
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.destination(.presented(.recordWorkout(.delegate(.discarded))))) {
            $0.destination = nil
            $0.$activeWorkout.withLock { $0 = nil }
        }
        #expect(store.state.workoutHistory.isEmpty)
    }

    @Test
    func タブを選ぶと表示するタブが切り替わる() async {
        let store = TestStore(initialState: makeState()) {
            AppFeature()
        }

        await store.send(.tabSelected(.calendar)) {
            $0.selectedTab = .calendar
        }
    }
}
