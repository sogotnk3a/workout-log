//
//  ExercisePickerFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 種目を1つ選ぶシート。選んだらすぐ閉じて、親がその種目の入力ページを開く
@Reducer
struct ExercisePickerFeature {
    @ObservableState
    struct State: Equatable {
        var searchText = ""
        var bodyPart: BodyPart?
        @SharedReader(.workoutHistory) var history

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
        case cancelButtonTapped
        case delegate(Delegate)
        case exerciseTapped(Exercise)

        @CasePathable
        enum Delegate: Equatable {
            case select(Exercise)
        }
    }

    @Dependency(\.dismiss) var dismiss

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding, .delegate:
                return .none

            case let .bodyPartTapped(bodyPart):
                state.bodyPart = bodyPart
                return .none

            case .cancelButtonTapped:
                return .run { _ in await dismiss() }

            case let .exerciseTapped(exercise):
                return .run { send in
                    await send(.delegate(.select(exercise)))
                    await dismiss()
                }
            }
        }
    }
}

struct ExercisePickerView: View {
    @Bindable var store: StoreOf<ExercisePickerFeature>

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
                        ExerciseRow(exercise: exercise, lastSets: store.history.lastSets(of: exercise.id))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "種目を検索")
        .navigationTitle("種目を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { store.send(.cancelButtonTapped) }
            }
        }
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

private struct ExerciseRow: View {
    let exercise: Exercise
    let lastSets: [WorkoutSet]?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body.weight(.semibold))
                Text(subtitle)
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

    private var subtitle: String {
        guard let lastSets, !lastSets.isEmpty else { return exercise.bodyPart.label }
        return "\(exercise.bodyPart.label) ・ 前回 \(lastSets.summary)"
    }
}
