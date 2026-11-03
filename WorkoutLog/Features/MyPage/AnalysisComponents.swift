//
//  AnalysisComponents.swift
//  WorkoutLog
//

import Charts
import SwiftUI

/// ←→で値を切り替えるコントロール
struct ArrowNavigator: View {
    let label: String
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button("前へ", systemImage: "chevron.left", action: onPrevious)
                .labelStyle(.iconOnly)

            Spacer()
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()

            Button("次へ", systemImage: "chevron.right", action: onNext)
                .labelStyle(.iconOnly)
                .disabled(!canGoNext)
        }
        .buttonStyle(.borderless)
    }
}

/// 操作方法を説明する案内文を添えた`ArrowNavigator`。期間・指標どちらの切り替えでも使う
struct CaptionedArrowNavigator: View {
    let caption: String
    let label: String
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)

            ArrowNavigator(label: label, canGoNext: canGoNext, onPrevious: onPrevious, onNext: onNext)
        }
    }
}

/// 青一色・塗りつぶしなしの折れ線グラフ。ヘルスケアアプリの推移グラフを参考にした見た目。
/// 区間に記録がなければ線をつながず、点をタップ、または左右にスワイプすると選ぶ期間が変わる
struct TrendLineChart<Item: Identifiable>: View {
    let data: [Item]
    let seriesLabel: String
    let label: (Item) -> String
    let value: (Item) -> Double?
    @Binding var selectedLabel: String?
    let canNavigatePeriod: Bool
    let onSwipePrevious: () -> Void
    let onSwipeNext: () -> Void

    var body: some View {
        Chart(data) { item in
            if let value = value(item) {
                let itemLabel = label(item)
                LineMark(x: .value("期間", itemLabel), y: .value(seriesLabel, value))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.blue)
                PointMark(x: .value("期間", itemLabel), y: .value(seriesLabel, value))
                    .symbol {
                        Circle()
                            .fill(selectedLabel == itemLabel ? Color.blue : Color.white)
                            .overlay(Circle().stroke(Color.blue, lineWidth: 1.5))
                            .frame(width: selectedLabel == itemLabel ? 14 : 9, height: selectedLabel == itemLabel ? 14 : 9)
                    }
            }
        }
        .chartXScale(domain: data.map(label))
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine()
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture().onEnded { tap in
                            let origin = geometry[proxy.plotAreaFrame].origin
                            let x = tap.location.x - origin.x
                            if let label: String = proxy.value(atX: x) {
                                selectedLabel = label
                            }
                        }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { value in
                                guard canNavigatePeriod else { return }
                                let horizontal = value.translation.width
                                let vertical = value.translation.height
                                guard abs(horizontal) > abs(vertical) else { return }
                                if horizontal < 0 {
                                    onSwipeNext()
                                } else {
                                    onSwipePrevious()
                                }
                            }
                    )
            }
        }
    }
}
