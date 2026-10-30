//
//  HomeFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct HomeFeatureTests {
    @Test
    func フレンドをタップするとそのフレンドの履歴ページが開く() async {
        let friend = Friend(id: UUID(1), name: "テスト", status: .lastTrained(at: .now))
        let store = TestStore(initialState: HomeFeature.State(friends: [friend])) {
            HomeFeature()
        }

        await store.send(.friendTapped(friend.id)) {
            $0.path[id: 0] = FriendHistoryFeature.State(friend: friend)
        }
    }
}
