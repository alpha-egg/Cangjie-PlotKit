package plotkit.chart

import std.collection.*
import plotkit.core.*
import plotkit.svg.*

/** 单序列柱状图 */
public func barChart(labels: Array<String>, values: Array<Float64>, opts: ChartOptions): PlotFrame {
    let one = ArrayList<Series>()
    one.add(Series("", values))
    return barChartGrouped(labels, one.toArray(), opts)
}

/**
 * 分组柱状图. 每个分类下并排绘制 series.size 根柱子.
 */
public func barChartGrouped(labels: Array<String>, series: Array<Series>, opts: ChartOptions): PlotFrame {
    let n = labels.size
    let frame = PlotFrame(opts, 0.0, 1.0, minAcross(series), maxAcross(series), false)
    let th = opts.theme
    let k = series.size
    if (k == 0 || n == 0) {
        return frame
    }

    let band = frame.bandWidth(n)
    let groupW = band * 0.72
    let barW = groupW / Float64(k)

    // 柱子的基线: 值 0 所在的位置, 越界时收敛到绘图区内
    let top = frame.y0
    let bottom = frame.y0 + frame.h
    var base = frame.yScale.map(0.0)
    if (base < top) {
        base = top
    }
    if (base > bottom) {
        base = bottom
    }

    var si = 0
    while (si < k) {
        let vals = series[si].values
        let color = th.seriesColor(si)
        var i = 0
        while (i < n && i < vals.size) {
            let cx = frame.bandCenter(i, n)
            let left = cx - groupW / 2.0 + barW * Float64(si)
            let vy = frame.yScale.map(vals[i])
            var ry = vy
            var rh = base - vy
            if (rh < 0.0) {
                ry = base
                rh = -rh
            }
            // 极小值也给出可辨识的最小高度
            if (vals[i] != 0.0 && rh < 1.0) {
                rh = 1.0
                ry = base - 1.0
            }
            frame.doc.rect(left, ry, barW, rh, color, "", 0.0)
            if (opts.showValues) {
                frame.doc.text(left + barW / 2.0, ry - 6.0, label(vals[i]), "middle", 11.0, th.textColor, 0.0)
            }
            i = i + 1
        }
        si = si + 1
    }

    frame.drawXLabels(labels)
    if (k > 1) {
        frame.drawLegend(seriesNames(series))
    }
    return frame
}

/** 从序列中收集图例名称, 全部为空时返回空数组 */
public func seriesNames(series: Array<Series>): Array<String> {
    let out = ArrayList<String>()
    var any = false
    for (s in series) {
        if (s.name.size > 0) {
            any = true
        }
        out.add(s.name)
    }
    if (!any) {
        return Array<String>()
    }
    return out.toArray()
}
