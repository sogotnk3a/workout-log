//
//  Exercise.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import SwiftUI

enum BodyPart: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case legs
    case shoulders
    case arms
    case abs

    var label: String {
        switch self {
        case .chest: "胸"
        case .back: "背中"
        case .legs: "脚"
        case .shoulders: "肩"
        case .arms: "腕"
        case .abs: "腹筋"
        }
    }

    /// カレンダーなどで部位を見分けるための色。今は固定で、ユーザーが変える機能は今後追加する
    var color: Color {
        switch self {
        case .chest: Color(red: 0.90, green: 0.28, blue: 0.30)
        case .back: Color(red: 0.18, green: 0.44, blue: 0.87)
        case .legs: Color(red: 0.18, green: 0.62, blue: 0.36)
        case .shoulders: Color(red: 0.94, green: 0.55, blue: 0.0)
        case .arms: Color(red: 0.56, green: 0.31, blue: 0.78)
        case .abs: Color(red: 0.05, green: 0.60, blue: 0.65)
        }
    }

    /// `ExerciseIcon` で使う、部位ごとに見た目を変えるためのSF Symbol
    var iconSystemName: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.climbing"
        case .legs: "figure.stair.stepper"
        case .shoulders: "figure.strengthtraining.functional"
        case .arms: "dumbbell.fill"
        case .abs: "figure.core.training"
        }
    }
}

/// 種目のマスター
struct Exercise: Equatable, Hashable, Identifiable, Codable, Sendable {
    let id: String
    var name: String
    var bodyPart: BodyPart

    /// 推定1RMを出す意味がある種目か。保存した記録にこの種目のスナップショットが残るため、
    /// 保存済みデータのデコードを壊さないよう、プロパティではなく id から判定する
    var supportsOneRepMax: Bool {
        Self.oneRepMaxExerciseIDs.contains(id)
    }

    /// 1RMを測る文化があるバーベルのコンパウンド種目だけに絞る。マシン・補助種目は対象外
    private static let oneRepMaxExerciseIDs: Set<String> = ["bench-press", "squat", "deadlift"]
}

/// 種目一覧・種目の行で使う簡易アイコン。部位ごとに色とSF Symbolを変えている仮のもので、
/// 実際のイラストに差し替えるときはここだけ直せばいい
struct ExerciseIcon: View {
    let exercise: Exercise
    var size: CGFloat = 36

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(exercise.bodyPart.color.gradient.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(exercise.bodyPart.color.opacity(0.25), lineWidth: 1)
            }
            .overlay {
                Image(systemName: exercise.bodyPart.iconSystemName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(exercise.bodyPart.color)
            }
    }
}

extension Exercise {
    /// あらかじめ用意している種目。ユーザーが種目を作る機能は今後追加する
    static let presets: [Exercise] = [
        Exercise(id: "bench-press", name: "ベンチプレス", bodyPart: .chest),
        Exercise(id: "incline-dumbbell-press", name: "インクラインダンベルプレス", bodyPart: .chest),
        Exercise(id: "cable-fly", name: "ケーブルフライ", bodyPart: .chest),
        Exercise(id: "deadlift", name: "デッドリフト", bodyPart: .back),
        Exercise(id: "lat-pulldown", name: "ラットプルダウン", bodyPart: .back),
        Exercise(id: "bent-over-row", name: "ベントオーバーロウ", bodyPart: .back),
        Exercise(id: "squat", name: "スクワット", bodyPart: .legs),
        Exercise(id: "leg-press", name: "レッグプレス", bodyPart: .legs),
        Exercise(id: "leg-curl", name: "レッグカール", bodyPart: .legs),
        Exercise(id: "shoulder-press", name: "ショルダープレス", bodyPart: .shoulders),
        Exercise(id: "side-raise", name: "サイドレイズ", bodyPart: .shoulders),
        Exercise(id: "dumbbell-curl", name: "ダンベルカール", bodyPart: .arms),
        Exercise(id: "triceps-pushdown", name: "トライセプスプッシュダウン", bodyPart: .arms),
        Exercise(id: "crunch", name: "クランチ", bodyPart: .abs),
        Exercise(id: "leg-raise", name: "レッグレイズ", bodyPart: .abs),
    ]
}
