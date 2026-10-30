//
//  MyPageFeatureTests.swift
//  WorkoutLogTests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import WorkoutLog

@MainActor
struct MyPageFeatureTests {
    let calendar = Calendar.tokyo
    var now: Date { calendar.date(2026, 10, 16, 9, 30) }

    @Test
    func 写真を選ぶとプロフィールに保存される() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }
        let data = Data([0x01, 0x02])

        await store.send(.photoPicked(data)) {
            $0.$profile.withLock { $0.photoData = data }
        }
    }

    @Test
    func テンプレートからメッセージを選ぶとプロフィールに保存される() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }
        let message = UserProfile.messageTemplates[0]

        await store.send(.messageTemplateTapped(message)) {
            $0.$profile.withLock { $0.message = message }
        }
    }

    @Test
    func 分析ボタンを押すと分析画面が開く() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }

        await store.send(.analysisButtonTapped) {
            $0.path[id: 0] = .analysis(StatsAnalysisFeature.State())
        }
    }

    @Test
    func 自己ベストボタンを押すと自己ベスト画面が開く() async {
        let store = TestStore(initialState: MyPageFeature.State()) {
            MyPageFeature()
        }

        await store.send(.personalBestButtonTapped) {
            $0.path[id: 0] = .personalBest(PersonalBestFeature.State())
        }
    }

    @Test
    func 自己ベスト画面で種目をタップすると重量の推移画面が追加で開く() async {
        var state = MyPageFeature.State()
        state.path.append(.personalBest(PersonalBestFeature.State()))
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }

        await store.send(.path(.element(id: 0, action: .personalBest(.exerciseTapped("squat")))))
        await store.receive(\.path[id: 0].personalBest.delegate.exerciseTapped) {
            $0.path[id: 1] = .trend(ExerciseTrendFeature.State(exercise: .preset("squat")))
        }
    }

    @Test
    func 分析画面で種目をタップすると重量の推移画面が追加で開く() async {
        var state = MyPageFeature.State()
        state.path.append(.analysis(StatsAnalysisFeature.State()))
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }

        await store.send(.path(.element(id: 0, action: .analysis(.exerciseTapped("squat")))))
        await store.receive(\.path[id: 0].analysis.delegate.exerciseTapped) {
            $0.path[id: 1] = .trend(ExerciseTrendFeature.State(exercise: .preset("squat")))
        }
    }

    @Test
    func 分析画面で部位をタップすると部位の内訳画面が追加で開く() async {
        let store = withDependencies {
            $0.calendar = calendar
            $0.date.now = now
        } operation: {
            var state = MyPageFeature.State()
            state.path.append(.analysis(StatsAnalysisFeature.State()))
            return TestStore(initialState: state) {
                MyPageFeature()
            } withDependencies: {
                $0.calendar = calendar
                $0.date.now = now
            }
        }

        await store.send(.path(.element(id: 0, action: .analysis(.bodyPartTapped(.chest)))))
        await store.receive(\.path[id: 0].analysis.delegate.bodyPartTapped) {
            $0.path[id: 1] = .bodyPartDetail(BodyPartDetailFeature.State(part: .chest, referenceDate: self.now))
        }
    }

    @Test
    func 分析画面でボリューム指標を選んでから部位をタップすると内訳画面もボリュームで開く() async {
        let store = withDependencies {
            $0.calendar = calendar
            $0.date.now = now
        } operation: {
            var state = MyPageFeature.State()
            state.path.append(.analysis(StatsAnalysisFeature.State()))
            return TestStore(initialState: state) {
                MyPageFeature()
            } withDependencies: {
                $0.calendar = calendar
                $0.date.now = now
            }
        }

        await store.send(.path(.element(id: 0, action: .analysis(.nextMetricButtonTapped)))) {
            $0.path[id: 0] = .analysis(StatsAnalysisFeature.State(metric: .volume))
        }

        await store.send(.path(.element(id: 0, action: .analysis(.bodyPartTapped(.chest)))))
        await store.receive(\.path[id: 0].analysis.delegate.bodyPartTapped) {
            $0.path[id: 1] = .bodyPartDetail(BodyPartDetailFeature.State(part: .chest, metric: .volume, referenceDate: self.now))
        }
    }

    @Test
    func 分析画面で期間を3ヶ月で選んで1つ前に戻ってから部位をタップすると内訳画面もその期間を引き継ぐ() async {
        let store = withDependencies {
            $0.calendar = calendar
            $0.date.now = now
        } operation: {
            var state = MyPageFeature.State()
            state.path.append(.analysis(StatsAnalysisFeature.State()))
            return TestStore(initialState: state) {
                MyPageFeature()
            } withDependencies: {
                $0.calendar = calendar
                $0.date.now = now
            }
        }

        await store.send(.path(.element(id: 0, action: .analysis(.rangeButtonTapped(.threeMonths))))) {
            $0.path[id: 0] = .analysis(StatsAnalysisFeature.State(range: .threeMonths))
        }
        await store.send(.path(.element(id: 0, action: .analysis(.previousPeriodButtonTapped)))) {
            $0.path[id: 0] = .analysis(StatsAnalysisFeature.State(range: .threeMonths, periodOffset: 1, hasSelectedPeriod: true))
        }

        let expectedReferenceDate = calendar.date(byAdding: .month, value: -1, to: now)!
        await store.send(.path(.element(id: 0, action: .analysis(.bodyPartTapped(.chest)))))
        await store.receive(\.path[id: 0].analysis.delegate.bodyPartTapped) {
            $0.path[id: 1] = .bodyPartDetail(BodyPartDetailFeature.State(part: .chest, range: .threeMonths, referenceDate: expectedReferenceDate))
        }
    }

    @Test
    func 部位の内訳画面で種目をタップすると重量の推移画面が追加で開く() async {
        var state = MyPageFeature.State()
        state.path.append(.bodyPartDetail(BodyPartDetailFeature.State(part: .chest)))
        let store = TestStore(initialState: state) {
            MyPageFeature()
        }

        await store.send(.path(.element(id: 0, action: .bodyPartDetail(.exerciseTapped("bench-press")))))
        await store.receive(\.path[id: 0].bodyPartDetail.delegate.exerciseTapped) {
            $0.path[id: 1] = .trend(ExerciseTrendFeature.State(exercise: .preset("bench-press")))
        }
    }
}
