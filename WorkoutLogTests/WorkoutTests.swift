//
//  WorkoutTests.swift
//  WorkoutLogTests
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

struct WorkoutTests {
    @Test
    func 保存するときは回数のないセットとセットが残らない種目を除く() {
        let workout = Workout(
            id: UUID(0),
            startedAt: .distantPast,
            exercises: [
                WorkoutExercise(
                    id: UUID(1),
                    exercise: Exercise.presets[0],
                    sets: [
                        WorkoutSet(id: UUID(2), weight: nil, reps: 10),
                        WorkoutSet(id: UUID(3), weight: 60, reps: nil),
                    ]
                ),
                WorkoutExercise(id: UUID(4), exercise: Exercise.presets[1], sets: [WorkoutSet(id: UUID(5), weight: 30, reps: nil)]),
            ]
        )

        let recorded = workout.recordedOnly

        #expect(recorded.exercises.map(\.id) == [UUID(1)])
        #expect(recorded.exercises[0].sets.map(\.id) == [UUID(2)])
    }

    @Test
    func トレーニングの部位は種目の部位を部位の順に1つずつ並べる() {
        let workout = Workout.sample(
            id: UUID(0),
            startedAt: .distantPast,
            exercises: [.preset("leg-raise"), .preset("bench-press"), .preset("crunch"), .preset("lat-pulldown")]
        )
        #expect(workout.bodyParts == [.chest, .back, .abs])
    }

    @Test
    func 腹筋の種目としてクランチとレッグレイズを用意している() {
        #expect(Exercise.presets.filter { $0.bodyPart == .abs }.map(\.name) == ["クランチ", "レッグレイズ"])
    }

    @Test
    func 一度もやっていない種目には前回の値がない() {
        let history = [Workout(id: UUID(0), startedAt: .distantPast)]
        #expect(history.lastSets(of: "bench-press") == nil)
    }

    @Test
    func 重量が全セット同じなら要約では重量を1回だけ書いて回数を並べる() {
        #expect(sets([(60, 10), (60, 8), (60, 7)]).summary == "60kg × 10, 8, 7")
    }

    @Test
    func 重量が違うセットがあれば要約ではセットごとに重量を書く() {
        #expect(sets([(60, 10), (62.5, 8)]).summary == "60kg × 10, 62.5kg × 8")
    }

    @Test
    func 重量がなければ要約は回数だけになる() {
        #expect(sets([(nil, 10), (nil, 12)]).summary == "10回, 12回")
    }

    private func sets(_ values: [(Double?, Int?)]) -> [WorkoutSet] {
        values.enumerated().map { WorkoutSet(id: UUID($0.offset), weight: $0.element.0, reps: $0.element.1) }
    }
}
