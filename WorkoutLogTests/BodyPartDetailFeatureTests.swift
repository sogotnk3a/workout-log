//
//  BodyPartDetailFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct BodyPartDetailFeatureTests {
    @Test
    func 開いたときは1ヶ月と回数が選ばれている() {
        let store = TestStore(initialState: BodyPartDetailFeature.State(part: .chest)) {
            BodyPartDetailFeature()
        }
        #expect(store.state.range == .oneMonth)
        #expect(store.state.metric == .count)
    }

    @Test
    func 矢印で指標を切り替えられる端まで行ったら逆側から回り込む() async {
        let store = TestStore(initialState: BodyPartDetailFeature.State(part: .chest)) {
            BodyPartDetailFeature()
        }
        #expect(store.state.metric == .count)

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
    func 開くときに指標を指定できる() {
        let store = TestStore(initialState: BodyPartDetailFeature.State(part: .chest, metric: .volume)) {
            BodyPartDetailFeature()
        }
        #expect(store.state.metric == .volume)
    }

    @Test
    func 期間セグメントをタップすると集計期間が変わる() async {
        let store = TestStore(initialState: BodyPartDetailFeature.State(part: .chest)) {
            BodyPartDetailFeature()
        }

        await store.send(.rangeButtonTapped(.all)) {
            $0.range = .all
        }
    }

    @Test
    func 種目をタップすると親に通知する() async {
        let store = TestStore(initialState: BodyPartDetailFeature.State(part: .chest)) {
            BodyPartDetailFeature()
        }

        await store.send(.exerciseTapped("bench-press"))
        await store.receive(\.delegate.exerciseTapped)
    }
}
