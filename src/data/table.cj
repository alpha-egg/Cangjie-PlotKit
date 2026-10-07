package plotkit.data

import std.collection.*
import std.convert.*
import plotkit.core.*

/**
 * 轻量列式表格. 以"列名 -> 字符串数组"的方式存储数据,
 * 按需解析为数值列. 不提供索引、连接等高级特性.
 */
public class Table {
    public let headers: Array<String>
    private let columns: ArrayList<ArrayList<String>>

    public init(headers: Array<String>) {
        this.headers = headers
        this.columns = ArrayList<ArrayList<String>>()
        var i = 0
        while (i < headers.size) {
            this.columns.add(ArrayList<String>())
            i = i + 1
        }
    }

    public func ncols(): Int64 {
        return this.headers.size
    }

    public func nrows(): Int64 {
        if (this.columns.size == 0) {
            return 0
        }
        return this.columns[0].size
    }

    /** 返回列名对应的下标; 不存在时返回 -1 */
    public func colIndex(name: String): Int64 {
        var i = 0
        while (i < this.headers.size) {
            if (this.headers[i] == name) {
                return i
            }
            i = i + 1
        }
        return -1
    }

    public func hasColumn(name: String): Bool {
        return this.colIndex(name) >= 0
    }

    public func addRow(cells: Array<String>): Unit {
        var i = 0
        while (i < this.columns.size) {
            if (i < cells.size) {
                this.columns[i].add(cells[i])
            } else {
                this.columns[i].add("")
            }
            i = i + 1
        }
    }

    /** 取字符串列; 列名不存在时抛异常 */
    public func strColumn(name: String): Array<String> {
        let idx = this.colIndex(name)
        if (idx < 0) {
            throw IllegalArgumentException("column not found: ${name}")
        }
        return this.columns[idx].toArray()
    }

    /** 取数值列; 无法解析的单元格按 0 处理 */
    public func numColumn(name: String): Array<Float64> {
        let raw = this.strColumn(name)
        let out = ArrayList<Float64>()
        for (s in raw) {
            let t = s.trimAscii()
            if (t.size == 0) {
                out.add(0.0)
            } else {
                out.add(Float64.parse(t))
            }
        }
        return out.toArray()
    }

    public func head(n: Int64): String {
        var s = joinStrings(this.headers, ",") + "\n"
        var i = 0
        while (i < n && i < this.nrows()) {
            let cells = ArrayList<String>()
            var j = 0
            while (j < this.ncols()) {
                cells.add(this.columns[j][i])
                j = j + 1
            }
            s = s + joinStrings(cells.toArray(), ",") + "\n"
            i = i + 1
        }
        return s
    }
}

// ---------- 统计函数 ----------

public func sumOf(v: Array<Float64>): Float64 {
    var s = 0.0
    for (x in v) {
        s = s + x
    }
    return s
}

public func meanOf(v: Array<Float64>): Float64 {
    if (v.size == 0) {
        return 0.0
    }
    return sumOf(v) / Float64(v.size)
}

public func minOf(v: Array<Float64>): Float64 {
    if (v.size == 0) {
        return 0.0
    }
    var m = v[0]
    for (x in v) {
        if (x < m) {
            m = x
        }
    }
    return m
}

public func maxOf(v: Array<Float64>): Float64 {
    if (v.size == 0) {
        return 0.0
    }
    var m = v[0]
    for (x in v) {
        if (x > m) {
            m = x
        }
    }
    return m
}

/** 分组聚合结果: 键与对应的聚合值 */
public class Grouped {
    public let keys: Array<String>
    public let values: Array<Float64>

    public init(keys: Array<String>, values: Array<Float64>) {
        this.keys = keys
        this.values = values
    }

    public func len(): Int64 {
        return this.keys.size
    }
}

/** 按名称对一组数值做聚合; 未知名称按均值处理 */
public func aggOf(v: Array<Float64>, how: String): Float64 {
    if (how == "sum") {
        return sumOf(v)
    }
    if (how == "count") {
        return Float64(v.size)
    }
    if (how == "min") {
        return minOf(v)
    }
    if (how == "max") {
        return maxOf(v)
    }
    return meanOf(v)
}

/** 分组聚合的名称是否受支持 */
public func isKnownAgg(how: String): Bool {
    return how == "mean" || how == "sum" || how == "count" || how == "min" || how == "max"
}

/**
 * 按 key 分组后对 values 聚合.
 * 键按首次出现顺序排列, 因此 x 轴顺序与数据出现顺序一致.
 */
public func groupAgg(keys: Array<String>, values: Array<Float64>, how: String): Grouped {
    let uniq = ArrayList<String>()
    let buckets = ArrayList<ArrayList<Float64>>()
    var i = 0
    while (i < keys.size) {
        let k = keys[i]
        var pos = -1
        var j = 0
        while (j < uniq.size) {
            if (uniq[j] == k) {
                pos = j
                break
            }
            j = j + 1
        }
        if (pos < 0) {
            uniq.add(k)
            buckets.add(ArrayList<Float64>())
            pos = uniq.size - 1
        }
        if (i < values.size) {
            buckets[pos].add(values[i])
        }
        i = i + 1
    }

    let out = ArrayList<Float64>()
    for (b in buckets) {
        out.add(aggOf(b.toArray(), how))
    }
    return Grouped(uniq.toArray(), out.toArray())
}

/** 分组求均值的便捷入口 */
public func groupMean(keys: Array<String>, values: Array<Float64>): Grouped {
    return groupAgg(keys, values, "mean")
}

/** 二维透视结果: 行 = 序列, 列 = 分类 */
public class Pivot {
    public let categories: Array<String>
    public let names: Array<String>
    public let matrix: Array<Array<Float64>>

    public init(categories: Array<String>, names: Array<String>, matrix: Array<Array<Float64>>) {
        this.categories = categories
        this.names = names
        this.matrix = matrix
    }

    public func nseries(): Int64 {
        return this.names.size
    }

    public func ncategories(): Int64 {
        return this.categories.size
    }

    /** 取第 i 条序列, 缺失的组合补 0 */
    public func row(i: Int64): Array<Float64> {
        let n = this.ncategories()
        let out = ArrayList<Float64>()
        var j = 0
        while (j < n) {
            if (i < this.matrix.size && j < this.matrix[i].size) {
                out.add(this.matrix[i][j])
            } else {
                out.add(0.0)
            }
            j = j + 1
        }
        return out.toArray()
    }
}

/**
 * 按 (xCol, seriesCol) 交叉分组后聚合 values.
 *
 * 用于"分组柱状图"和"多序列折线图": 分类来自 xCol, 每条线/每组柱来自 seriesCol.
 */
public func pivot(xCol: Array<String>, seriesCol: Array<String>, values: Array<Float64>, how: String): Pivot {
    let cats = ArrayList<String>()
    let snames = ArrayList<String>()
    let cells = ArrayList<ArrayList<ArrayList<Float64>>>()

    var i = 0
    while (i < xCol.size) {
        let c = xCol[i]
        let s = if (i < seriesCol.size) { seriesCol[i] } else { "" }

        var ci = -1
        var a = 0
        while (a < cats.size) {
            if (cats[a] == c) {
                ci = a
                break
            }
            a = a + 1
        }
        if (ci < 0) {
            cats.add(c)
            ci = cats.size - 1
        }

        var si = -1
        var b = 0
        while (b < snames.size) {
            if (snames[b] == s) {
                si = b
                break
            }
            b = b + 1
        }
        if (si < 0) {
            snames.add(s)
            si = snames.size - 1
            // 新序列补齐已有分类的空桶
            let row = ArrayList<ArrayList<Float64>>()
            var t = 0
            while (t < cats.size) {
                row.add(ArrayList<Float64>())
                t = t + 1
            }
            cells.add(row)
        }
        // 新分类在各序列下补空桶
        var r = 0
        while (r < cells.size) {
            while (cells[r].size < cats.size) {
                cells[r].add(ArrayList<Float64>())
            }
            r = r + 1
        }

        if (i < values.size) {
            cells[si][ci].add(values[i])
        }
        i = i + 1
    }

    let mat = ArrayList<Array<Float64>>()
    for (row in cells) {
        let r = ArrayList<Float64>()
        for (cell in row) {
            r.add(aggOf(cell.toArray(), how))
        }
        mat.add(r.toArray())
    }
    return Pivot(cats.toArray(), snames.toArray(), mat.toArray())
}
