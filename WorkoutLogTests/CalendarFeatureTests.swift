//
//  CalendarFeatureTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct CalendarFeatureTests {
    let calendar = Calendar.tokyo
    var now: Date { calendar.date(2026, 10, 16, 9, 30) }

    private func makeStore(history: IdentifiedArrayOf<Workout> = []) -> TestStoreOf<CalendarFeature> {
        withDependencies {
            $0.calendar = calendar
            $0.date.now = now
        } operation: {
            @Shared(.workoutHistory) var shared = history
            return TestStore(initialState: CalendarFeature.State()) {
                CalendarFeature()
            } withDependencies: {
                $0.calendar = calendar
                $0.date.now = now
            }
        }
    }

    @Test
    func 開いたときは今月が表示され今日が選ばれている() {
        let store = makeStore()

        #expect(store.state.month == calendar.date(2026, 10, 1))
        #expect(store.state.selectedDay == calendar.date(2026, 10, 16))
    }

    @Test
    func 前の月に移ると1日が選ばれ今月に戻ると今日が選ばれる() async {
        let store = makeStore()

        await store.send(.previousMonthButtonTapped) {
            $0.month = calendar.date(2026, 9, 1)
            $0.selectedDay = calendar.date(2026, 9, 1)
        }
        await store.send(.nextMonthButtonTapped) {
            $0.month = calendar.date(2026, 10, 1)
            $0.selectedDay = calendar.date(2026, 10, 16)
        }
    }

    @Test
    func 日付のマスは日曜始まりで1日より前は空白になる() {
        let store = makeStore()

        let days = store.state.days(calendar: calendar)

        // 2026年10月1日は木曜日なので、日〜水の4マスが空白
        #expect(days.prefix(4).allSatisfy { $0 == nil })
        #expect(days[4]?.date == calendar.date(2026, 10, 1))
        #expect(days.compactMap { $0 }.count == 31)
    }

    @Test
    func 日付のマスにはその日に鍛えた部位が部位の順に1つずつ並ぶ() {
        let morning = Workout.sample(
            id: UUID(1),
            startedAt: calendar.date(2026, 10, 8, 7, 0),
            exercises: [.preset("dumbbell-curl"), .preset("bench-press")]
        )
        let evening = Workout.sample(
            id: UUID(2),
            startedAt: calendar.date(2026, 10, 8, 19, 0),
            exercises: [.preset("cable-fly"), .preset("crunch")]
        )
        let store = makeStore(history: [evening, morning])

        let day = store.state.days(calendar: calendar).compactMap { $0 }.first { $0.date == calendar.date(2026, 10, 8) }

        #expect(day?.bodyParts == [.chest, .arms, .abs])
    }

    @Test
    func トレーニングしていない日のマスには部位がない() {
        let store = makeStore()

        let days = store.state.days(calendar: calendar).compactMap { $0 }

        #expect(days.allSatisfy { $0.bodyParts.isEmpty })
    }

    @Test
    func 選んだ日のトレーニングだけが開始の早い順に並ぶ() async {
        let evening = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("squat")])
        let morning = Workout.sample(id: UUID(2), startedAt: calendar.date(2026, 10, 15, 7, 0), exercises: [.preset("deadlift")])
        let otherDay = Workout.sample(id: UUID(3), startedAt: calendar.date(2026, 10, 14, 19, 0), exercises: [.preset("bench-press")])
        let store = makeStore(history: [evening, morning, otherDay])

        await store.send(.dayTapped(calendar.date(2026, 10, 15))) {
            $0.selectedDay = calendar.date(2026, 10, 15)
        }

        #expect(store.state.selectedDayWorkouts(calendar: calendar).map(\.id) == [UUID(2), UUID(1)])
    }

    @Test
    func 表示している月にトレーニングした回数を数える() {
        let store = makeStore(history: [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 0), exercises: [.preset("squat")]),
            .sample(id: UUID(2), startedAt: calendar.date(2026, 10, 1, 19, 0), exercises: [.preset("squat")]),
            .sample(id: UUID(3), startedAt: calendar.date(2026, 9, 30, 19, 0), exercises: [.preset("squat")]),
        ])

        #expect(store.state.workoutCount(calendar: calendar) == 2)
    }

    @Test
    func 記録をタップするとその記録の詳細ページが開く() async {
        let store = makeStore()

        await store.send(.workoutTapped(UUID(1))) {
            $0.path[id: 0] = WorkoutDetailFeature.State(workoutID: UUID(1))
        }
    }

    @Test
    func 記録をスワイプして削除すると確認したあとで履歴から消える() async {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 2), minutes: 68, exercises: [.preset("bench-press")])
        let store = makeStore(history: [workout])

        await store.send(.deleteWorkoutSwiped(workout.id)) {
            $0.destination = .deleteAlert(.deleteWorkout(workout, calendar: calendar, action: .confirmButtonTapped(workout.id)))
        }
        await store.send(.destination(.presented(.deleteAlert(.confirmButtonTapped(workout.id))))) {
            $0.destination = nil
            $0.$history.withLock { $0 = [] }
        }
    }

    @Test
    func 削除の確認には記録の日付と時間が出る() {
        let workout = Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 15, 19, 2), minutes: 68, exercises: [.preset("bench-press")])

        let alert = AlertState.deleteWorkout(workout, calendar: calendar, action: CalendarFeature.Destination.DeleteAlert.confirmButtonTapped(workout.id))

        #expect(String(state: alert.message!) == "10月15日（木） 19:02〜20:10 の記録を削除します。元に戻すことはできません。")
    }
}
