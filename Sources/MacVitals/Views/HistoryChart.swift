import SwiftUI

/// The charts' shared time axis: the 30 minutes up to `now`, spread over a width.
struct TimeAxis {
    static let window = ThermalMonitor.window
    let now: Date

    var start: Date { now.addingTimeInterval(-Self.window) }

    /// Where `date` falls on the axis, clamped to its ends.
    func x(_ date: Date, width: CGFloat) -> CGFloat {
        min(max(date.timeIntervalSince(start) / Self.window, 0), 1) * width
    }
}

struct ChartTint {
    let from: Date
    let to: Date
    let color: Color
}

/// A 30-minute history drawn as an area, a line, or bars. Gaps longer than a minute (sleep) break
/// the area and line styles.
struct HistoryChart: View {
    let points: [HistoryPoint]
    let now: Date
    let range: ClosedRange<Double>
    let style: ChartStyle
    let color: Color
    /// Optional time spans that recolor the chart, e.g. by thermal state. Without them, `color` is used.
    var tint: [ChartTint] = []

    private static let barCount = 60

    var body: some View {
        GeometryReader { geo in
            if tint.isEmpty {
                chart(color: color, size: geo.size)
            } else {
                ZStack(alignment: .topLeading) {
                    ForEach(tint.indices, id: \.self) { i in
                        let x = axis.x(tint[i].from, width: geo.size.width)
                        let width = max(axis.x(tint[i].to, width: geo.size.width) - x, 0)
                        chart(color: tint[i].color, size: geo.size)
                            .mask(alignment: .topLeading) {
                                Rectangle().frame(width: width, height: geo.size.height).offset(x: x)
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder private func chart(color: Color, size: CGSize) -> some View {
        ZStack {
            switch style {
            case .area, .line:
                let segments = self.segments(in: size)
                ZStack {
                    ForEach(segments.indices, id: \.self) { i in
                        if style == .area {
                            area(segments[i], height: size.height).fill(color.opacity(0.18))
                        }
                        line(segments[i]).stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    }
                }
            case .bars:
                bars(in: size).fill(color.opacity(0.85))
            }
        }
    }

    private var axis: TimeAxis { TimeAxis(now: now) }

    private func normalized(_ value: Double) -> Double {
        min(max((value - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private func segments(in size: CGSize) -> [[CGPoint]] {
        var result: [[CGPoint]] = []
        var previous: Date?
        for point in points where point.date >= axis.start {
            let x = axis.x(point.date, width: size.width)
            let y = 1 + (size.height - 2) * (1 - normalized(point.value))
            if let previous, point.date.timeIntervalSince(previous) <= 60, !result.isEmpty {
                result[result.count - 1].append(CGPoint(x: x, y: y))
            } else {
                result.append([CGPoint(x: x, y: y)])
            }
            previous = point.date
        }
        return result.filter { $0.count > 1 }
    }

    private func line(_ points: [CGPoint]) -> Path {
        Path { $0.addLines(points) }
    }

    private func area(_ points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLines(points)
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }

    /// Averages the samples into fixed time buckets, one bar each. Empty buckets stay empty.
    private func bars(in size: CGSize) -> Path {
        let bucket = TimeAxis.window / Double(Self.barCount)
        var sums = [Double](repeating: 0, count: Self.barCount)
        var counts = [Int](repeating: 0, count: Self.barCount)
        for point in points where point.date >= axis.start {
            let i = min(Int(point.date.timeIntervalSince(axis.start) / bucket), Self.barCount - 1)
            sums[i] += point.value
            counts[i] += 1
        }
        let width = size.width / CGFloat(Self.barCount)
        return Path { path in
            for i in 0..<Self.barCount where counts[i] > 0 {
                let height = max(size.height * normalized(sums[i] / Double(counts[i])), 1)
                path.addRoundedRect(
                    in: CGRect(x: CGFloat(i) * width + 0.5, y: size.height - height, width: max(width - 1, 1), height: height),
                    cornerSize: CGSize(width: 1, height: 1)
                )
            }
        }
    }
}

struct ThermalBand: View {
    let history: [ThermalEvent]
    let now: Date
    let settings: Settings

    var body: some View {
        GeometryReader { geo in
            let axis = TimeAxis(now: now)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                ForEach(Array(history.enumerated()), id: \.offset) { i, event in
                    let to = i + 1 < history.count ? history[i + 1].date : now
                    let x = axis.x(event.date, width: geo.size.width)
                    let width = max(axis.x(to, width: geo.size.width) - x, 0)
                    Rectangle().fill(settings.color(for: event.state)).frame(width: width).offset(x: x)
                }
            }
            .clipShape(Capsule())
        }
    }
}
