package plotkit.chart

/** 配色主题 */
public class Theme {
    public let background: String
    public let plotBackground: String
    public let axisColor: String
    public let gridColor: String
    public let textColor: String
    public let titleColor: String
    private let series: Array<String>

    public init(background: String, plotBackground: String, axisColor: String,
                gridColor: String, textColor: String, titleColor: String,
                series: Array<String>) {
        this.background = background
        this.plotBackground = plotBackground
        this.axisColor = axisColor
        this.gridColor = gridColor
        this.textColor = textColor
        this.titleColor = titleColor
        this.series = series
    }

    /** 按序号取分类色板颜色, 循环使用 */
    public func seriesColor(i: Int64): String {
        if (this.series.size == 0) {
            return "#1f77b4"
        }
        var k = i % this.series.size
        if (k < 0) {
            k = k + this.series.size
        }
        return this.series[k]
    }

    public func paletteSize(): Int64 {
        return this.series.size
    }
}

public func lightTheme(): Theme {
    return Theme(
        "#ffffff",
        "#fafafa",
        "#888888",
        "#e8e8e8",
        "#555555",
        "#222222",
        ["#4c78a8", "#f58518", "#54a24b", "#e45756", "#72b7b2", "#b279a2", "#eeca3b", "#9d755d"]
    )
}

public func darkTheme(): Theme {
    return Theme(
        "#1e1e1e",
        "#252526",
        "#6a6a6a",
        "#3a3a3a",
        "#c8c8c8",
        "#f0f0f0",
        ["#7fb3ff", "#ffb454", "#8fd47c", "#ff8a80", "#7fd4d0", "#d9a7d4", "#ffe066", "#c9a98c"]
    )
}

/** 一条数据序列. 柱状图/折线图中按顺序与分类标签对齐 */
public class Series {
    public let name: String
    public let values: Array<Float64>

    public init(name: String, values: Array<Float64>) {
        this.name = name
        this.values = values
    }
}

public func series(name: String, values: Array<Float64>): Series {
    return Series(name, values)
}

/** 全部序列中的最小值; 无数据时返回 0 */
public func minAcross(series: Array<Series>): Float64 {
    var m = 0.0
    var first = true
    for (s in series) {
        for (v in s.values) {
            if (first) {
                m = v
                first = false
            } else if (v < m) {
                m = v
            }
        }
    }
    return m
}

/** 全部序列中的最大值; 无数据时返回 1 */
public func maxAcross(series: Array<Series>): Float64 {
    var m = 1.0
    var first = true
    for (s in series) {
        for (v in s.values) {
            if (first) {
                m = v
                first = false
            } else if (v > m) {
                m = v
            }
        }
    }
    return m
}

/** 散点序列: 成对的 x/y 数值 */
public class XYSeries {
    public let name: String
    public let xs: Array<Float64>
    public let ys: Array<Float64>

    public init(name: String, xs: Array<Float64>, ys: Array<Float64>) {
        this.name = name
        this.xs = xs
        this.ys = ys
    }

    public func size(): Int64 {
        if (this.xs.size < this.ys.size) {
            return this.xs.size
        }
        return this.ys.size
    }
}

public func xySeries(name: String, xs: Array<Float64>, ys: Array<Float64>): XYSeries {
    return XYSeries(name, xs, ys)
}

/** 全部散点序列的 x 范围 */
public func xRangeOf(series: Array<XYSeries>): Array<Float64> {
    var lo = 0.0
    var hi = 1.0
    var first = true
    for (s in series) {
        for (v in s.xs) {
            if (first) {
                lo = v
                hi = v
                first = false
            } else if (v < lo) {
                lo = v
            } else if (v > hi) {
                hi = v
            }
        }
    }
    return [lo, hi]
}

/** 全部散点序列的 y 范围 */
public func yRangeOf(series: Array<XYSeries>): Array<Float64> {
    var lo = 0.0
    var hi = 1.0
    var first = true
    for (s in series) {
        for (v in s.ys) {
            if (first) {
                lo = v
                hi = v
                first = false
            } else if (v < lo) {
                lo = v
            } else if (v > hi) {
                hi = v
            }
        }
    }
    return [lo, hi]
}

/** 图表配置 */
public class ChartOptions {
    public var width: Float64
    public var height: Float64
    public var title: String
    public var xLabel: String
    public var yLabel: String
    public var theme: Theme
    public var showGrid: Bool
    public var showValues: Bool
    public var fromZero: Bool
    public var yTicks: Int64
    public var xTicks: Int64
    /** 散点图上叠加最小二乘趋势线 */
    public var showTrend: Bool

    public init() {
        this.width = 800.0
        this.height = 500.0
        this.title = ""
        this.xLabel = ""
        this.yLabel = ""
        this.theme = lightTheme()
        this.showGrid = true
        this.showValues = false
        this.fromZero = true
        this.yTicks = 5
        this.xTicks = 5
        this.showTrend = false
    }
}
