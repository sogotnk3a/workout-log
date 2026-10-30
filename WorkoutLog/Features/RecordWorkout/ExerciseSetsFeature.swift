//
//  ExerciseSetsFeature.swift
//  WorkoutLog
//
//  Created by Hotaka Kanazawa on 2026/10/16.
//

import ComposableArchitecture
import SwiftUI

/// 1つの種目のセットを入力するページ
@Reducer
struct ExerciseSetsFeature {
    @ObservableState
    struct State: Equatable {
        @Shared var entry: WorkoutExercise
        @SharedReader(.workoutHistory) var history
        /// これより前に始めたトレーニングから前回の値を探す。記録を編集するとき、その記録自身を前回として出さないため
        var startedBefore: Date?
        /// 直前に削除したセット。「元に戻す」を表示している間だけ値がある
        var deletedSet: DeletedSet?

        /// この種目を前回やったときのセット
        var previousSets: [WorkoutSet] {
            guard let startedBefore else { return history.lastSets(of: entry.exercise.id) ?? [] }
            return history.filter { $0.startedAt < startedBefore }.lastSets(of: entry.exercise.id) ?? []
        }
    }

    struct DeletedSet: Equatable {
        let index: Int
        let set: WorkoutSet
    }

    enum Action {
        case addSetButtonTapped
        case delegate(Delegate)
        case deleteSetSwiped(WorkoutSet.ID)
        case fillPreviousButtonTapped
        case nextExerciseButtonTapped
        case repsChanged(WorkoutSet.ID, Int?)
        case undoDeleteButtonTapped
        case undoExpired
        case weightChanged(WorkoutSet.ID, Double?)

        @CasePathable
        enum Delegate: Equatable {
            case addNextExercise
        }
    }

    private enum CancelID { case undo }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .addSetButtonTapped:
                // 同じトレーニングの直前のセットの値を引き継ぐ
                let last = state.entry.sets.last
                let set = WorkoutSet(id: uuid(), weight: last?.weight, reps: last?.reps)
                state.$entry.withLock { $0.sets.append(set) }
                return .none

            case .delegate:
                return .none

            case let .deleteSetSwiped(setID):
                guard let index = state.entry.sets.index(id: setID) else { return .none }
                state.deletedSet = DeletedSet(index: index, set: state.entry.sets[index])
                state.$entry.withLock { $0.sets.remove(id: setID) }
                return .run { send in
                    try await clock.sleep(for: .seconds(6))
                    await send(.undoExpired)
                }
                .cancellable(id: CancelID.undo, cancelInFlight: true)

            case .fillPreviousButtonTapped:
                let previous = state.previousSets
                // 前回と同じセット数になるまで行を足し、空欄だけを前回の値で埋める
                let newIDs = (0..<max(0, previous.count - state.entry.sets.count)).map { _ in uuid() }
                state.$entry.withLock {
                    for id in newIDs {
                        $0.sets.append(WorkoutSet(id: id, weight: nil, reps: nil))
                    }
                    for (index, previousSet) in previous.enumerated() {
                        if $0.sets[index].weight == nil { $0.sets[index].weight = previousSet.weight }
                        if $0.sets[index].reps == nil { $0.sets[index].reps = previousSet.reps }
                    }
                }
                return .none

            case .nextExerciseButtonTapped:
                return .send(.delegate(.addNextExercise))

            case let .repsChanged(setID, reps):
                state.$entry.withLock { $0.sets[id: setID]?.reps = reps.map { max(0, $0) } }
                return .none

            case .undoDeleteButtonTapped:
                guard let deleted = state.deletedSet else { return .none }
                state.deletedSet = nil
                state.$entry.withLock { $0.sets.insert(deleted.set, at: min(deleted.index, $0.sets.count)) }
                return .cancel(id: CancelID.undo)

            case .undoExpired:
                state.deletedSet = nil
                return .none

            case let .weightChanged(setID, weight):
                state.$entry.withLock { $0.sets[id: setID]?.weight = weight.map { max(0, $0) } }
                return .none
            }
        }
    }
}

struct ExerciseSetsView: View {
    let store: StoreOf<ExerciseSetsFeature>
    @FocusState private var focusedField: SetField?

    var body: some View {
        let previous = store.previousSets
        List {
            if !previous.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("前回")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(previous.summary)
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Button("前回の値を入力") {
                            store.send(.fillPreviousButtonTapped, animation: .default)
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }

            Section {
                HStack(spacing: 6) {
                    Color.clear.frame(width: 22, height: 1)
                    Text("重量（kg）").frame(maxWidth: .infinity)
                    Text("回数").frame(maxWidth: .infinity)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                .listRowSeparator(.hidden)

                ForEach(Array(store.entry.sets.enumerated()), id: \.element.id) { index, set in
                    SetRow(
                        number: index + 1,
                        set: set,
                        previous: previous.indices.contains(index) ? previous[index] : nil,
                        focusedField: $focusedField,
                        onWeightChange: { store.send(.weightChanged(set.id, $0)) },
                        onRepsChange: { store.send(.repsChanged(set.id, $0)) }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("削除", systemImage: "trash", role: .destructive) {
                            store.send(.deleteSetSwiped(set.id), animation: .default)
                        }
                    }
                }

                Button {
                    store.send(.addSetButtonTapped, animation: .default)
                } label: {
                    Label("セットを追加", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listSectionSpacing(16)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(store.entry.exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") { focusedField = nil }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let deleted = store.deletedSet {
                HStack {
                    Text("セット\(deleted.index + 1)を削除しました")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button("元に戻す") { store.send(.undoDeleteButtonTapped, animation: .default) }
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .foregroundStyle(.white)
                .tint(Color(red: 0.49, green: 0.71, blue: 1.0))
                .background(Color(.darkGray), in: .rect(cornerRadius: 14))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                focusedField = nil
                store.send(.nextExerciseButtonTapped)
            } label: {
                Label("次の種目を追加", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// キーボードのフォーカス先。セットごとに重量と回数の2つ
private struct SetField: Hashable {
    enum Kind { case weight, reps }
    let setID: WorkoutSet.ID
    let kind: Kind
}

private struct SetRow: View {
    let number: Int
    let set: WorkoutSet
    /// 同じ番号の前回のセット。空欄のプレースホルダーに使う
    let previous: WorkoutSet?
    var focusedField: FocusState<SetField?>.Binding
    let onWeightChange: (Double?) -> Void
    let onRepsChange: (Int?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            StepperField(
                title: "重量",
                value: set.weight,
                placeholder: previous?.weight,
                step: 2.5,
                format: .number.precision(.fractionLength(0...2)),
                keyboard: .decimalPad,
                onChange: onWeightChange
            )
            .focused(focusedField, equals: SetField(setID: set.id, kind: .weight))
            StepperField(
                title: "回数",
                value: set.reps,
                placeholder: previous?.reps,
                step: 1,
                format: .number,
                keyboard: .numberPad,
                onChange: onRepsChange
            )
            .focused(focusedField, equals: SetField(setID: set.id, kind: .reps))
        }
    }
}

/// −／＋ボタン付きの数値入力。数字をタップすれば直接入力もできる。
/// 空欄のときは前回の値を薄く表示し、±を押すとその値を基準に増減する
private struct StepperField<Value: Numeric & Comparable, Format: ParseableFormatStyle>: View
where Format.FormatInput == Value, Format.FormatOutput == String {
    let title: String
    let value: Value?
    let placeholder: Value?
    let step: Value
    let format: Format
    let keyboard: UIKeyboardType
    let onChange: (Value?) -> Void

    private var base: Value { value ?? placeholder ?? .zero }

    var body: some View {
        HStack(spacing: 0) {
            Button("\(title)を減らす", systemImage: "minus") {
                onChange(max(.zero, base - step))
            }
            .labelStyle(.iconOnly)
            .frame(width: 40, height: 48)
            TextField(
                title,
                value: Binding(get: { value }, set: onChange),
                format: format,
                prompt: Text(placeholder.map { format.format($0) } ?? "-")
            )
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.title3.weight(.bold).monospacedDigit())
            .frame(minWidth: 0, maxWidth: .infinity)
            Button("\(title)を増やす", systemImage: "plus") {
                onChange(base + step)
            }
            .labelStyle(.iconOnly)
            .frame(width: 40, height: 48)
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
    }
}
