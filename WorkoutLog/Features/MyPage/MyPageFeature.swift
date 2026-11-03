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
    @Reducer
    enum Path {
        case analysis(StatsAnalysisFeature)
        case exerciseList(StatsExerciseListFeature)
    }

    @ObservableState
    struct State: Equatable {
        var path = StackState<Path.State>()
    }

    enum Action {
        case analysisButtonTapped
        case path(StackActionOf<Path>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .analysisButtonTapped:
                state.path.append(.exerciseList(StatsExerciseListFeature.State()))
                return .none

            case let .path(.element(id: _, action: .exerciseList(.delegate(.select(exercise))))):
                state.path.append(.analysis(StatsAnalysisFeature.State(exercise: exercise)))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}

extension MyPageFeature.Path.State: Equatable {}

struct MyPageView: View {
    @Bindable var store: StoreOf<MyPageFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section {
                    Button {
                        store.send(.analysisButtonTapped)
                    } label: {
                        Label("分析", systemImage: "chart.bar.xaxis")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .navigationTitle("マイページ")
        } destination: { store in
            switch store.case {
            case let .analysis(store):
                StatsAnalysisView(store: store)
            case let .exerciseList(store):
                StatsExerciseListView(store: store)
            }
        }
    }
}
