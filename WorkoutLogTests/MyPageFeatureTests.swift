//
//  MyPageFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct MyPageFeatureTests {
    @Test
    func 分析ボタンを押すと種目一覧が開く() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }

        await store.send(.analysisButtonTapped) {
            $0.path[id: 0] = .exerciseList(StatsExerciseListFeature.State())
        }
    }

    @Test
    func 種目一覧で種目を選ぶとその種目の分析画面が開く() async {
        var state = MyPageFeature.State()
        state.path.append(.exerciseList(StatsExerciseListFeature.State()))
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }

        let bench = Exercise.presets[0]
        await store.send(.path(.element(id: 0, action: .exerciseList(.delegate(.select(bench)))))) {
            $0.path[id: 1] = .analysis(StatsAnalysisFeature.State(exercise: bench))
        }
    }
}
