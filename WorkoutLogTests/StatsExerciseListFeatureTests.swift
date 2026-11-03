//
//  StatsExerciseListFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct StatsExerciseListFeatureTests {
    @Test
    func 初期状態では全種目がExerciseのpresetsの順で並ぶ() {
        let store = TestStore(initialState: StatsExerciseListFeature.State()) {
            StatsExerciseListFeature()
        }
        #expect(store.state.filteredExercises.map(\.id) == Exercise.presets.map(\.id))
    }

    @Test
    func 部位チップをタップするとその部位の種目だけに絞り込まれる() async {
        let store = TestStore(initialState: StatsExerciseListFeature.State()) {
            StatsExerciseListFeature()
        }

        await store.send(.bodyPartTapped(.legs)) {
            $0.bodyPart = .legs
        }
        #expect(store.state.filteredExercises.allSatisfy { $0.bodyPart == .legs })
    }

    @Test
    func 検索語に一致しない種目は絞り込みから外れる() async {
        let store = TestStore(initialState: StatsExerciseListFeature.State()) {
            StatsExerciseListFeature()
        }

        await store.send(.binding(.set(\.searchText, "ベンチ"))) {
            $0.searchText = "ベンチ"
        }
        #expect(store.state.filteredExercises.map(\.id) == ["bench-press"])
    }

    @Test
    func 種目をタップすると選んだ種目をdelegateで通知する() async {
        let store = TestStore(initialState: StatsExerciseListFeature.State()) {
            StatsExerciseListFeature()
        }

        let squat = Exercise.preset("squat")
        await store.send(.exerciseTapped(squat))
        await store.receive(\.delegate.select, squat)
    }
}
