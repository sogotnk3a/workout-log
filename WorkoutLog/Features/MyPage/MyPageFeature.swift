//
//  MyPageFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

@Reducer
struct MyPageFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {}
}

struct MyPageView: View {
    let store: StoreOf<MyPageFeature>

    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle("マイページ")
        }
    }
}
