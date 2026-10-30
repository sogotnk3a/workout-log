//
//  AppView.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        TabView(selection: selection) {
            Tab("ホーム", systemImage: "house", value: TabItem.home) {
                HomeView(store: store.scope(state: \.home, action: \.home))
            }
            Tab("カレンダー", systemImage: "calendar", value: TabItem.calendar) {
                CalendarView(store: store.scope(state: \.calendar, action: \.calendar))
            }
            Tab("マイページ", systemImage: "person", value: TabItem.myPage) {
                MyPageView(store: store.scope(state: \.myPage, action: \.myPage))
            }
            // role: .search を使うと iOS 26 ではタブバーの横に独立したボタンとして表示される
            Tab("記録", systemImage: "plus", value: TabItem.record, role: .search) {
                EmptyView()
            }
        }
        .tabViewBottomAccessory(isEnabled: store.activeWorkout != nil) {
            if let workout = store.activeWorkout {
                ActiveWorkoutBar(workout: workout) {
                    store.send(.activeWorkoutBarTapped)
                }
            }
        }
        .sheet(item: $store.scope(state: \.destination?.startWorkout, action: \.destination.startWorkout)) { store in
            StartWorkoutView(store: store)
                .presentationDetents([.medium])
        }
        .fullScreenCover(item: $store.scope(state: \.destination?.recordWorkout, action: \.destination.recordWorkout)) { store in
            RecordWorkoutView(store: store)
        }
    }

    /// 記録ボタンが選ばれたらタブは切り替えず、モーダルを開くアクションを送る
    private var selection: Binding<TabItem> {
        Binding(
            get: { TabItem(store.selectedTab) },
            set: { item in
                switch item {
                case .home: store.send(.tabSelected(.home))
                case .calendar: store.send(.tabSelected(.calendar))
                case .myPage: store.send(.tabSelected(.myPage))
                case .record: store.send(.recordButtonTapped)
                }
            }
        )
    }
}

/// TabView に並べる項目。State の Tab に記録ボタンを足した View 専用の型
private enum TabItem: Hashable {
    case home
    case calendar
    case myPage
    case record

    init(_ tab: AppFeature.Tab) {
        switch tab {
        case .home: self = .home
        case .calendar: self = .calendar
        case .myPage: self = .myPage
        }
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
    })
}
