//
//  AppFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture

@Reducer
struct AppFeature {
    /// 画面として切り替わるタブ。記録はモーダルを開くボタンなので含めない
    enum Tab: Hashable {
        case home
        case calendar
        case myPage
    }

    @Reducer
    enum Destination {
        case recordWorkout(RecordWorkoutFeature)
        case startWorkout(StartWorkoutFeature)
    }

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var home = HomeFeature.State()
        var calendar = CalendarFeature.State()
        var myPage = MyPageFeature.State()
        @Presents var destination: Destination.State?
        /// 記録中のトレーニング。最小化して記録画面を閉じても残る
        @Shared(.activeWorkout) var activeWorkout
        @Shared(.workoutHistory) var workoutHistory
    }

    enum Action {
        case activeWorkoutBarTapped
        case calendar(CalendarFeature.Action)
        case destination(PresentationAction<Destination.Action>)
        case home(HomeFeature.Action)
        case myPage(MyPageFeature.Action)
        case recordButtonTapped
        case tabSelected(Tab)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.calendar, action: \.calendar) {
            CalendarFeature()
        }
        Scope(state: \.myPage, action: \.myPage) {
            MyPageFeature()
        }
        Reduce { state, action in
            switch action {
            case .activeWorkoutBarTapped:
                state.openActiveWorkout()
                return .none

            case .calendar, .home, .myPage:
                return .none

            case .destination(.presented(.recordWorkout(.delegate(.discarded)))):
                state.destination = nil
                state.$activeWorkout.withLock { $0 = nil }
                return .none

            case .destination(.presented(.recordWorkout(.delegate(.finished)))):
                if var workout = state.activeWorkout?.recordedOnly {
                    workout.endedAt = now
                    state.$workoutHistory.withLock { $0.insert(workout, at: 0) }
                }
                state.destination = nil
                state.$activeWorkout.withLock { $0 = nil }
                return .none

            case .destination(.presented(.startWorkout(.delegate(.startEmpty)))):
                state.$activeWorkout.withLock { $0 = Workout(id: uuid(), startedAt: now) }
                state.openActiveWorkout()
                // 空の一覧から「種目を追加」を押す手間を省き、すぐ種目を選べるようにする
                state.destination?.modify(\.recordWorkout) {
                    $0.destination = .exercisePicker(ExercisePickerFeature.State())
                }
                return .none

            case .destination:
                return .none

            case .recordButtonTapped:
                // 記録中なら続きを開き、そうでなければ開始シートを出す
                if state.activeWorkout == nil {
                    state.destination = .startWorkout(StartWorkoutFeature.State())
                } else {
                    state.openActiveWorkout()
                }
                return .none

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension AppFeature.Destination.State: Equatable {}

extension AppFeature.State {
    mutating func openActiveWorkout() {
        guard let workout = Shared($activeWorkout) else { return }
        destination = .recordWorkout(RecordWorkoutFeature.State(workout: workout))
    }
}
