//
//  WorkoutStats.swift
//  WorkoutLog
//

import Foundation

/// 分析画面の推移グラフで、1区間をどの単位で区切るか
enum StatsPeriod: String, CaseIterable, Hashable, Codable, Sendable {
    case week, month, year, all
}

/// 分析画面の推移グラフで、どれだけ遡って見るか。棒の単位（週・月）はこれに応じて自動で決まる
enum TrendRange: String, CaseIterable, Hashable {
    case oneMonth, threeMonths, sixMonths, oneYear, all

    var label: String {
        switch self {
        case .oneMonth: "1ヶ月"
        case .threeMonths: "3ヶ月"
        case .sixMonths: "6ヶ月"
        case .oneYear: "1年"
        case .all: "全期間"
        }
    }

    /// 推移グラフの棒1本分の単位。1ヶ月は週ごと、それ以外は月ごと、全期間は区切りなし
    var bucketPeriod: StatsPeriod {
        switch self {
        case .oneMonth: .week
        case .threeMonths, .sixMonths, .oneYear: .month
        case .all: .all
        }
    }

    /// 推移グラフに並べる棒の本数
    var bucketCount: Int {
        switch self {
        case .oneMonth: 4
        case .threeMonths: 3
        case .sixMonths: 6
        case .oneYear: 12
        case .all: 1
        }
    }

    /// 指定した個数分、今から遡った基準日
    func referenceDate(calendar: Calendar, now: Date, offset: Int) -> Date {
        guard offset != 0 else { return now }
        switch bucketPeriod {
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -offset, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -offset, to: now) ?? now
        case .year:
            return calendar.date(byAdding: .year, value: -offset, to: now) ?? now
        case .all:
            return now
        }
    }
}

extension WorkoutSet {
    /// Epley式による推定1RM（1回だけ挙げられる最大重量）。重量・回数のどちらかが未入力なら nil
    var estimated1RM: Double? {
        guard let weight, let reps, reps > 0 else { return nil }
        return weight * (1 + Double(reps) / 30)
    }
}

extension Collection<Workout> {
    /// 指定した期間の開始〜終了（全期間は nil）
    private func periodInterval(_ period: StatsPeriod, calendar: Calendar, now: Date) -> DateInterval? {
        switch period {
        case .week: calendar.dateInterval(of: .weekOfYear, for: now)
        case .month: calendar.dateInterval(of: .month, for: now)
        case .year: calendar.dateInterval(of: .year, for: now)
        case .all: nil
        }
    }

    /// 指定した期間のトレーニング
    func workouts(in period: StatsPeriod, calendar: Calendar, now: Date) -> [Workout] {
        guard let interval = periodInterval(period, calendar: calendar, now: now) else { return Array(self) }
        return workouts(in: interval)
    }

    /// 指定した範囲のトレーニング
    func workouts(in interval: DateInterval) -> [Workout] {
        filter { interval.contains($0.startedAt) }
    }

    /// 記録が1件以上ある種目。`Exercise.presets` の並び順
    var exercisesWithRecords: [Exercise] {
        let recorded = Set(flatMap { $0.exercises.map(\.exercise.id) })
        return Exercise.presets.filter { recorded.contains($0.id) }
    }

    /// 指定した種目・期間で、推定1RMが一番高かったセット（トレーニングの日付つき）。対象のセットが1つもなければ nil
    func best1RMEntry(of exerciseID: Exercise.ID, in period: StatsPeriod, calendar: Calendar, now: Date) -> Best1RMEntry? {
        workouts(in: period, calendar: calendar, now: now)
            .flatMap { workout in
                workout.exercises
                    .filter { $0.exercise.id == exerciseID }
                    .flatMap(\.sets)
                    .compactMap { set in set.estimated1RM.map { Best1RMEntry(date: workout.startedAt, set: set, value: $0) } }
            }
            .max { $0.value < $1.value }
    }

    /// 指定した種目・期間でのベスト推定1RM（セットの中で一番高い値）。対象のセットが1つもなければ nil
    func best1RM(of exerciseID: Exercise.ID, in period: StatsPeriod, calendar: Calendar, now: Date) -> Double? {
        best1RMEntry(of: exerciseID, in: period, calendar: calendar, now: now)?.value
    }
}

/// 期間内で推定1RMが一番高かったセット
struct Best1RMEntry: Equatable {
    let date: Date
    let set: WorkoutSet
    let value: Double
}

extension StatsPeriod {
    /// 対応する `Calendar.Component`。全期間には区切りがないので nil
    var calendarComponent: Calendar.Component? {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        case .all: nil
        }
    }

    /// 「10/4」「9月」「2026年」のような、区間の開始日に対応するラベル
    func dateLabel(for date: Date, calendar: Calendar) -> String {
        switch self {
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let components = calendar.dateComponents([.month, .day], from: start)
            return "\(components.month ?? 0)/\(components.day ?? 0)"
        case .month:
            let components = calendar.dateComponents([.month], from: date)
            return "\(components.month ?? 0)月"
        case .year:
            let components = calendar.dateComponents([.year], from: date)
            return "\(components.year ?? 0)年"
        case .all:
            return "全期間"
        }
    }
}

extension TrendRange {
    /// 「10/25〜10/31」のような、基準日が含まれる区間の範囲ラベル（具体的な日付で出す）
    func periodRangeLabel(referenceDate: Date, calendar: Calendar) -> String {
        switch bucketPeriod {
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { return "" }
            let start = interval.start
            let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(Self.shortDate(start, calendar: calendar))〜\(Self.shortDate(end, calendar: calendar))"
        case .month:
            let components = calendar.dateComponents([.year, .month], from: referenceDate)
            return "\(components.year ?? 0)年\(components.month ?? 0)月"
        case .year:
            let components = calendar.dateComponents([.year], from: referenceDate)
            return "\(components.year ?? 0)年"
        case .all:
            return "全期間"
        }
    }

    private static func shortDate(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.month, .day], from: date)
        return "\(components.month ?? 0)/\(components.day ?? 0)"
    }
}
