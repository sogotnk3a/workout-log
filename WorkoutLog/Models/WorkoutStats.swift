//
//  WorkoutStats.swift
//  WorkoutLog
//

import Foundation

/// マイページの「部位ごとの回数」を絞り込む期間
enum StatsPeriod: String, CaseIterable, Hashable, Codable, Sendable {
    case week, month, year, all

    /// 回数のカードに出す文言
    var statLabel: String {
        switch self {
        case .week: "今週"
        case .month: "今月"
        case .year: "今年"
        case .all: "全期間"
        }
    }
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

    /// 指定した個数分、今から遡った基準日。他の画面に部位・種目の内訳を引き継ぐときにも使う
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

    /// 指定した期間に鍛えた部位ごとの回数（`BodyPart.allCases` の順）
    func bodyPartCounts(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(part: BodyPart, count: Int)] {
        var counts: [BodyPart: Int] = [:]
        for workout in workouts(in: period, calendar: calendar, now: now) {
            for part in workout.bodyParts {
                counts[part, default: 0] += 1
            }
        }
        return BodyPart.allCases.map { ($0, counts[$0] ?? 0) }
    }

    /// 指定した期間にやった種目ごとの回数（回数が多い順、同数なら種目のプリセットの順）。
    /// 1回のトレーニングで同じ種目を複数回やっても1回として数える。まだやっていない種目も0件として含む
    func exerciseCounts(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(exercise: Exercise, count: Int)] {
        exerciseCounts(of: workouts(in: period, calendar: calendar, now: now))
    }

    private func exerciseCounts(of workouts: [Workout]) -> [(exercise: Exercise, count: Int)] {
        var counts: [Exercise.ID: Int] = [:]
        for workout in workouts {
            var seen = Set<Exercise.ID>()
            for entry in workout.exercises where seen.insert(entry.exercise.id).inserted {
                counts[entry.exercise.id, default: 0] += 1
            }
        }
        return Exercise.presets
            .map { ($0, counts[$0.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// 指定した期間に鍛えた部位ごとのセット数（回数が入力されたセットだけを数える）
    func bodyPartSetCounts(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(part: BodyPart, count: Int)] {
        var counts: [BodyPart: Int] = [:]
        for workout in workouts(in: period, calendar: calendar, now: now) {
            for entry in workout.exercises {
                counts[entry.exercise.bodyPart, default: 0] += entry.sets.filter(\.isRecorded).count
            }
        }
        return BodyPart.allCases.map { ($0, counts[$0] ?? 0) }
    }

    /// 指定した期間に鍛えた部位ごとのボリューム（重量×回数の合計）
    func bodyPartVolumes(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(part: BodyPart, volume: Double)] {
        var volumes: [BodyPart: Double] = [:]
        for workout in workouts(in: period, calendar: calendar, now: now) {
            for entry in workout.exercises {
                guard let volume = Array(entry.sets).volume else { continue }
                volumes[entry.exercise.bodyPart, default: 0] += volume
            }
        }
        return BodyPart.allCases.map { ($0, volumes[$0] ?? 0) }
    }

    /// 指定した期間にやった種目ごとのセット数（回数が多い順、同数なら種目のプリセットの順）。
    /// まだやっていない種目も0件として含む
    func exerciseSetCounts(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(exercise: Exercise, count: Int)] {
        exerciseSetCounts(of: workouts(in: period, calendar: calendar, now: now))
    }

    private func exerciseSetCounts(of workouts: [Workout]) -> [(exercise: Exercise, count: Int)] {
        var counts: [Exercise.ID: Int] = [:]
        for workout in workouts {
            for entry in workout.exercises {
                counts[entry.exercise.id, default: 0] += entry.sets.filter(\.isRecorded).count
            }
        }
        return Exercise.presets
            .map { ($0, counts[$0.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// 指定した期間にやった種目ごとのボリューム（重量が多い順、同数なら種目のプリセットの順）。
    /// まだやっていない種目も0として含む
    func exerciseVolumes(in period: StatsPeriod, calendar: Calendar, now: Date) -> [(exercise: Exercise, volume: Double)] {
        exerciseVolumes(of: workouts(in: period, calendar: calendar, now: now))
    }

    private func exerciseVolumes(of workouts: [Workout]) -> [(exercise: Exercise, volume: Double)] {
        var volumes: [Exercise.ID: Double] = [:]
        for workout in workouts {
            for entry in workout.exercises {
                guard let volume = Array(entry.sets).volume else { continue }
                volumes[entry.exercise.id, default: 0] += volume
            }
        }
        return Exercise.presets
            .map { ($0, volumes[$0.id] ?? 0) }
            .sorted { $0.1 > $1.1 }
    }

    /// 部位ごとの値。指標（回数・ボリューム・セット数）で中身を切り替える
    func bodyPartStats(metric: StatsMetric, in period: StatsPeriod, calendar: Calendar, now: Date) -> [(part: BodyPart, value: Double)] {
        switch metric {
        case .count:
            bodyPartCounts(in: period, calendar: calendar, now: now).map { ($0.part, Double($0.count)) }
        case .volume:
            bodyPartVolumes(in: period, calendar: calendar, now: now).map { ($0.part, $0.volume) }
        case .setCount:
            bodyPartSetCounts(in: period, calendar: calendar, now: now).map { ($0.part, Double($0.count)) }
        }
    }

    /// 種目ごとの値。指標（回数・ボリューム・セット数）で中身を切り替える
    func exerciseStats(metric: StatsMetric, in period: StatsPeriod, calendar: Calendar, now: Date) -> [(exercise: Exercise, value: Double)] {
        exerciseStats(metric: metric, of: workouts(in: period, calendar: calendar, now: now))
    }

    /// 種目ごとの値。`range` が示す期間全体（bucketCount分の区間をまとめた範囲）を集計する。
    /// 「3ヶ月の実績」のように、選んだ期間のトータルを出したいときに使う（`range.bucketPeriod` 単体の集計とは異なる）
    func exerciseStats(metric: StatsMetric, in range: TrendRange, calendar: Calendar, referenceDate: Date) -> [(exercise: Exercise, value: Double)] {
        let workoutsInRange = range.interval(calendar: calendar, referenceDate: referenceDate)
            .map { workouts(in: $0) } ?? Array(self)
        return exerciseStats(metric: metric, of: workoutsInRange)
    }

    private func exerciseStats(metric: StatsMetric, of workouts: [Workout]) -> [(exercise: Exercise, value: Double)] {
        switch metric {
        case .count:
            exerciseCounts(of: workouts).map { ($0.exercise, Double($0.count)) }
        case .volume:
            exerciseVolumes(of: workouts).map { ($0.exercise, $0.volume) }
        case .setCount:
            exerciseSetCounts(of: workouts).map { ($0.exercise, Double($0.count)) }
        }
    }
}

/// マイページの分析で、回数・ボリューム・セット数のどれで見るか
enum StatsMetric: String, CaseIterable, Hashable {
    case count, volume, setCount

    var label: String {
        switch self {
        case .count: "回数"
        case .volume: "ボリューム"
        case .setCount: "セット数"
        }
    }

    /// グラフ・行に出す値の文言
    func formattedValue(_ value: Double) -> String {
        switch self {
        case .count: "\(Int(value))回"
        case .volume: "\(WorkoutSet.formatted(weight: value))kg"
        case .setCount: "\(Int(value))セット"
        }
    }

    /// ←→で指標を切り替えるときの次・前（端まで行ったら逆側から回り込む）
    var next: StatsMetric {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var previous: StatsMetric {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index - 1 + all.count) % all.count]
    }
}

/// マイページの「部位ごとの回数」で、部位単位と種目単位のどちらで見るか
enum StatsMode: String, CaseIterable, Hashable {
    case bodyPart, exercise

    var label: String {
        switch self {
        case .bodyPart: "部位"
        case .exercise: "種目"
        }
    }
}

/// 種目ごとの自己ベスト。一番重い重量（同じ重量なら回数が多い方）
struct ExerciseBest: Equatable, Identifiable {
    let exercise: Exercise
    let weight: Double
    let reps: Int
    let date: Date

    var id: Exercise.ID { exercise.id }
}

extension Collection<Workout> {
    /// 直近1回のトレーニングに含まれる種目（新しい順に並んでいる前提で、先頭のトレーニングを見る）。
    /// 1回のトレーニングで同じ種目を複数回やっても1回として数える
    var recentExercises: [Exercise] {
        guard let latest = first else { return [] }
        var seen = Set<Exercise.ID>()
        return latest.exercises.map(\.exercise).filter { seen.insert($0.id).inserted }
    }

    /// 種目ごとの自己ベスト。種目のプリセットの順に並ぶ
    var exerciseBests: [ExerciseBest] {
        var bests: [Exercise.ID: ExerciseBest] = [:]
        for workout in self {
            for entry in workout.exercises {
                for set in entry.sets {
                    guard let weight = set.weight, let reps = set.reps else { continue }
                    if let current = bests[entry.exercise.id], (weight, reps) <= (current.weight, current.reps) {
                        continue
                    }
                    bests[entry.exercise.id] = ExerciseBest(exercise: entry.exercise, weight: weight, reps: reps, date: workout.startedAt)
                }
            }
        }
        let order = Dictionary(uniqueKeysWithValues: Exercise.presets.enumerated().map { ($1.id, $0) })
        return bests.values.sorted { (order[$0.exercise.id] ?? .max) < (order[$1.exercise.id] ?? .max) }
    }
}

extension WorkoutSet {
    /// Epley式による推定1RM（`重量 ×（1 + 回数 ÷ 30）`）。重量か回数が未入力なら nil
    var estimatedOneRepMax: Double? {
        guard let weight, let reps, reps > 0 else { return nil }
        return weight * (1 + Double(reps) / 30)
    }
}

/// 重量の推移で表示する指標
enum WeightMetric: String, CaseIterable, Hashable, Sendable {
    case oneRepMax, volume

    /// セグメントコントロールに出す文言
    var label: String {
        switch self {
        case .oneRepMax: "推定1RM"
        case .volume: "ボリューム"
        }
    }

    /// グラフの下に出す説明
    var caption: String {
        switch self {
        case .oneRepMax: "推定1RM（Epley式）"
        case .volume: "ボリューム（重量×回数の合計）"
        }
    }
}

/// 1区間（週・月・年など）分の重量の推移の値。データがない区間は `value` が nil
struct WeightTrendPoint: Equatable, Identifiable {
    let bucketStart: Date
    let label: String
    let value: Double?

    var id: Date { bucketStart }
}

extension Collection<Workout> {
    /// 指定した種目の重量の推移（古い順）。区間の単位と数は `range` で変える
    func weightTrend(for exercise: Exercise, metric: WeightMetric, range: TrendRange, calendar: Calendar, now: Date) -> [WeightTrendPoint] {
        let bucketPeriod = range.bucketPeriod
        guard let component = bucketPeriod.calendarComponent else {
            let sets = flatMap { $0.exercises.filter { $0.exercise.id == exercise.id } }.flatMap(\.sets)
            let value = metric == .oneRepMax
                ? sets.compactMap(\.estimatedOneRepMax).max()
                : sets.volume
            return [WeightTrendPoint(bucketStart: .distantPast, label: "全期間", value: value)]
        }
        guard let thisBucketStart = calendar.dateInterval(of: component, for: now)?.start else { return [] }

        return (0..<range.bucketCount).reversed().compactMap { offset in
            guard
                let bucketStart = calendar.date(byAdding: component, value: -offset, to: thisBucketStart),
                let bucketEnd = calendar.date(byAdding: component, value: 1, to: bucketStart)
            else { return nil }

            let sets = filter { $0.startedAt >= bucketStart && $0.startedAt < bucketEnd }
                .flatMap { $0.exercises.filter { $0.exercise.id == exercise.id } }
                .flatMap(\.sets)
            let value = metric == .oneRepMax
                ? sets.compactMap(\.estimatedOneRepMax).max()
                : sets.volume

            return WeightTrendPoint(bucketStart: bucketStart, label: bucketPeriod.dateLabel(for: bucketStart, calendar: calendar), value: value)
        }
    }
}

extension [WorkoutSet] {
    /// ボリューム（重量 × 回数の合計）。重量を入力したセットが1つもなければ nil
    var volume: Double? {
        let weighted = compactMap { set -> Double? in
            guard let weight = set.weight, let reps = set.reps else { return nil }
            return weight * Double(reps)
        }
        return weighted.isEmpty ? nil : weighted.reduce(0, +)
    }
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
    /// 選んでいる期間全体（bucketCount分の区間をまとめた範囲）。基準日が含まれる区間の終わりまでを含む。全期間はnil
    func interval(calendar: Calendar, referenceDate: Date) -> DateInterval? {
        guard
            let component = bucketPeriod.calendarComponent,
            let thisBucket = calendar.dateInterval(of: component, for: referenceDate),
            let start = calendar.date(byAdding: component, value: -(bucketCount - 1), to: thisBucket.start)
        else { return nil }
        return DateInterval(start: start, end: thisBucket.end)
    }

    /// 重量の推移で「前の区間と比べてどれだけ変わったか」に出す文言
    var comparisonLabel: String {
        switch bucketPeriod {
        case .week: "先週比"
        case .month: "先月比"
        case .year: "去年比"
        case .all: "前区間比"
        }
    }

    /// 「10/25〜10/31」のような、基準日が含まれる区間の範囲ラベル（具体的な日付で出す）。部位・種目どちらの分析画面でも使う
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

extension [WeightTrendPoint] {
    /// データがある直近2区間分（新しい順）。前区間比を出すのに使う
    var latestTwoValues: (current: Double, previous: Double?)? {
        let values = compactMap(\.value)
        guard let current = values.last else { return nil }
        return (current, values.count >= 2 ? values[values.count - 2] : nil)
    }
}
