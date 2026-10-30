//
//  StartWorkoutFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// ＋を押したときに出る開始シート。ルーティンから始める機能は今後追加する
@Reducer
struct StartWorkoutFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action {
        case delegate(Delegate)
        case startEmptyButtonTapped

        @CasePathable
        enum Delegate: Equatable {
            case startEmpty
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none

            case .startEmptyButtonTapped:
                return .send(.delegate(.startEmpty))
            }
        }
    }
}

struct StartWorkoutView: View {
    let store: StoreOf<StartWorkoutFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日はどれをやる？")
                    .font(.title2.weight(.heavy))
                Text("前回の重量と回数は、入力ページで薄く表示されます")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ContentUnavailableView(
                "ルーティンはまだありません",
                systemImage: "list.bullet.rectangle",
                description: Text("よくやるメニューをルーティンとして登録すると、ここから1回のタップで始められます")
            )
            .frame(maxHeight: .infinity)

            Button {
                store.send(.startEmptyButtonTapped)
            } label: {
                Text("空で始める")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }
}
