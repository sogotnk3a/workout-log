//
//  PersonalBestFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct PersonalBestFeatureTests {
    @Test
    func 開いたときは部位の絞り込みは選ばれていない() {
        let store = TestStore(initialState: PersonalBestFeature.State()) {
            PersonalBestFeature()
        }
        #expect(store.state.bodyPartFilter == nil)
    }

    @Test
    func 部位チップをタップすると絞り込みが変わる() async {
        let store = TestStore(initialState: PersonalBestFeature.State()) {
            PersonalBestFeature()
        }

        await store.send(.bodyPartFilterTapped(.chest)) {
            $0.bodyPartFilter = .chest
        }
        await store.send(.bodyPartFilterTapped(nil)) {
            $0.bodyPartFilter = nil
        }
    }

    @Test
    func 種目をタップすると親に通知する() async {
        let store = TestStore(initialState: PersonalBestFeature.State()) {
            PersonalBestFeature()
        }

        await store.send(.exerciseTapped("bench-press"))
        await store.receive(\.delegate.exerciseTapped)
    }
}
