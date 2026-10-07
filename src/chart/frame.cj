package plotkit.chart

import plotkit.core.*
import plotkit.svg.*

/**
 * 绘图区框架: 负责留边距布局、坐标轴、网格、标题, 并对外暴露坐标映射.
 *
 * 支持两种 x 轴:
 *   - 分类轴 (numericX = false): 由 [drawXLabels] 按等宽分档绘制标签, 用于柱状图/折线图;
 *   - 数值轴 (numericX = true):  按 nice ticks 绘制刻度, 用于散点图.
 */
public class PlotFrame {
    public let doc: SvgDoc
    public let opts: ChartOptions
    public let x0: Float64
    public let y0: Float64
    public let w: Float64
    public let h: Float64
    public let yScale: LinearScale
    public let ticks: Array<Float64>
    public let numericX: Bool
    /** 数值 x 轴的比例尺; 分类轴时为 None */
    public let xScale: Option<LinearScale>
    public let xTickValues: Array<Float64>

    public init(opts: ChartOptions,
                xDataMin: Float64, xDataMax: Float64,
                yDataMin: Float64, yDataMax: Float64,
                numericX: Bool) {
        let th = opts.theme
        let padL = 72.0
        let padR = 32.0
        let padT = if (opts.title.size > 0) { 58.0 } else { 32.0 }
        let padB = if (opts.xLabel.size > 0) { 78.0 } else { 56.0 }

        let px = padL
        let py = padT
        let pw = opts.width - padL - padR
        let ph = opts.height - padT - padB

        // y 轴: 以美观刻度的端点作为实际值域
        var ylo = yDataMin
        var yhi = yDataMax
        if (opts.fromZero && ylo > 0.0) {
            ylo = 0.0
        }
        let ytk = niceTicks(ylo, yhi, opts.yTicks)

        // x 轴: 数值模式下同样先取美观刻度
        var xtk = Array<Float64>()
        var xs: Option<LinearScale> = None
        if (numericX) {
            let t = niceTicks(xDataMin, xDataMax, opts.xTicks)
            xtk = t
            xs = Some(LinearScale(t[0], t[t.size - 1], px, px + pw))
        }

        this.opts = opts
        this.x0 = px
        this.y0 = py
        this.w = pw
        this.h = ph
        this.ticks = ytk
        this.numericX = numericX
        this.xScale = xs
        this.xTickValues = xtk
        // SVG 的 y 轴向下增长, 因此值域上界映射到绘图区顶部
        this.yScale = LinearScale(ytk[0], ytk[ytk.size - 1], py + ph, py)

        let doc = SvgDoc(opts.width, opts.height, th.background)
        this.doc = doc

        // 绘图区背景
        doc.rect(px, py, pw, ph, th.plotBackground, "", 0.0)

        // 水平网格线与 y 轴刻度标签
        for (t in ytk) {
            let yy = this.yScale.map(t)
            if (opts.showGrid) {
                doc.line(px, yy, px + pw, yy, th.gridColor, 1.0)
            }
            doc.text(px - 12.0, yy + 4.0, label(t), "end", 13.0, th.textColor, 0.0)
        }

        // 数值 x 轴的竖直网格线与刻度标签
        if (numericX) {
            match (xs) {
                case Some(sc) =>
                    for (t in xtk) {
                        let xx = sc.map(t)
                        if (opts.showGrid) {
                            doc.line(xx, py, xx, py + ph, th.gridColor, 1.0)
                        }
                        doc.line(xx, py + ph, xx, py + ph + 5.0, th.axisColor, 1.0)
                        doc.text(xx, py + ph + 22.0, label(t), "middle", 13.0, th.textColor, 0.0)
                    }
                case None => ()
            }
        }

        // 坐标轴
        doc.line(px, py, px, py + ph, th.axisColor, 1.5)
        doc.line(px, py + ph, px + pw, py + ph, th.axisColor, 1.5)

        // 标题
        if (opts.title.size > 0) {
            doc.text(opts.width / 2.0, 34.0, opts.title, "middle", 20.0, th.titleColor, 0.0)
        }
        // y 轴标题 (竖排)
        if (opts.yLabel.size > 0) {
            doc.text(20.0, py + ph / 2.0, opts.yLabel, "middle", 14.0, th.textColor, -90.0)
        }
        // x 轴标题
        if (opts.xLabel.size > 0) {
            doc.text(px + pw / 2.0, opts.height - 18.0, opts.xLabel, "middle", 14.0, th.textColor, 0.0)
        }
    }

    /** 每个分类占据的横向宽度 */
    public func bandWidth(n: Int64): Float64 {
        if (n <= 0) {
            return this.w
        }
        return this.w / Float64(n)
    }

    /** 第 i 个分类的中心 x 坐标 */
    public func bandCenter(i: Int64, n: Int64): Float64 {
        return this.x0 + this.bandWidth(n) * (Float64(i) + 0.5)
    }

    /** 数值 x 轴映射; 分类轴时返回 x0 */
    public func mapX(v: Float64): Float64 {
        match (this.xScale) {
            case Some(sc) => return sc.map(v)
            case None => return this.x0
        }
    }

    /** 绘制 x 轴分类标签 (仅分类轴) */
    public func drawXLabels(labels: Array<String>): Unit {
        if (this.numericX) {
            return
        }
        let n = labels.size
        var i = 0
        while (i < n) {
            this.doc.text(this.bandCenter(i, n), this.y0 + this.h + 22.0,
                          labels[i], "middle", 13.0, this.opts.theme.textColor, 0.0)
            i = i + 1
        }
    }

    /** 绘制图例 (右上角) */
    public func drawLegend(names: Array<String>): Unit {
        if (names.size == 0) {
            return
        }
        let th = this.opts.theme
        let lh = 20.0
        let bw = 14.0
        var maxLen = 0
        for (nm in names) {
            if (nm.size > maxLen) {
                maxLen = nm.size
            }
        }
        let boxW = 40.0 + Float64(maxLen) * 8.0
        let boxH = lh * Float64(names.size) + 14.0
        let bx = this.x0 + this.w - boxW - 10.0
        let by = this.y0 + 10.0

        this.doc.rect(bx, by, boxW, boxH, th.background, th.gridColor, 1.0)
        var i = 0
        while (i < names.size) {
            let cy = by + 14.0 + lh * Float64(i) + lh / 2.0 - 5.0
            this.doc.rect(bx + 10.0, cy, bw, bw, th.seriesColor(i), "", 0.0)
            this.doc.text(bx + 30.0, cy + bw - 2.0, names[i], "start", 13.0, th.textColor, 0.0)
            i = i + 1
        }
    }

    public func save(path: String): Unit {
        this.doc.save(path)
    }

    public func render(): String {
        return this.doc.render()
    }
}
