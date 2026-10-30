//
//  Workout.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation

/// 1回のトレーニング
struct Workout: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var exercises: IdentifiedArrayOf<WorkoutExercise> = []
}

/// トレーニング内の1種目
struct WorkoutExercise: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var exercise: Exercise
    var sets: IdentifiedArrayOf<WorkoutSet> = []
}

/// 重量・回数は未入力なら nil。回数が入っているセットを「やったセット」として扱う
struct WorkoutSet: Equatable, Identifiable, Codable, Sendable {
    let id: UUID
    var weight: Double?
    var reps: Int?

    var isRecorded: Bool { reps != nil }
}

extension Workout {
    /// 回数が入力されたセットだけを残したトレーニング。セットが1つもない種目は除く
    var recordedOnly: Workout {
        var workout = self
        workout.exercises = IdentifiedArray(
            uniqueElements: exercises.compactMap { entry in
                var entry = entry
                entry.sets = entry.sets.filter(\.isRecorded)
                return entry.sets.isEmpty ? nil : entry
            }
        )
        return workout
    }
}

extension Workout {
    /// このトレーニングで鍛えた部位（`BodyPart.allCases` の順）
    var bodyParts: [BodyPart] {
        let parts = Set(exercises.map(\.exercise.bodyPart))
        return BodyPart.allCases.filter(parts.contains)
    }

    var recordedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isRecorded).count }
    }
}

extension Collection<Workout> {
    /// 指定した種目を最後に行ったときのセット（新しい順に並んでいる前提）
    func lastSets(of exerciseID: Exercise.ID) -> [WorkoutSet]? {
        for workout in self {
            if let entry = workout.exercises.first(where: { $0.exercise.id == exerciseID }) {
                return Array(entry.sets)
            }
        }
        return nil
    }
}

extension WorkoutSet {
    static func formatted(weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension [WorkoutSet] {
    /// 「60kg × 10, 8, 7」の形式。重量が混ざる場合は「60kg × 10, 62.5kg × 8」、重量なしは「10回」
    var summary: String {
        let reps = map { $0.reps.map(String.init) ?? "-" }
        if let weight = first?.weight, allSatisfy({ $0.weight == weight }) {
            return "\(WorkoutSet.formatted(weight: weight))kg × " + reps.joined(separator: ", ")
        }
        return map { set in
            let reps = set.reps.map(String.init) ?? "-"
            guard let weight = set.weight else { return "\(reps)回" }
            return "\(WorkoutSet.formatted(weight: weight))kg × \(reps)"
        }
        .joined(separator: ", ")
    }
}

extension SharedKey where Self == FileStorageKey<IdentifiedArrayOf<Workout>>.Default {
    /// 完了したトレーニングの履歴（開始日時の新しい順）
    static var workoutHistory: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "workout-history.json")), default: []]
    }
}

extension SharedKey where Self == FileStorageKey<Workout?>.Default {
    /// 記録中のトレーニング。アプリを閉じても残り、開き直すと続きから記録できる
    static var activeWorkout: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "active-workout.json")), default: nil]
    }
}
