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
    @Test
    func 開いたときは部位と月と回数が選ばれている() {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }
        #expect(store.state.mode == .bodyPart)
        #expect(store.state.range == .oneMonth)
        #expect(store.state.metric == .count)
    }

    @Test
    func 指標を矢印で切り替えると回数ボリュームセット数を順に巡回する() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.nextMetricButtonTapped) {
            $0.metric = .volume
        }
        await store.send(.nextMetricButtonTapped) {
            $0.metric = .setCount
        }
        await store.send(.nextMetricButtonTapped) {
            $0.metric = .count
        }
        await store.send(.previousMetricButtonTapped) {
            $0.metric = .setCount
        }
    }

    @Test
    func 部位をタップすると親に通知する() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.bodyPartTapped(.chest))
        await store.receive(\.delegate.bodyPartTapped)
    }

    @Test
    func 部位種目セグメントをタップすると表示モードが変わる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.modeButtonTapped(.exercise)) {
            $0.mode = .exercise
        }
    }

    @Test
    func 期間セグメントをタップすると集計範囲が変わる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
        }
    }

    @Test
    func 種目をタップすると親に通知する() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.exerciseTapped("squat"))
        await store.receive(\.delegate.exerciseTapped)
    }

    @Test
    func 開いたときは種目の部位絞り込みは選ばれていない() {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }
        #expect(store.state.exerciseBodyPartFilter == nil)
    }

    @Test
    func 部位チップをタップすると種目の絞り込みが変わる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.exerciseBodyPartFilterTapped(.chest)) {
            $0.exerciseBodyPartFilter = .chest
        }
        await store.send(.exerciseBodyPartFilterTapped(nil)) {
            $0.exerciseBodyPartFilter = nil
        }
    }

    @Test
    func 前の期間をタップするとperiodOffsetが増え次の期間で戻る() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
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
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.nextPeriodButtonTapped) {
            $0.hasSelectedPeriod = true
        }
        #expect(store.state.periodOffset == 0)
    }

    @Test
    func 期間セグメントを変えるとperiodOffsetが0に戻る() async {
        var state = StatsAnalysisFeature.State()
        state.periodOffset = 2
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
            $0.periodOffset = 0
        }
    }

    @Test
    func 部位種目セグメントを変えるとperiodOffsetが0に戻る() async {
        var state = StatsAnalysisFeature.State()
        state.periodOffset = 2
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.modeButtonTapped(.exercise)) {
            $0.mode = .exercise
            $0.periodOffset = 0
        }
    }

    @Test
    func 期間セグメントを変えると推移グラフの部位絞り込みも解除される() async {
        var state = StatsAnalysisFeature.State()
        state.bodyPartChartFilter = .chest
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
            $0.bodyPartChartFilter = nil
        }
    }

    @Test
    func 推移グラフの部位チップをタップすると絞り込みが変わる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.bodyPartChartFilterTapped(.legs)) {
            $0.bodyPartChartFilter = .legs
        }
        await store.send(.bodyPartChartFilterTapped(nil)) {
            $0.bodyPartChartFilter = nil
        }
    }

    @Test
    func 棒をタップしてperiodOffsetを直接指定できる() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
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
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }

        await store.send(.periodOffsetSet(-5)) {
            $0.hasSelectedPeriod = true
        }
        #expect(store.state.periodOffset == 0)
    }

    @Test
    func 期間を選ぶまでは部位ごとの内訳を出さない() async {
        let store = TestStore(initialState: StatsAnalysisFeature.State()) {
            StatsAnalysisFeature()
        }
        #expect(store.state.hasSelectedPeriod == false)

        await store.send(.periodOffsetSet(1)) {
            $0.periodOffset = 1
            $0.hasSelectedPeriod = true
        }
    }

    @Test
    func 期間セグメントを変えると内訳を出す前の状態に戻る() async {
        var state = StatsAnalysisFeature.State()
        state.hasSelectedPeriod = true
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.rangeButtonTapped(.oneYear)) {
            $0.range = .oneYear
            $0.hasSelectedPeriod = false
        }
    }

    @Test
    func 部位種目セグメントを変えると内訳を出す前の状態に戻る() async {
        var state = StatsAnalysisFeature.State()
        state.hasSelectedPeriod = true
        let store = TestStore(initialState: state) {
            StatsAnalysisFeature()
        }

        await store.send(.modeButtonTapped(.exercise)) {
            $0.mode = .exercise
            $0.hasSelectedPeriod = false
        }
    }
}
