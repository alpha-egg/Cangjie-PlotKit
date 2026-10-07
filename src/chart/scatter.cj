package plotkit.chart

import std.collection.*
import plotkit.core.*
import plotkit.svg.*

/** 单序列散点图 */
public func scatterChart(xs: Array<Float64>, ys: Array<Float64>, opts: ChartOptions): PlotFrame {
    let one = ArrayList<XYSeries>()
    one.add(XYSeries("", xs, ys))
    return scatterChartMulti(one.toArray(), opts)
}

/**
 * 多序列散点图. x 轴为数值轴, 每个点半径一致,
 * 开启 showTrend 时叠加最小二乘趋势线.
 */
public func scatterChartMulti(series: Array<XYSeries>, opts: ChartOptions): PlotFrame {
    let xr = xRangeOf(series)
    let yr = yRangeOf(series)
    let frame = PlotFrame(opts, xr[0], xr[1], yr[0], yr[1], true)
    let th = opts.theme
    if (series.size == 0) {
        return frame
    }

    // 趋势线在散点之下绘制
    if (opts.showTrend) {
        var si = 0
        while (si < series.size) {
            drawTrend(frame, series[si], th.seriesColor(si))
            si = si + 1
        }
    }

    var si2 = 0
    while (si2 < series.size) {
        let s = series[si2]
        let color = th.seriesColor(si2)
        let n = s.size()
        var i = 0
        while (i < n) {
            let cx = frame.mapX(s.xs[i])
            let cy = frame.yScale.map(s.ys[i])
            frame.doc.circle(cx, cy, 4.5, color, th.background, 1.0, 0.85)
            i = i + 1
        }
        si2 = si2 + 1
    }

    if (series.size > 1) {
        var anyName = false
        let names = ArrayList<String>()
        for (s in series) {
            if (s.name.size > 0) {
                anyName = true
            }
            names.add(s.name)
        }
        if (anyName) {
            frame.drawLegend(names.toArray())
        }
    }
    return frame
}

/** 在散点图上叠加一条虚线趋势线 */
private func drawTrend(frame: PlotFrame, s: XYSeries, color: String): Unit {
    let n = s.size()
    if (n < 2) {
        return
    }
    let fit = linearFit(s.xs, s.ys)
    var xlo = s.xs[0]
    var xhi = s.xs[0]
    var i = 0
    while (i < n) {
        if (s.xs[i] < xlo) {
            xlo = s.xs[i]
        }
        if (s.xs[i] > xhi) {
            xhi = s.xs[i]
        }
        i = i + 1
    }
    let y1 = fit[0] * xlo + fit[1]
    let y2 = fit[0] * xhi + fit[1]
    frame.doc.dashedLine(frame.mapX(xlo), frame.yScale.map(y1),
                         frame.mapX(xhi), frame.yScale.map(y2),
                         color, 2.0, "6 4")
}
