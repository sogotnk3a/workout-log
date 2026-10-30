//
//  ExerciseTrendFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct ExerciseTrendFeatureTests {
    @Test
    func ビッグ3は初期状態で推定1RMが選ばれている() {
        let state = ExerciseTrendFeature.State(exercise: .preset("bench-press"))
        #expect(state.metric == .oneRepMax)
    }

    @Test
    func ビッグ3以外は初期状態でボリュームが選ばれている() {
        let state = ExerciseTrendFeature.State(exercise: .preset("lat-pulldown"))
        #expect(state.metric == .volume)
    }

    @Test
    func 指標をタップすると表示する指標が変わる() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }

        await store.send(.metricButtonTapped(.volume)) {
            $0.metric = .volume
        }
    }

    @Test
    func 期間セグメントをタップすると集計範囲が変わる() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }
        #expect(store.state.range == .oneMonth)

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
        }
    }

    @Test
    func 前の期間をタップするとperiodOffsetが増え次の期間で戻る() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }

        await store.send(.previousPeriodButtonTapped) {
            $0.periodOffset = 1
        }
        await store.send(.previousPeriodButtonTapped) {
            $0.periodOffset = 2
        }
        await store.send(.nextPeriodButtonTapped) {
            $0.periodOffset = 1
        }
    }

    @Test
    func periodOffsetが0のときに次の期間をタップしても0未満にならない() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }

        await store.send(.nextPeriodButtonTapped)
        #expect(store.state.periodOffset == 0)
    }

    @Test
    func 期間セグメントを変えるとperiodOffsetが0に戻る() async {
        var state = ExerciseTrendFeature.State(exercise: .preset("bench-press"))
        state.periodOffset = 2
        let store = TestStore(initialState: state) {
            ExerciseTrendFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
            $0.periodOffset = 0
        }
    }

    @Test
    func 点をタップしてperiodOffsetを直接指定できる() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }

        await store.send(.periodOffsetSet(3)) {
            $0.periodOffset = 3
        }
        await store.send(.periodOffsetSet(1)) {
            $0.periodOffset = 1
        }
    }

    @Test
    func periodOffsetSetは負の値を指定しても0未満にはならない() async {
        let store = TestStore(initialState: ExerciseTrendFeature.State(exercise: .preset("bench-press"))) {
            ExerciseTrendFeature()
        }

        await store.send(.periodOffsetSet(-5))
        #expect(store.state.periodOffset == 0)
    }
}
