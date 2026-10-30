//
//  TestSupport.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation

@testable import WorkoutLog

extension Calendar {
    /// テスト用の暦。端末の設定によらず、グレゴリオ暦・日本時間にする
    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

extension Workout {
    /// 指定した種目を1セットずつやったトレーニング
    static func sample(id: UUID, startedAt: Date, minutes: Int = 60, exercises: [Exercise]) -> Workout {
        Workout(
            id: id,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(TimeInterval(minutes * 60)),
            exercises: IdentifiedArray(
                uniqueElements: exercises.enumerated().map { index, exercise in
                    WorkoutExercise(
                        id: UUID(uuidString: "00000000-0000-0000-0001-\(String(format: "%012d", index))")!,
                        exercise: exercise,
                        sets: [WorkoutSet(id: UUID(uuidString: "00000000-0000-0000-0002-\(String(format: "%012d", index))")!, weight: 60, reps: 10)]
                    )
                }
            )
        )
    }
}

extension Exercise {
    static func preset(_ id: String) -> Exercise {
        presets.first { $0.id == id }!
    }
}
