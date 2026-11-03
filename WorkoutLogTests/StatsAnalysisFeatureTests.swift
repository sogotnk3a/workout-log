//
//  StatsAnalysisFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct StatsAnalysisFeatureTests {
    let bench = Exercise.presets[0]
    let calendar = Calendar.tokyo

    @Test
    func 開いたときは1ヶ月が選ばれていて内訳は出ていない() {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        #expect(store.state.exercise.id == bench.id)
        #expect(store.state.range == .oneMonth)
        #expect(store.state.hasSelectedPeriod == false)
    }

    @Test
    func 期間の基準はその種目を最後にやった日時でしばらく記録していなくても今日からにはならない() {
        let lastBenchDate = calendar.date(2026, 9, 1, 10, 0)
        @Shared(.workoutHistory) var history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: lastBenchDate, exercises: [.preset("bench-press")]),
        ]
        let state = StatsAnalysisFeature.State(exercise: bench)

        #expect(state.latestRecordDate == lastBenchDate)
        #expect(state.referenceDate(calendar: calendar) == lastBenchDate)
    }

    @Test
    func 期間の基準は記録がない種目なら今の日時になる() {
        let state = StatsAnalysisFeature.State(exercise: bench)
        #expect(abs(state.latestRecordDate.timeIntervalSinceNow) < 1)
    }

    @Test
    func 期間セグメントをタップすると集計範囲が変わる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
        }
    }

    @Test
    func 前の期間をタップするとperiodOffsetが増え次の期間で戻る() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        await store.send(.previousPeriodButtonTapped) {
            $0.periodOffset = 1
            $0.hasSelectedPeriod = true
        }
        await store.send(.previousPeriodButtonTapped) {
            $0.periodOffset = 2
        }
        await store.send(.nextPeriodButtonTapped) {
            $0.periodOffset = 1
        }
    }

    @Test
    func 次の期間は現在より先には進まない() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        await store.send(.nextPeriodButtonTapped) {
            $0.hasSelectedPeriod = true
        }
        #expect(store.state.periodOffset == 0)
    }

    @Test
    func 期間セグメントを変えるとperiodOffsetや内訳を出す前の状態に戻る() async {
        var state = StatsAnalysisFeature.State(exercise: bench)
        state.periodOffset = 2
        state.hasSelectedPeriod = true
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
            $0.periodOffset = 0
            $0.hasSelectedPeriod = false
        }
    }

    @Test
    func 点をタップしてperiodOffsetを直接指定できる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        await store.send(.periodOffsetSet(3)) {
            $0.periodOffset = 3
            $0.hasSelectedPeriod = true
        }
        await store.send(.periodOffsetSet(1)) {
            $0.periodOffset = 1
        }
    }

    @Test
    func periodOffsetSetは負の値を指定しても0未満にはならない() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State(exercise: bench)) {
            StatsAnalysisFeature()
        }

        await store.send(.periodOffsetSet(-5)) {
            $0.hasSelectedPeriod = true
        }
        #expect(store.state.periodOffset == 0)
    }
}
