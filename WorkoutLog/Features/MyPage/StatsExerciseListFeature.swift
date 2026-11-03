//
//  StatsExerciseListFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// マイページの「分析」ボタンから開く、分析する種目を選ぶ一覧。記録画面の「種目を追加」と同じ見た目
@Reducer
struct StatsExerciseListFeature {
    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var bodyPart: BodyPart?

        var filteredExercises: [Exercise] {
            Exercise.presets.filter { exercise in
                (bodyPart == nil || exercise.bodyPart == bodyPart)
                    && (searchText.isEmpty || exercise.name.localizedStandardContains(searchText))
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case bodyPartTapped(BodyPart?)
        case delegate(Delegate)
        case exerciseTapped(Exercise)

        @CasePathable
        enum Delegate: Equatable {
            case select(Exercise)
        }
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case let .bodyPartTapped(bodyPart):
                state.bodyPart = bodyPart
                return .none

            case let .exerciseTapped(exercise):
                return .send(.delegate(.select(exercise)))
            }
        }
    }
}

struct StatsExerciseListView: View {
    @Bindable var store: StoreOf<StatsExerciseListFeature>

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        BodyPartChip(title: "すべて", isSelected: store.bodyPart == nil) {
                            store.send(.bodyPartTapped(nil))
                        }
                        ForEach(BodyPart.allCases, id: \.self) { part in
                            BodyPartChip(title: part.label, isSelected: store.bodyPart == part) {
                                store.send(.bodyPartTapped(part))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(store.filteredExercises) { exercise in
                    Button {
                        store.send(.exerciseTapped(exercise))
                    } label: {
                        StatsExerciseRow(exercise: exercise)
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "種目を検索")
        .navigationTitle("分析")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BodyPartChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .background(isSelected ? Color.primary : Color(.secondarySystemGroupedBackground), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

private struct StatsExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Text(exercise.bodyPart.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
