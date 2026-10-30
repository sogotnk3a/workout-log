//
//  Friend.swift
//  WorkoutLog
//

import ComposableArchitecture
import Foundation
import SwiftUI

/// フレンド。トレ中かどうかと、過去のトレーニング履歴を持つ。
/// フレンド機能はいずれサーバーと連携する予定だが、今はモックデータのみ（`docs/specs/app-structure.md`）
struct Friend: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var status: Status
    var workouts: IdentifiedArrayOf<Workout> = []

    enum Status: Equatable, Codable, Sendable {
        case training(startedAt: Date)
        case lastTrained(at: Date)
    }
}

extension Friend.Status {
    /// 「トレ中」「5分前にトレ」の形式
    func text(now: Date) -> String {
        switch self {
        case .training:
            return "トレ中"
        case let .lastTrained(at):
            return "\(at.agoText(now: now))にトレ"
        }
    }

    /// Discordのオンライン表示のような状態の色。トレ中は緑、1時間以内なら黄色、それより前は灰色
    func badgeColor(now: Date) -> Color {
        switch self {
        case .training:
            return .green
        case let .lastTrained(at):
            return now.timeIntervalSince(at) <= 60 * 60 ? .yellow : Color.secondary.opacity(0.6)
        }
    }
}

extension Friend {
    /// やる気を出させるための煽り文。名前は含まない（名前は別に表示する）
    func tauntText(now: Date) -> String {
        switch status {
        case .training:
            return "もう動き出してる。置いていかれるよ"
        case .lastTrained:
            return "もうトレした。お前はまだ？"
        }
    }
}

extension Date {
    /// 「5分前」「2時間前」「3日前」の形式。`RelativeDateTimeFormatter` は日本語ロケールで数字と単位の間にスペースが入るため使わない
    func agoText(now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(self) / 60))
        if minutes < 1 { return "たった今" }
        if minutes < 60 { return "\(minutes)分前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)時間前" }
        return "\(hours / 24)日前"
    }
}

extension IdentifiedArrayOf<Friend> {
    /// トレ中のフレンドを先に、残りは最後にトレーニングした時刻が新しい順に並べる
    var sortedByActivity: [Friend] {
        sorted { lhs, rhs in
            switch (lhs.status, rhs.status) {
            case (.training, .training):
                return false
            case (.training, _):
                return true
            case (_, .training):
                return false
            case let (.lastTrained(l), .lastTrained(r)):
                return l > r
            }
        }
    }
}

extension Friend {
    /// サーバーができるまでのダミーデータ
    static let mock: IdentifiedArrayOf<Friend> = {
        func exercise(_ id: String) -> Exercise {
            Exercise.presets.first { $0.id == id }!
        }
        func workout(startedAt: Date, exerciseIDs: [String]) -> Workout {
            Workout(
                id: UUID(),
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(60 * 60),
                exercises: IdentifiedArray(
                    uniqueElements: exerciseIDs.map { exerciseID in
                        WorkoutExercise(
                            id: UUID(),
                            exercise: exercise(exerciseID),
                            sets: [WorkoutSet(id: UUID(), weight: 60, reps: 10)]
                        )
                    }
                )
            )
        }

        let now = Date.now
        return [
            Friend(
                id: UUID(),
                name: "OREN",
                status: .training(startedAt: now.addingTimeInterval(-15 * 60)),
                workouts: [
                    workout(startedAt: now.addingTimeInterval(-60 * 60 * 24), exerciseIDs: ["bench-press", "incline-dumbbell-press"]),
                    workout(startedAt: now.addingTimeInterval(-60 * 60 * 24 * 3), exerciseIDs: ["squat", "leg-press"]),
                ]
            ),
            Friend(
                id: UUID(),
                name: "SOGO",
                status: .lastTrained(at: now.addingTimeInterval(-5 * 60)),
                workouts: [
                    workout(startedAt: now.addingTimeInterval(-5 * 60), exerciseIDs: ["deadlift", "lat-pulldown"]),
                ]
            ),
            Friend(
                id: UUID(),
                name: "HOTAKA",
                status: .lastTrained(at: now.addingTimeInterval(-60 * 60 * 2)),
                workouts: [
                    workout(startedAt: now.addingTimeInterval(-60 * 60 * 2), exerciseIDs: ["shoulder-press", "side-raise"]),
                ]
            ),
        ]
    }()
}
