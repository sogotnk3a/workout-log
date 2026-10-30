//
//  PersonalBestFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// マイページの「自己ベスト」ボタンから開く、種目ごとの自己ベスト一覧
@Reducer
struct PersonalBestFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.workoutHistory) var history
        var bodyPartFilter: BodyPart?
    }

    enum Action {
        case bodyPartFilterTapped(BodyPart?)
        case delegate(Delegate)
        case exerciseTapped(Exercise.ID)

        @CasePathable
        enum Delegate: Equatable {
            case exerciseTapped(Exercise.ID)
        }
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .bodyPartFilterTapped(part):
                state.bodyPartFilter = part
                return .none

            case .delegate:
                return .none

            case let .exerciseTapped(id):
                return .send(.delegate(.exerciseTapped(id)))
            }
        }
    }
}

struct PersonalBestView: View {
    @Bindable var store: StoreOf<PersonalBestFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        let bests = bests
        List {
            Section {
                BodyPartFilterChips(
                    selected: store.bodyPartFilter,
                    action: { store.send(.bodyPartFilterTapped($0), animation: .default) }
                )
            }

            if bests.isEmpty {
                ContentUnavailableView("自己ベストはまだありません", systemImage: "trophy")
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(bests) { best in
                        Button {
                            store.send(.exerciseTapped(best.exercise.id))
                        } label: {
                            ExerciseBestRow(best: best, calendar: calendar)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("種目をタップすると重量の推移を見られます")
                }
            }
        }
        .navigationTitle("自己ベスト")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 種目ごとの自己ベスト（部位の絞り込みがあればそれも適用する）
    private var bests: [ExerciseBest] {
        let bests = store.history.exerciseBests
        return store.bodyPartFilter.map { filter in bests.filter { $0.exercise.bodyPart == filter } } ?? bests
    }
}

private struct ExerciseBestRow: View {
    let best: ExerciseBest
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 12) {
            ExerciseIcon(exercise: best.exercise, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(best.exercise.name)
                    .font(.subheadline.weight(.semibold))
                Text(best.date.dayTitle(calendar: calendar))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(WorkoutSet.formatted(weight: best.weight))kg × \(best.reps)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
