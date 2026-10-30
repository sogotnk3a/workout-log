//
//  RecordWorkoutFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 記録画面のトップ（種目一覧）。種目をタップすると、その種目の入力ページに進む
@Reducer
struct RecordWorkoutFeature {
    @Reducer
    enum Destination {
        case exercisePicker(ExercisePickerFeature)
        case finishAlert(AlertState<FinishAlert>)

        @CasePathable
        enum FinishAlert {
            case discardButtonTapped
            case saveButtonTapped
        }
    }

    @ObservableState
    struct State: Equatable {
        @Presents var destination: Destination.State?
        var path = StackState<ExerciseSetsFeature.State>()
        @Shared var workout: Workout
    }

    enum Action {
        case addExerciseButtonTapped
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case exerciseTapped(WorkoutExercise.ID)
        case deleteExerciseSwiped(WorkoutExercise.ID)
        case exercisesMoved(IndexSet, Int)
        case finishButtonTapped
        case minimizeButtonTapped
        case path(StackActionOf<ExerciseSetsFeature>)

        @CasePathable
        enum Delegate: Equatable {
            case discarded
            case finished
        }
    }

    @Dependency(\.dismiss) var dismiss
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addExerciseButtonTapped:
                state.destination = .exercisePicker(ExercisePickerFeature.State())
                return .none

            case .delegate:
                return .none

            case let .destination(.presented(.exercisePicker(.delegate(.select(exercise))))):
                // 空欄のセットを1つ用意して、そのまま入力ページを開く。戻ると一覧に戻るよう、開いているページは閉じる
                let entry = WorkoutExercise(
                    id: uuid(),
                    exercise: exercise,
                    sets: [WorkoutSet(id: uuid(), weight: nil, reps: nil)]
                )
                state.$workout.withLock { $0.exercises.append(entry) }
                state.path.removeAll()
                state.openExercise(entry.id)
                return .none

            case .destination(.presented(.finishAlert(.discardButtonTapped))):
                return .send(.delegate(.discarded))

            case .destination(.presented(.finishAlert(.saveButtonTapped))):
                return .send(.delegate(.finished))

            case .destination:
                return .none

            case let .exerciseTapped(id):
                state.openExercise(id)
                return .none

            case let .deleteExerciseSwiped(id):
                _ = state.$workout.withLock { $0.exercises.remove(id: id) }
                return .none

            case let .exercisesMoved(source, destination):
                state.$workout.withLock { $0.exercises.move(fromOffsets: source, toOffset: destination) }
                return .none

            case .finishButtonTapped:
                state.destination = .finishAlert(.finish(hasRecordedSets: !state.workout.recordedOnly.exercises.isEmpty))
                return .none

            case .minimizeButtonTapped:
                return .run { _ in await dismiss() }

            case .path(.element(id: _, action: .delegate(.addNextExercise))):
                state.destination = .exercisePicker(ExercisePickerFeature.State())
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            ExerciseSetsFeature()
        }
        .ifLet(\.$destination, action: \.destination)
    }
}

extension RecordWorkoutFeature.Destination.State: Equatable {}

extension RecordWorkoutFeature.State {
    mutating func openExercise(_ id: WorkoutExercise.ID) {
        guard let entry = Shared($workout.exercises[id: id]) else { return }
        path.append(ExerciseSetsFeature.State(entry: entry))
    }
}

extension AlertState where Action == RecordWorkoutFeature.Destination.FinishAlert {
    static func finish(hasRecordedSets: Bool) -> Self {
        Self {
            TextState("トレーニングを終了しますか？")
        } actions: {
            if hasRecordedSets {
                ButtonState(action: .saveButtonTapped) {
                    TextState("保存して終了")
                }
            }
            ButtonState(role: .destructive, action: .discardButtonTapped) {
                TextState("記録を破棄")
            }
            ButtonState(role: .cancel) {
                TextState("キャンセル")
            }
        } message: {
            hasRecordedSets
                ? TextState("回数を入力したセットだけが保存されます。")
                : TextState("回数を入力したセットがないため、保存できるものがありません。")
        }
    }
}

struct RecordWorkoutView: View {
    @Bindable var store: StoreOf<RecordWorkoutFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                if store.workout.exercises.isEmpty {
                    ContentUnavailableView(
                        "種目がありません",
                        systemImage: "dumbbell",
                        description: Text("下の「種目を追加」から始めましょう")
                    )
                    .listRowBackground(Color.clear)
                }
                // 長押しでそのままドラッグして並べ替え、スワイプで削除できる
                ForEach(store.workout.exercises) { entry in
                    Button {
                        store.send(.exerciseTapped(entry.id))
                    } label: {
                        ExerciseSummaryRow(entry: entry)
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            store.send(.deleteExerciseSwiped(entry.id), animation: .default)
                        }
                    }
                }
                .onMove { store.send(.exercisesMoved($0, $1)) }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.send(.addExerciseButtonTapped)
                } label: {
                    Label("種目を追加", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("最小化", systemImage: "chevron.down") {
                        store.send(.minimizeButtonTapped)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("トレーニング中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ElapsedTimeText(startedAt: store.workout.startedAt)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完了") { store.send(.finishButtonTapped) }
                        .buttonStyle(.borderedProminent)
                }
            }
        } destination: { store in
            ExerciseSetsView(store: store)
        }
        .sheet(item: $store.scope(state: \.destination?.exercisePicker, action: \.destination.exercisePicker)) { pickerStore in
            NavigationStack {
                ExercisePickerView(store: pickerStore)
            }
        }
        .alert($store.scope(state: \.destination?.finishAlert, action: \.destination.finishAlert))
    }
}

struct ExerciseSummaryRow: View {
    let entry: WorkoutExercise

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.exercise.name)
                    .font(.body.weight(.semibold))
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var summary: String {
        let recorded = Array(entry.sets.filter(\.isRecorded))
        guard !recorded.isEmpty else { return "未入力" }
        return "\(recorded.count)セット ・ \(recorded.summary)"
    }
}

/// 開始からの経過時間を1秒ごとに更新して表示する
struct ElapsedTimeText: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Self.format(context.date.timeIntervalSince(startedAt)))
                .monospacedDigit()
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }
}
