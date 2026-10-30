//
//  ActiveWorkoutBar.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import SwiftUI

/// 記録画面を最小化している間、タブバーの上に出るバー。タップで記録画面に戻る
struct ActiveWorkoutBar: View {
    let workout: Workout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.orange)
                    .frame(width: 10, height: 10)
                ElapsedTimeText(startedAt: workout.startedAt)
                    .font(.subheadline.weight(.bold))
                Text(progress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("記録中のトレーニングを開く")
    }

    /// 今やっている種目（最後に記録した種目）と、記録したセット数
    private var progress: String {
        let current = workout.exercises.last { $0.sets.contains(where: \.isRecorded) } ?? workout.exercises.first
        guard let current else { return "種目を追加してください" }
        let recorded = current.sets.filter(\.isRecorded).count
        return recorded == 0 ? current.exercise.name : "\(current.exercise.name) \(recorded)セット"
    }
}
