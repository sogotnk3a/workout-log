//
//  HomeFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// フレンドのトレーニング状況を一覧表示する。フレンド機能はいずれサーバーと連携する予定だが、今はモックデータのみ
@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var friends: IdentifiedArrayOf<Friend> = Friend.mock
        var path = StackState<FriendHistoryFeature.State>()
    }

    enum Action {
        case friendTapped(Friend.ID)
        case path(StackActionOf<FriendHistoryFeature>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .friendTapped(id):
                guard let friend = state.friends[id: id] else { return .none }
                state.path.append(FriendHistoryFeature.State(friend: friend))
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            FriendHistoryFeature()
        }
    }
}

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section("タイムライン") {
                    ForEach(store.friends.sortedByActivity) { friend in
                        Button {
                            store.send(.friendTapped(friend.id))
                        } label: {
                            FriendRow(friend: friend)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("ホーム")
        } destination: { store in
            FriendHistoryView(store: store)
        }
    }
}

/// Discordのオンライン表示のように、アイコンの右下にトレ中かどうかの丸バッジを重ねる
private struct FriendAvatar: View {
    let friend: Friend
    var size: CGFloat = 44

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay {
                Text(friend.name.prefix(1))
                    .font(size >= 36 ? .headline : .caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(friend.status.badgeColor(now: .now))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay {
                        Circle().strokeBorder(Color(.systemBackground), lineWidth: 2)
                    }
            }
    }
}

private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatar(friend: friend)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                Text(friend.tauntText(now: .now))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(friend.status.text(now: .now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(friend.status.badgeColor(now: .now))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
