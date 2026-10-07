package plotkit.chart

import std.collection.*
import plotkit.core.*
import plotkit.svg.*

/** 单序列折线图 */
public func lineChart(labels: Array<String>, values: Array<Float64>, opts: ChartOptions): PlotFrame {
    let one = ArrayList<Series>()
    one.add(Series("", values))
    return lineChartMulti(labels, one.toArray(), opts)
}

/**
 * 多序列折线图. 各序列共用分类轴, 用颜色区分.
 * 当 values 数量少于标签数量时, 只绘制有数据的部分.
 */
public func lineChartMulti(labels: Array<String>, series: Array<Series>, opts: ChartOptions): PlotFrame {
    let n = labels.size
    let frame = PlotFrame(opts, 0.0, 1.0, minAcross(series), maxAcross(series), false)
    let th = opts.theme
    if (series.size == 0 || n == 0) {
        return frame
    }

    var si = 0
    while (si < series.size) {
        let vals = series[si].values
        let color = th.seriesColor(si)
        let pts = ArrayList<Float64>()
        var i = 0
        while (i < n && i < vals.size) {
            pts.add(frame.bandCenter(i, n))
            pts.add(frame.yScale.map(vals[i]))
            i = i + 1
        }
        let flat = pts.toArray()
        frame.doc.polyline(flat, color, 2.5)

        // 数据点
        var j = 0
        while (j + 1 < flat.size) {
            frame.doc.circle(flat[j], flat[j + 1], 3.5, color, th.plotBackground, 1.5, 1.0)
            if (opts.showValues) {
                frame.doc.text(flat[j], flat[j + 1] - 10.0, label(vals[j / 2]), "middle", 11.0, th.textColor, 0.0)
            }
            j = j + 2
        }
        si = si + 1
    }

    frame.drawXLabels(labels)
    if (series.size > 1) {
        frame.drawLegend(seriesNames(series))
    }
    return frame
}
