package plotkit

import std.collection.*
import std.fs.*
import plotkit.chart.*
import plotkit.cli.*
import plotkit.core.*
import plotkit.data.*

/** 分类轴上的数据: 分类标签 + 一条或多条数值序列 */
class Prepared {
    let categories: Array<String>
    let series: Array<Series>

    init(categories: Array<String>, series: Array<Series>) {
        this.categories = categories
        this.series = series
    }
}

main(args: Array<String>): Int64 {
    let fl = Flags(args)
    let pos = fl.positional()
    if (pos.size == 0) {
        printUsage()
        return 0
    }
    let cmd = pos[0]
    if (cmd == "help" || cmd == "-h" || cmd == "--help") {
        printUsage()
        return 0
    }
    if (cmd == "version") {
        println("plotkit 0.1.0")
        return 0
    }
    if (cmd == "bar" || cmd == "line" || cmd == "scatter") {
        return runChart(cmd, fl, pos)
    }
    println("error: unknown command '${cmd}'")
    printUsage()
    return 1
}

func runChart(cmd: String, fl: Flags, pos: Array<String>): Int64 {
    if (pos.size < 2) {
        println("error: missing <csv> argument")
        printUsage()
        return 1
    }
    let path = pos[1]
    let xName = fl.get("x", "")
    let yName = fl.get("y", "")
    if (xName.size == 0 || yName.size == 0) {
        println("error: --x and --y are required")
        return 1
    }

    let maybeT = tryReadCsv(path)
    if (maybeT.isNone()) {
        println("error: cannot read CSV file '${path}'")
        return 1
    }
    let t = maybeT.getOrThrow()
    if (!t.hasColumn(xName)) {
        println("error: column not found: ${xName}")
        return 1
    }
    if (!t.hasColumn(yName)) {
        println("error: column not found: ${yName}")
        return 1
    }

    let opts = buildOptions(fl, yName)

    if (cmd == "scatter") {
        return runScatter(t, fl, opts, xName, yName)
    }

    let how = fl.get("agg", "mean")
    if (!isKnownAgg(how)) {
        println("error: unknown --agg '${how}' (mean|sum|count|min|max)")
        return 1
    }

    // --series 是 --group 的别名
    var gcol = fl.get("group", "")
    if (gcol.size == 0) {
        gcol = fl.get("series", "")
    }
    if (gcol.size > 0 && !t.hasColumn(gcol)) {
        println("error: column not found: ${gcol}")
        return 1
    }

    var prep = prepare(t, t.strColumn(xName), t.numColumn(yName), gcol, how)

    let order = fl.get("sort", "none")
    if (order == "asc" || order == "desc") {
        prep = reorder(prep, order)
    }

    var frame: PlotFrame
    if (cmd == "bar") {
        frame = barChartGrouped(prep.categories, prep.series, opts)
    } else {
        frame = lineChartMulti(prep.categories, prep.series, opts)
    }

    return emit(frame, fl, cmd, "${prep.categories.size} categories, ${prep.series.size} series")
}

/** 读 CSV; 文件不存在或内容无法解码时返回 None, 由调用方给出提示 */
func tryReadCsv(path: String): Option<Table> {
    if (!exists(path)) {
        return None
    }
    try {
        return Some(readCsv(path))
    } catch (e: Exception) {
        return None
    }
}

/** 把 (x, y) 两列整理成分类轴数据; gcol 为空时不分组 */
func prepare(t: Table, xv: Array<String>, yv: Array<Float64>, gcol: String, how: String): Prepared {
    if (gcol.size == 0) {
        let g = groupAgg(xv, yv, how)
        let one = ArrayList<Series>()
        one.add(Series("", g.values))
        return Prepared(g.keys, one.toArray())
    }
    let g = pivot(xv, t.strColumn(gcol), yv, how)
    let lst = ArrayList<Series>()
    var i = 0
    while (i < g.nseries()) {
        lst.add(Series(g.names[i], g.row(i)))
        i = i + 1
    }
    return Prepared(g.categories, lst.toArray())
}

func runScatter(t: Table, fl: Flags, opts: ChartOptions, xName: String, yName: String): Int64 {
    let xs = t.numColumn(xName)
    let ys = t.numColumn(yName)
    // 散点图默认贴合数据范围, 否则点会全挤在顶部; 需要时用 --from-zero 打开
    opts.fromZero = fl.flag("fromzero")
    var gcol = fl.get("group", "")
    if (gcol.size == 0) {
        gcol = fl.get("series", "")
    }
    if (gcol.size > 0 && !t.hasColumn(gcol)) {
        println("error: column not found: ${gcol}")
        return 1
    }

    let lst = ArrayList<XYSeries>()
    if (gcol.size == 0) {
        lst.add(XYSeries("", xs, ys))
    } else {
        let gv = t.strColumn(gcol)
        let names = ArrayList<String>()
        let bxs = ArrayList<ArrayList<Float64>>()
        let bys = ArrayList<ArrayList<Float64>>()
        var i = 0
        while (i < xs.size && i < ys.size && i < gv.size) {
            var pos = -1
            var j = 0
            while (j < names.size) {
                if (names[j] == gv[i]) {
                    pos = j
                    break
                }
                j = j + 1
            }
            if (pos < 0) {
                names.add(gv[i])
                bxs.add(ArrayList<Float64>())
                bys.add(ArrayList<Float64>())
                pos = names.size - 1
            }
            bxs[pos].add(xs[i])
            bys[pos].add(ys[i])
            i = i + 1
        }
        var k = 0
        while (k < names.size) {
            lst.add(XYSeries(names[k], bxs[k].toArray(), bys[k].toArray()))
            k = k + 1
        }
    }

    let frame = scatterChartMulti(lst.toArray(), opts)
    let code = emit(frame, fl, "scatter", "${lst.size} series")
    if (opts.showTrend) {
        let fit = linearFit(xs, ys)
        println("linear fit: y = ${fmtNum(fit[0], 6)} x + ${fmtNum(fit[1], 6)}   r2 = ${fmtNum(fit[2], 4)}")
    }
    return code
}

// ---------- 辅助 ----------

func buildOptions(fl: Flags, yName: String): ChartOptions {
    let o = ChartOptions()
    o.width = fl.getFloat("width", 800.0)
    o.height = fl.getFloat("height", 500.0)
    o.title = fl.get("title", "")
    o.xLabel = fl.get("xlabel", "")
    o.yLabel = fl.get("ylabel", yName)
    if (fl.get("theme", "light") == "dark") {
        o.theme = darkTheme()
    }
    o.showGrid = !fl.flag("nogrid")
    o.showValues = fl.flag("values")
    o.showTrend = fl.flag("trend")
    if (fl.flag("nofromzero")) {
        o.fromZero = false
    }
    let yt = fl.getInt("yticks", 5)
    if (yt >= 2) {
        o.yTicks = yt
    }
    let xt = fl.getInt("xticks", 5)
    if (xt >= 2) {
        o.xTicks = xt
    }
    return o
}

/** 按各序列合计值重排分类; order 取 "asc" 或 "desc" */
func reorder(p: Prepared, order: String): Prepared {
    let n = p.categories.size
    let idx = ArrayList<Int64>()
    var i = 0
    while (i < n) {
        idx.add(i)
        i = i + 1
    }
    let a = idx.toArray()

    let totals = ArrayList<Float64>()
    i = 0
    while (i < n) {
        var s = 0.0
        for (ser in p.series) {
            if (i < ser.values.size) {
                s = s + ser.values[i]
            }
        }
        totals.add(s)
        i = i + 1
    }

    // 数据量小, 冒泡排序即可, 避免依赖额外的排序 API
    var pass = 0
    while (pass < n) {
        var q = 0
        while (q + 1 < n - pass) {
            let left = totals[a[q]]
            let right = totals[a[q + 1]]
            var swap = left > right
            if (order == "desc") {
                swap = left < right
            }
            if (swap) {
                let tmp = a[q]
                a[q] = a[q + 1]
                a[q + 1] = tmp
            }
            q = q + 1
        }
        pass = pass + 1
    }

    let cats = ArrayList<String>()
    for (j in a) {
        cats.add(p.categories[j])
    }
    let sers = ArrayList<Series>()
    for (ser in p.series) {
        let vals = ArrayList<Float64>()
        for (j in a) {
            if (j < ser.values.size) {
                vals.add(ser.values[j])
            } else {
                vals.add(0.0)
            }
        }
        sers.add(Series(ser.name, vals.toArray()))
    }
    return Prepared(cats.toArray(), sers.toArray())
}

func emit(frame: PlotFrame, fl: Flags, cmd: String, detail: String): Int64 {
    var out = fl.get("out", "")
    if (out.size == 0) {
        out = fl.get("o", "")
    }
    if (out.size == 0) {
        out = "${cmd}.svg"
    }
    ensureParent(out)
    frame.save(out)
    println("wrote ${out}  (${detail})")
    return 0
}

/** 输出路径含目录时先尝试创建 */
func ensureParent(path: String): Unit {
    var cut = -1
    var i = 0
    while (i < path.size) {
        let c = path[i]
        if (c == b'/' || c == b'\\') {
            cut = i
        }
        i = i + 1
    }
    if (cut <= 0) {
        return
    }
    try {
        Directory.create(path[0..cut], recursive: true)
    } catch (e: Exception) {
        // 目录已存在或创建失败, 交给真正写文件时报错
    }
}

func printUsage(): Unit {
    println("plotkit 0.1.0 - CSV 数据 -> SVG 图表")
    println("")
    println("用法:")
    println("  plotkit bar     <data.csv> --x <列> --y <列> [--group <列>] [--agg mean|sum|count|min|max] [--sort asc|desc]")
    println("  plotkit line    <data.csv> --x <列> --y <列> [--series <列>] [--agg ...] [--sort asc|desc]")
    println("  plotkit scatter <data.csv> --x <列> --y <列> [--group <列>] [--trend]")
    println("  plotkit version")
    println("")
    println("通用选项:")
    println("  -o, --out <文件>      输出 SVG 路径 (默认 <命令>.svg)")
    println("      --title <文字>    图表标题")
    println("      --xlabel <文字>   x 轴标题")
    println("      --ylabel <文字>   y 轴标题 (默认取 --y 的列名)")
    println("      --theme light|dark")
    println("      --width/--height  画布尺寸, 默认 800x500")
    println("      --values          在图形上标注数值")
    println("      --no-grid         关闭网格线")
    println("      --no-from-zero    y 轴不从 0 开始 (柱状图/折线图)")
    println("      --from-zero       散点图 y 轴从 0 开始")
    println("      --trend           散点图叠加最小二乘趋势线")
    println("")
    println("示例:")
    println("  plotkit bar data/sales.csv --x month --y amount --group region --agg sum -o out/sales.svg")
    println("  plotkit scatter data/measure.csv --x height --y weight --trend")
}
