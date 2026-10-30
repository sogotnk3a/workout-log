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
    func 部位ごとの回数は指定した期間のトレーニングだけを数える() {
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 16, 7, 0), exercises: [.preset("bench-press")]),
            .sample(id: UUID(2), startedAt: calendar.date(2026, 10, 1, 7, 0), exercises: [.preset("bench-press"), .preset("squat")]),
            .sample(id: UUID(3), startedAt: calendar.date(2026, 9, 30, 7, 0), exercises: [.preset("squat")]),
        ]

        let monthCounts = history.bodyPartCounts(in: .month, calendar: calendar, now: now)
        #expect(monthCounts.first { $0.part == .chest }?.count == 2)
        #expect(monthCounts.first { $0.part == .legs }?.count == 1)

        let allCounts = history.bodyPartCounts(in: .all, calendar: calendar, now: now)
        #expect(allCounts.first { $0.part == .legs }?.count == 2)
    }

    @Test
    func 部位ごとの回数は過去の月を指定すると以降の月のトレーニングは数えない() {
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 16, 7, 0), exercises: [.preset("bench-press")]),
        ]

        let mayReference = calendar.date(2026, 5, 16, 9, 30)
        let mayCounts = history.bodyPartCounts(in: .month, calendar: calendar, now: mayReference)

        #expect(mayCounts.allSatisfy { $0.count == 0 })
    }

    @Test
    func 部位ごとの回数は部位がない場合は0でBodyPartの全部位が揃う() {
        let counts = IdentifiedArrayOf<Workout>().bodyPartCounts(in: .all, calendar: calendar, now: now)
        #expect(counts.map(\.part) == BodyPart.allCases)
        #expect(counts.allSatisfy { $0.count == 0 })
    }

    @Test
    func 種目ごとの回数は指定した期間のトレーニングだけを数え回数が多い順に並ぶ() {
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 16, 7, 0), exercises: [.preset("bench-press")]),
            .sample(id: UUID(2), startedAt: calendar.date(2026, 10, 10, 7, 0), exercises: [.preset("bench-press"), .preset("squat")]),
            .sample(id: UUID(3), startedAt: calendar.date(2026, 9, 1, 7, 0), exercises: [.preset("bench-press")]),
        ]

        let counts = history.exerciseCounts(in: .month, calendar: calendar, now: now)

        #expect(counts.prefix(2).map(\.exercise.id) == ["bench-press", "squat"])
        #expect(counts.prefix(2).map(\.count) == [2, 1])
        #expect(counts.count == Exercise.presets.count)
        #expect(counts.dropFirst(2).allSatisfy { $0.count == 0 })
    }

    @Test
    func 種目ごとの回数は1回のトレーニングで同じ種目を複数回やっても1回として数える() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(100), weight: 60, reps: 10)]),
                    WorkoutExercise(id: UUID(11), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(101), weight: 60, reps: 8)]),
                ]
            ),
        ]

        let counts = history.exerciseCounts(in: .week, calendar: calendar, now: now)

        #expect(counts.first { $0.exercise.id == "bench-press" }?.count == 1)
    }

    @Test
    func 種目ごとの回数は記録がなければ全種目が0件でプリセットの順に並ぶ() {
        let counts = IdentifiedArrayOf<Workout>().exerciseCounts(in: .all, calendar: calendar, now: now)
        #expect(counts.map(\.exercise.id) == Exercise.presets.map(\.id))
        #expect(counts.allSatisfy { $0.count == 0 })
    }

    @Test
    func 自己ベストは一番重い重量を種目ごとに選ぶ() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 10), minutes: 60, exercises: [.preset("bench-press")]),
            heavierBenchPress(startedAt: calendar.date(2026, 10, 12)),
        ]

        let bests = history.exerciseBests

        let benchBest = bests.first { $0.exercise.id == "bench-press" }
        #expect(benchBest?.weight == 100)
        #expect(benchBest?.reps == 3)
        #expect(benchBest?.date == calendar.date(2026, 10, 12))
    }

    @Test
    func 自己ベストは重量が同じなら回数が多い方を選ぶ() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: calendar.date(2026, 10, 10),
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("squat"), sets: [WorkoutSet(id: UUID(100), weight: 80, reps: 5)]),
                ]
            ),
            Workout(
                id: UUID(2),
                startedAt: calendar.date(2026, 10, 12),
                exercises: [
                    WorkoutExercise(id: UUID(11), exercise: .preset("squat"), sets: [WorkoutSet(id: UUID(101), weight: 80, reps: 8)]),
                ]
            ),
        ]

        let best = history.exerciseBests.first { $0.exercise.id == "squat" }

        #expect(best?.reps == 8)
    }

    @Test
    func 自己ベストは重量未入力のセットを無視する() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: .distantPast,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("leg-raise"), sets: [WorkoutSet(id: UUID(100), weight: nil, reps: 20)]),
                ]
            ),
        ]

        #expect(history.exerciseBests.isEmpty)
    }

    @Test
    func 自己ベストは種目のプリセットの順に並ぶ() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout.sample(id: UUID(1), startedAt: .distantPast, exercises: [.preset("squat"), .preset("bench-press")]),
        ]

        #expect(history.exerciseBests.map(\.exercise.id) == ["bench-press", "squat"])
    }

    @Test
    func 最近の種目は先頭のトレーニングに含まれる種目だけを返す() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout.sample(id: UUID(1), startedAt: calendar.date(2026, 10, 16), exercises: [.preset("bench-press"), .preset("squat")]),
            Workout.sample(id: UUID(2), startedAt: calendar.date(2026, 10, 10), exercises: [.preset("lat-pulldown")]),
        ]

        #expect(history.recentExercises.map(\.id) == ["bench-press", "squat"])
    }

    @Test
    func 最近の種目は同じトレーニング内の重複を1回にまとめる() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(100), weight: 60, reps: 10)]),
                    WorkoutExercise(id: UUID(11), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(101), weight: 60, reps: 8)]),
                ]
            ),
        ]

        #expect(history.recentExercises.map(\.id) == ["bench-press"])
    }

    @Test
    func 履歴が空なら最近の種目も空() {
        #expect(IdentifiedArrayOf<Workout>().recentExercises.isEmpty)
    }

    @Test
    func 推定1RMはEpley式で計算する() {
        let set = WorkoutSet(id: UUID(1), weight: 100, reps: 3)
        #expect(abs(set.estimatedOneRepMax! - 110) < 0.0001)
    }

    @Test
    func 重量か回数が未入力なら推定1RMはnil() {
        #expect(WorkoutSet(id: UUID(1), weight: nil, reps: 5).estimatedOneRepMax == nil)
        #expect(WorkoutSet(id: UUID(2), weight: 50, reps: nil).estimatedOneRepMax == nil)
    }

    @Test
    func 重量の推移は推定1RM指定なら週ごとの最大推定1RMを古い順に並べる() {
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: lastWeekStart.addingTimeInterval(3600),
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(100), weight: 80, reps: 5)]),
                ]
            ),
            Workout(
                id: UUID(2),
                startedAt: thisWeekStart.addingTimeInterval(3600),
                exercises: [
                    WorkoutExercise(id: UUID(11), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(101), weight: 90, reps: 3)]),
                ]
            ),
        ]

        let trend = history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .oneMonth, calendar: calendar, now: now)

        #expect(trend.count == 4)
        #expect(trend[0...1].allSatisfy { $0.value == nil })
        #expect(trend[2].value == 80 * (1 + 5.0 / 30))
        #expect(trend[3].value == 90 * (1 + 3.0 / 30))
    }

    @Test
    func 重量の推移はボリューム指定ならその区間のボリュームの合計を使う() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("lat-pulldown"), sets: [
                        WorkoutSet(id: UUID(100), weight: 50, reps: 10),
                        WorkoutSet(id: UUID(101), weight: 55, reps: 8),
                    ]),
                ]
            ),
        ]

        let trend = history.weightTrend(for: .preset("lat-pulldown"), metric: .volume, range: .oneMonth, calendar: calendar, now: now)

        #expect(trend.last?.value == 940)
    }

    @Test
    func 重量の推移はビッグ3でもボリュームを指定すればボリュームが取れる() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout(
                id: UUID(1),
                startedAt: now,
                exercises: [
                    WorkoutExercise(id: UUID(10), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(100), weight: 80, reps: 5)]),
                ]
            ),
        ]

        let trend = history.weightTrend(for: .preset("bench-press"), metric: .volume, range: .oneMonth, calendar: calendar, now: now)

        #expect(trend.last?.value == 400)
    }

    @Test
    func ボリュームは重量を入力したセットだけ重量times回数の合計を取る() {
        let sets: [WorkoutSet] = [
            WorkoutSet(id: UUID(1), weight: 50, reps: 10),
            WorkoutSet(id: UUID(2), weight: nil, reps: 12),
            WorkoutSet(id: UUID(3), weight: 60, reps: 5),
        ]

        #expect(sets.volume == 800)
    }

    @Test
    func 重量を入力したセットが1つもなければボリュームはnil() {
        let sets: [WorkoutSet] = [WorkoutSet(id: UUID(1), weight: nil, reps: 10)]
        #expect(sets.volume == nil)
    }

    @Test
    func 重量の推移は違う種目のセットを数えない() {
        let history: IdentifiedArrayOf<Workout> = [
            Workout.sample(id: UUID(1), startedAt: now, exercises: [.preset("squat")]),
        ]

        let trend = history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .oneMonth, calendar: calendar, now: now)

        #expect(trend.allSatisfy { $0.value == nil })
    }

    @Test
    func 重量の推移は選んだ期間に応じて区間の単位と数が変わる() {
        let history = IdentifiedArrayOf<Workout>()

        #expect(history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .oneMonth, calendar: calendar, now: now).count == 4)
        #expect(history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .threeMonths, calendar: calendar, now: now).count == 3)
        #expect(history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .sixMonths, calendar: calendar, now: now).count == 6)
        #expect(history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .oneYear, calendar: calendar, now: now).count == 12)
        #expect(history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .all, calendar: calendar, now: now).count == 1)

        let monthTrend = history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .threeMonths, calendar: calendar, now: now)
        #expect(monthTrend.last?.label == "10月")

        let allTrend = history.weightTrend(for: .preset("bench-press"), metric: .oneRepMax, range: .all, calendar: calendar, now: now)
        #expect(allTrend.first?.label == "全期間")
    }

    @Test
    func 前区間比は値がある直近2区間分を比べる() {
        let weeks = [
            WeightTrendPoint(bucketStart: .distantPast, label: "3週前", value: nil),
            WeightTrendPoint(bucketStart: Date(timeIntervalSince1970: 1), label: "2週前", value: 100),
            WeightTrendPoint(bucketStart: Date(timeIntervalSince1970: 2), label: "先週", value: nil),
            WeightTrendPoint(bucketStart: Date(timeIntervalSince1970: 3), label: "今週", value: 110),
        ]

        let latest = weeks.latestTwoValues

        #expect(latest?.current == 110)
        #expect(latest?.previous == 100)
    }

    @Test
    func データが1つもなければ前区間比はnil() {
        let weeks = [WeightTrendPoint(bucketStart: .distantPast, label: "今週", value: nil)]
        #expect(weeks.latestTwoValues == nil)
    }

    @Test
    func 指標のnextとpreviousは回数ボリュームセット数を循環する() {
        #expect(StatsMetric.count.next == .volume)
        #expect(StatsMetric.volume.next == .setCount)
        #expect(StatsMetric.setCount.next == .count)
        #expect(StatsMetric.count.previous == .setCount)
        #expect(StatsMetric.volume.previous == .count)
        #expect(StatsMetric.setCount.previous == .volume)
    }

    @Test
    func 期間の範囲ラベルは区間の単位に応じて具体的な日付で出る() {
        let reference = calendar.date(2026, 10, 16, 9, 30)

        #expect(TrendRange.oneMonth.periodRangeLabel(referenceDate: reference, calendar: calendar) == "10/11〜10/17")
        #expect(TrendRange.threeMonths.periodRangeLabel(referenceDate: reference, calendar: calendar) == "2026年10月")
        #expect(TrendRange.oneYear.periodRangeLabel(referenceDate: reference, calendar: calendar) == "2026年10月")
        #expect(TrendRange.all.periodRangeLabel(referenceDate: reference, calendar: calendar) == "全期間")
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
    func 期間全体の範囲はbucketCount分をまとめた区間になる() {
        let interval = TrendRange.threeMonths.interval(calendar: calendar, referenceDate: now)

        #expect(interval?.start == calendar.date(2026, 8, 1))
        #expect(interval?.end == calendar.date(2026, 11, 1))
        #expect(TrendRange.all.interval(calendar: calendar, referenceDate: now) == nil)
    }

    @Test
    func 種目の値をTrendRangeで集計すると期間全体の合計になりbucketPeriod単体とは異なる() {
        let history: IdentifiedArrayOf<Workout> = [
            .sample(id: UUID(1), startedAt: calendar.date(2026, 10, 16, 7, 0), exercises: [.preset("bench-press")]),
            .sample(id: UUID(2), startedAt: calendar.date(2026, 9, 10, 7, 0), exercises: [.preset("bench-press")]),
            .sample(id: UUID(3), startedAt: calendar.date(2026, 8, 5, 7, 0), exercises: [.preset("bench-press")]),
            .sample(id: UUID(4), startedAt: calendar.date(2026, 7, 1, 7, 0), exercises: [.preset("bench-press")]),
        ]

        let threeMonthTotal = history.exerciseStats(metric: .count, in: .threeMonths, calendar: calendar, referenceDate: now)
        #expect(threeMonthTotal.first { $0.exercise.id == "bench-press" }?.value == 3)

        let bucketPeriodOnly = history.exerciseStats(metric: .count, in: TrendRange.threeMonths.bucketPeriod, calendar: calendar, now: now)
        #expect(bucketPeriodOnly.first { $0.exercise.id == "bench-press" }?.value == 1)
    }

    private func heavierBenchPress(startedAt: Date) -> Workout {
        Workout(
            id: UUID(2),
            startedAt: startedAt,
            exercises: [
                WorkoutExercise(id: UUID(20), exercise: .preset("bench-press"), sets: [WorkoutSet(id: UUID(200), weight: 100, reps: 3)]),
            ]
        )
    }
}
