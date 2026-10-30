//
//  MyPageFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import PhotosUI
import SwiftUI

@Reducer
struct MyPageFeature {
    @Reducer
    enum Path {
        case analysis(StatsAnalysisFeature)
        case bodyPartDetail(BodyPartDetailFeature)
        case personalBest(PersonalBestFeature)
        case trend(ExerciseTrendFeature)
    }

    @ObservableState
    struct State: Equatable {
        @Shared(.userProfile) var profile
        @Shared(.workoutHistory) var history
        var path = StackState<Path.State>()
    }

    enum Action {
        case analysisButtonTapped
        case messageTemplateTapped(String)
        case path(StackActionOf<Path>)
        case personalBestButtonTapped
        case photoPicked(Data)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .analysisButtonTapped:
                state.path.append(.analysis(StatsAnalysisFeature.State()))
                return .none

            case let .messageTemplateTapped(message):
                state.$profile.withLock { $0.message = message }
                return .none

            case let .path(.element(id, action: .analysis(.delegate(.bodyPartTapped(part))))):
                guard case let .analysis(analysisState) = state.path[id: id] else { return .none }
                state.path.append(.bodyPartDetail(BodyPartDetailFeature.State(
                    part: part,
                    range: analysisState.range,
                    metric: analysisState.metric,
                    referenceDate: analysisState.referenceDate(calendar: calendar, now: now)
                )))
                return .none

            case let .path(.element(_, action: .analysis(.delegate(.exerciseTapped(id))))):
                appendTrend(for: id, into: &state)
                return .none

            case let .path(.element(_, action: .bodyPartDetail(.delegate(.exerciseTapped(id))))):
                appendTrend(for: id, into: &state)
                return .none

            case let .path(.element(_, action: .personalBest(.delegate(.exerciseTapped(id))))):
                appendTrend(for: id, into: &state)
                return .none

            case .path:
                return .none

            case .personalBestButtonTapped:
                state.path.append(.personalBest(PersonalBestFeature.State()))
                return .none

            case let .photoPicked(data):
                state.$profile.withLock { $0.photoData = data }
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }

    /// 種目IDから重量の推移画面をpathに積む。部位・自己ベスト・分析の各内訳画面で共通して使う
    private func appendTrend(for id: Exercise.ID, into state: inout State) {
        guard let exercise = Exercise.presets.first(where: { $0.id == id }) else { return }
        state.path.append(.trend(ExerciseTrendFeature.State(exercise: exercise)))
    }
}

extension MyPageFeature.Path.State: Equatable {}

struct MyPageView: View {
    @Bindable var store: StoreOf<MyPageFeature>
    @State private var photosPickerItem: PhotosPickerItem?
    @Environment(\.calendar) private var calendar

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section {
                    HStack(spacing: 16) {
                        PhotosPicker(selection: $photosPickerItem, matching: .images) {
                            ProfilePhoto(data: store.profile.photoData)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("写真をタップして変更")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Menu {
                                ForEach(UserProfile.messageTemplates, id: \.self) { message in
                                    Button(message) {
                                        store.send(.messageTemplateTapped(message))
                                    }
                                }
                            } label: {
                                Text(store.profile.message ?? "ひとことを選ぶ")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    StatsSummary(history: store.history, period: .month, calendar: calendar)
                }

                Section {
                    Button {
                        store.send(.analysisButtonTapped)
                    } label: {
                        Label("分析", systemImage: "chart.bar.xaxis")
                            .font(.subheadline.weight(.semibold))
                    }

                    Button {
                        store.send(.personalBestButtonTapped)
                    } label: {
                        Label("自己ベスト", systemImage: "trophy")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if let latest = store.history.first {
                    Section("トレーニングをシェア") {
                        ShareWorkoutSection(workout: latest, calendar: calendar)
                    }
                }
            }
            .navigationTitle("マイページ")
            .onChange(of: photosPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        store.send(.photoPicked(data))
                    }
                }
            }
        } destination: { store in
            switch store.case {
            case let .analysis(store):
                StatsAnalysisView(store: store)
            case let .bodyPartDetail(store):
                BodyPartDetailView(store: store)
            case let .personalBest(store):
                PersonalBestView(store: store)
            case let .trend(store):
                ExerciseTrendView(store: store)
            }
        }
    }
}

private struct ProfilePhoto: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.accentColor.opacity(0.15)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.accentColor)
                    }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }
}

/// 合計トレーニング回数と、選んでいる期間の回数
private struct StatsSummary: View {
    let history: IdentifiedArrayOf<Workout>
    let period: StatsPeriod
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 12) {
            StatCard(label: "合計トレーニング", count: history.count)
            StatCard(label: period.statLabel, count: history.workouts(in: period, calendar: calendar, now: .now).count)
        }
        .padding(.vertical, 4)
    }
}

private struct StatCard: View {
    let label: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(count)")
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("回")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 直近のトレーニングをカード画像にしてシェアする
private struct ShareWorkoutSection: View {
    let workout: Workout
    let calendar: Calendar
    @State private var cardImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ShareCardView(workout: workout, calendar: calendar)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let cardImage {
                ShareLink(
                    item: Image(uiImage: cardImage),
                    preview: SharePreview("\(workout.startedAt.dayTitle(calendar: calendar))の記録", image: Image(uiImage: cardImage))
                ) {
                    Label("シェアする", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 4)
        .task(id: workout.id) {
            cardImage = await Self.renderImage(workout: workout, calendar: calendar)
        }
    }

    @MainActor
    private static func renderImage(workout: Workout, calendar: Calendar) async -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(workout: workout, calendar: calendar).frame(width: 358, height: 160))
        renderer.scale = 3
        return renderer.uiImage
    }
}

/// シェア画像のもとになるカード。背景は鍛えた部位の色から作る
private struct ShareCardView: View {
    let workout: Workout
    let calendar: Calendar

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [.black, accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("WORKOUTLOG")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(workout.startedAt.dayTitle(calendar: calendar))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Text("\(workout.bodyParts.map(\.label).joined(separator: "・"))を鍛えた")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    if let minutes = workout.durationMinutes {
                        Text("\(minutes)分")
                    }
                    Text("\(workout.exercises.count)種目")
                    Text("\(workout.recordedSetCount)セット")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private var accentColor: Color {
        workout.bodyParts.first?.color ?? Color.accentColor
    }
}
