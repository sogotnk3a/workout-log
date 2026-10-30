//
//  FriendTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import WorkoutLog

struct FriendTests {
    @Test
    func トレ中のフレンドはトレ中と表示される() {
        let status = Friend.Status.training(startedAt: .distantPast)
        #expect(status.text(now: .now) == "トレ中")
    }

    @Test
    func 最後にトレした時刻から相対的な経過時間が表示される() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let status = Friend.Status.lastTrained(at: now.addingTimeInterval(-5 * 60))
        #expect(status.text(now: now) == "5分前にトレ")
    }

    @Test
    func バッジの色はトレ中なら緑1時間以内なら黄色それより前は灰色() {
        let now = Date(timeIntervalSinceReferenceDate: 10000)
        #expect(Friend.Status.training(startedAt: now).badgeColor(now: now) == .green)
        #expect(Friend.Status.lastTrained(at: now.addingTimeInterval(-59 * 60)).badgeColor(now: now) == .yellow)
        #expect(Friend.Status.lastTrained(at: now.addingTimeInterval(-61 * 60)).badgeColor(now: now) == Color.secondary.opacity(0.6))
    }

    @Test
    func トレ中のフレンドの煽り文は名前を含まず動き出している旨だけを含む() {
        let friend = Friend(id: UUID(1), name: "OREN", status: .training(startedAt: .distantPast))
        #expect(friend.tauntText(now: .now) == "もう動き出してる。置いていかれるよ")
    }

    @Test
    func トレした後のフレンドの煽り文は名前も経過時間も含まない() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let friend = Friend(id: UUID(1), name: "SOGO", status: .lastTrained(at: now.addingTimeInterval(-5 * 60)))
        #expect(friend.tauntText(now: now) == "もうトレした。お前はまだ？")
    }

    @Test
    func 並び替えはトレ中のフレンドが先頭でそれ以外は最後にトレした時刻が新しい順() {
        let now = Date.now
        let training = Friend(id: UUID(1), name: "トレ中", status: .training(startedAt: now))
        let recent = Friend(id: UUID(2), name: "最近", status: .lastTrained(at: now.addingTimeInterval(-60)))
        let old = Friend(id: UUID(3), name: "古い", status: .lastTrained(at: now.addingTimeInterval(-3600)))
        let friends: IdentifiedArrayOf<Friend> = [old, recent, training]

        #expect(friends.sortedByActivity.map(\.name) == ["トレ中", "最近", "古い"])
    }
}
