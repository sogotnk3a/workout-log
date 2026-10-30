//
//  CalendarFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 過去のトレーニングを月ごとに表示する。日付には、その日に鍛えた部位の色の点を付ける
@Reducer
struct CalendarFeature {
    @Reducer
    enum Destination {
        case deleteAlert(AlertState<DeleteAlert>)

        @CasePathable
        enum DeleteAlert: Equatable {
            case confirmButtonTapped(Workout.ID)
        }
    }

    @ObservableState
    struct State: Equatable {
        /// 表示している月の1日
        var month: Date
        /// 選んでいる日（0時0分）
        var selectedDay: Date
        var path = StackState<WorkoutDetailFeature.State>()
        @Presents var destination: Destination.State?
        @Shared(.workoutHistory) var history

        init() {
            @Dependency(\.date.now) var now
            @Dependency(\.calendar) var calendar
            month = calendar.startOfMonth(for: now)
            selectedDay = calendar.startOfDay(for: now)
        }
    }

    enum Action {
        case dayTapped(Date)
        case deleteWorkoutSwiped(Workout.ID)
        case destination(PresentationAction<Destination.Action>)
        case nextMonthButtonTapped
        case path(StackActionOf<WorkoutDetailFeature>)
        case previousMonthButtonTapped
        case workoutTapped(Workout.ID)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .dayTapped(day):
                state.selectedDay = day
                return .none

            case let .deleteWorkoutSwiped(id):
                guard let workout = state.history[id: id] else { return .none }
                state.destination = .deleteAlert(.deleteWorkout(workout, calendar: calendar, action: .confirmButtonTapped(id)))
                return .none

            case let .destination(.presented(.deleteAlert(.confirmButtonTapped(id)))):
                _ = state.$history.withLock { $0.remove(id: id) }
                return .none

            case .destination:
                return .none

            case .nextMonthButtonTapped:
                state.showMonth(adding: 1, calendar: calendar, now: now)
                return .none

            case .path:
                return .none

            case .previousMonthButtonTapped:
                state.showMonth(adding: -1, calendar: calendar, now: now)
                return .none

            case let .workoutTapped(id):
                state.path.append(WorkoutDetailFeature.State(workoutID: id))
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            WorkoutDetailFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension CalendarFeature.Destination.State: Equatable {}

/// カレンダーの1日分のマス
struct CalendarDay: Equatable, Identifiable {
    let date: Date
    let bodyParts: [BodyPart]

    var id: Date { date }
}

extension CalendarFeature.State {
    /// 月を移動する。今月なら今日を、それ以外の月なら1日を選ぶ
    mutating func showMonth(adding value: Int, calendar: Calendar, now: Date) {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        month = next
        selectedDay = calendar.isDate(now, equalTo: next, toGranularity: .month) ? calendar.startOfDay(for: now) : next
    }

    /// 表示している月の日付。日曜始まりで、1日より前の空白は nil
    func days(calendar: Calendar) -> [CalendarDay?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let partsByDay = Dictionary(grouping: history) { calendar.startOfDay(for: $0.startedAt) }
            .mapValues { workouts in
                let parts = Set(workouts.flatMap(\.bodyParts))
                return BodyPart.allCases.filter(parts.contains)
            }
        let blanks = calendar.component(.weekday, from: month) - 1
        let days = range.compactMap { day -> CalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: month) else { return nil }
            return CalendarDay(date: date, bodyParts: partsByDay[date] ?? [])
        }
        return Array(repeating: nil, count: blanks) + days
    }

    /// 選んでいる日のトレーニング（開始が早い順）
    func selectedDayWorkouts(calendar: Calendar) -> [Workout] {
        history
            .filter { calendar.isDate($0.startedAt, inSameDayAs: selectedDay) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// 表示している月にトレーニングした回数
    func workoutCount(calendar: Calendar) -> Int {
        history.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }.count
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

extension Date {
    /// 「10月15日（木）」の形式
    func dayTitle(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.month, .day, .weekday], from: self)
        let weekdays = ["日", "月", "火", "水", "木", "金", "土"]
        let weekday = weekdays[(components.weekday ?? 1) - 1]
        return "\(components.month ?? 0)月\(components.day ?? 0)日（\(weekday)）"
    }

    /// 「19:02」の形式。端末の言語設定によらず24時間表記にする
    func timeText(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return String(format: "%d:%02d", components.hour ?? 0, components.minute ?? 0)
    }
}

extension Workout {
    /// 「19:02〜20:10」の形式
    func timeRange(calendar: Calendar) -> String {
        let start = startedAt.timeText(calendar: calendar)
        guard let endedAt else { return start }
        return "\(start)〜\(endedAt.timeText(calendar: calendar))"
    }

    /// トレーニングの長さ（分）
    var durationMinutes: Int? {
        endedAt.map { max(0, Int($0.timeIntervalSince(startedAt) / 60)) }
    }
}

extension AlertState {
    static func deleteWorkout(_ workout: Workout, calendar: Calendar, action: Action) -> Self {
        Self {
            TextState("この記録を削除しますか？")
        } actions: {
            ButtonState(role: .destructive, action: action) {
                TextState("削除")
            }
            ButtonState(role: .cancel) {
                TextState("キャンセル")
            }
        } message: {
            let day = workout.startedAt.dayTitle(calendar: calendar)
            return TextState("\(day) \(workout.timeRange(calendar: calendar)) の記録を削除します。元に戻すことはできません。")
        }
    }
}

struct CalendarView: View {
    @Bindable var store: StoreOf<CalendarFeature>
    @Environment(\.calendar) private var calendar

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section {
                    MonthCard(store: store)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 10, trailing: 12))
                }

                Section {
                    let workouts = store.state.selectedDayWorkouts(calendar: calendar)
                    if workouts.isEmpty {
                        Text("この日の記録はありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(workouts) { workout in
                        Button {
                            store.send(.workoutTapped(workout.id))
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("削除", systemImage: "trash", role: .destructive) {
                                store.send(.deleteWorkoutSwiped(workout.id))
                            }
                        }
                    }
                } header: {
                    Text(store.selectedDay.dayTitle(calendar: calendar))
                }
            }
            .navigationTitle("カレンダー")
        } destination: { store in
            WorkoutDetailView(store: store)
        }
        .alert($store.scope(state: \.destination?.deleteAlert, action: \.destination.deleteAlert))
    }
}

private struct MonthCard: View {
    let store: StoreOf<CalendarFeature>
    @Environment(\.calendar) private var calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdays = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("前の月", systemImage: "chevron.left") {
                    store.send(.previousMonthButtonTapped, animation: .default)
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
                Spacer()
                VStack(spacing: 2) {
                    Text(monthTitle)
                        .font(.headline)
                    Text("\(store.state.workoutCount(calendar: calendar))回トレーニング")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("次の月", systemImage: "chevron.right") {
                    store.send(.nextMonthButtonTapped, animation: .default)
                }
                .labelStyle(.iconOnly)
                .frame(width: 44, height: 44)
            }
            .font(.body.weight(.semibold))

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, weekday in
                    Text(weekday)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(weekdayColor(index + 1))
                        .accessibilityHidden(true)
                }
                ForEach(Array(store.state.days(calendar: calendar).enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(
                            day: day,
                            isSelected: day.date == store.selectedDay,
                            isToday: calendar.isDateInToday(day.date),
                            isFuture: day.date > Date.now,
                            weekdayColor: weekdayColor(calendar.component(.weekday, from: day.date))
                        ) {
                            store.send(.dayTapped(day.date))
                        }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }

            Divider()
            HStack(spacing: 12) {
                ForEach(BodyPart.allCases, id: \.self) { part in
                    HStack(spacing: 4) {
                        Circle().fill(part.color).frame(width: 8, height: 8)
                        Text(part.label)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.borderless)
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: store.month)
        return "\(components.year ?? 0)年\(components.month ?? 0)月"
    }

    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: .red
        case 7: .blue
        default: .primary
        }
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let isToday: Bool
    let isFuture: Bool
    let weekdayColor: Color
    let action: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.body.weight(isSelected || isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(numberColor)
                    .frame(width: 34, height: 34)
                    .background {
                        if isSelected {
                            Circle().fill(Color.primary)
                        } else if isToday {
                            Circle().strokeBorder(Color.primary, lineWidth: 1.5)
                        }
                    }
                HStack(spacing: 2) {
                    ForEach(day.bodyParts, id: \.self) { part in
                        Circle().fill(part.color).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var numberColor: Color {
        if isSelected { return Color(.systemBackground) }
        if isFuture { return Color.secondary.opacity(0.6) }
        return weekdayColor
    }

    private var accessibilityLabel: String {
        let title = day.date.dayTitle(calendar: calendar)
        guard !day.bodyParts.isEmpty else { return title }
        return "\(title) \(day.bodyParts.map(\.label).joined(separator: "、"))"
    }
}

private struct WorkoutRow: View {
    let workout: Workout
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(workout.timeRange(calendar: calendar))
                        .font(.headline.monospacedDigit())
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                BodyPartBadges(parts: workout.bodyParts)
                ForEach(workout.exercises) { entry in
                    Text("\(entry.exercise.name) \(Array(entry.sets).summary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        let count = "\(workout.exercises.count)種目"
        guard let minutes = workout.durationMinutes else { return count }
        return "\(minutes)分 ・ \(count)"
    }
}

/// 部位を色の点と名前で並べる
struct BodyPartBadges: View {
    let parts: [BodyPart]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(parts, id: \.self) { part in
                HStack(spacing: 4) {
                    Circle().fill(part.color).frame(width: 7, height: 7)
                    Text(part.label)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(part.color.opacity(0.14), in: .capsule)
            }
        }
    }
}
