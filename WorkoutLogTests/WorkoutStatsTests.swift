//
//  WorkoutStatsTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

struct WorkoutStatsTests {
    let calendar = Calendar.tokyo
    var now: Date { calendar.date(2026, 10, 16, 9, 30) }

    @Test
    func 推定1RMはEpley式で重量times1たす回数わる30() {
        let set = WorkoutSet(id: UUID(1), weight: 60, reps: 10)
        #expect(set.estimated1RM == 80)
    }

    @Test
    func 推定1RMは重量か回数が未入力ならnil() {
        #expect(WorkoutSet(id: UUID(1), weight: nil, reps: 10).estimated1RM == nil)
        #expect(WorkoutSet(id: UUID(2), weight: 60, reps: nil).estimated1RM == nil)
    }

    @Test
    func ベスト推定1RMは指定した期間のセットの中で一番高い値を取る() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [
                        WorkoutSet(id: UUID(100), weight: 60, reps: 10),
                        WorkoutSet(id: UUID(101), weight: 90, reps: 1),
                    ]),
                ]
            ),
        ]

        let best = history.best1RM(of: "bench-press", in: .all, calendar: calendar, now: now)
        #expect(abs((best ?? 0) - 93) < 0.0001)
    }

    @Test
    func ベスト推定1RMは指定した期間のトレーニングだけを対象にする() {
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 9, 30, 7, 0), exercises: [.preset("bench-press")]),
        ]

        let monthBest = history.best1RM(of: "bench-press", in: .month, calendar: calendar, now: now)
        #expect(monthBest == nil)

        let allBest = history.best1RM(of: "bench-press", in: .all, calendar: calendar, now: now)
        #expect(allBest == 80)
    }

    @Test
    func ベスト推定1RMは回数が入力されていないセットを対象にしない() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [
                        WorkoutSet(id: UUID(100), weight: 100, reps: nil),
                    ]),
                ]
            ),
        ]

        #expect(history.best1RM(of: "bench-press", in: .all, calendar: calendar, now: now) == nil)
    }

    @Test
    func ベストセットは推定1RMが一番高いセットとそのトレーニング日を返す() {
        let bestDate = calendar.date(2026, 10, 10, 7, 0)
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 1, 7, 0), exercises: [.preset("bench-press")]),
            Workout(
                id: UUID(2),
                startedAt: bestDate,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [
                        WorkoutSet(id: UUID(100), weight: 90, reps: 1),
                    ]),
                ]
            ),
        ]

        let entry = history.best1RMEntry(of: "bench-press", in: .all, calendar: calendar, now: now)
        #expect(entry?.date == bestDate)
        #expect(abs((entry?.value ?? 0) - 93) < 0.0001)
        #expect(entry?.set.weight == 90)
        #expect(entry?.set.reps == 1)
    }

    @Test
    func 推移グラフの範囲は期間に応じて棒の単位と本数が決まる() {
        #expect(TrendRange.oneMonth.bucketPeriod == .week)
        #expect(TrendRange.oneMonth.bucketCount == 4)
        #expect(TrendRange.threeMonths.bucketPeriod == .month)
        #expect(TrendRange.threeMonths.bucketCount == 3)
        #expect(TrendRange.sixMonths.bucketPeriod == .month)
        #expect(TrendRange.sixMonths.bucketCount == 6)
        #expect(TrendRange.oneYear.bucketPeriod == .month)
        #expect(TrendRange.oneYear.bucketCount == 12)
        #expect(TrendRange.all.bucketPeriod == .all)
        #expect(TrendRange.all.bucketCount == 1)
    }

    @Test
    func 期間の範囲ラベルは区間の単位に応じて具体的な日付で出る() {
        let reference = calendar.date(2026, 10, 16, 9, 30)

        #expect(TrendRange.oneMonth.periodRangeLabel(referenceDate: reference, calendar: calendar) == "10/11〜10/17")
        #expect(TrendRange.threeMonths.periodRangeLabel(referenceDate: reference, calendar: calendar) == "2026年10月")
        #expect(TrendRange.oneYear.periodRangeLabel(referenceDate: reference, calendar: calendar) == "2026年10月")
        #expect(TrendRange.all.periodRangeLabel(referenceDate: reference, calendar: calendar) == "全期間")
    }
}
