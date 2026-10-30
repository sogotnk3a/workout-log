//
//  FriendHistoryFeature.swift
//  WorkoutLog
//

import ComposableArchitecture
import SwiftUI

/// フレンドの過去のトレーニング履歴を表示する。今はモックデータのみ
@Reducer
struct FriendHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var friend: Friend
    }

    enum Action {}
}

struct FriendHistoryView: View {
    let store: StoreOf<FriendHistoryFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        List {
            if store.friend.workouts.isEmpty {
                Text("トレーニングの記録がありません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(store.friend.workouts) { workout in
                FriendWorkoutRow(workout: workout, calendar: calendar)
            }
        }
        .navigationTitle("\(store.friend.name)の記録")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FriendWorkoutRow: View {
    let workout: Workout
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(workout.startedAt.dayTitle(calendar: calendar))
                .font(.headline)
            BodyPartBadges(parts: workout.bodyParts)
            ForEach(workout.exercises) { entry in
                Text("\(entry.exercise.name) \(Array(entry.sets).summary)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
