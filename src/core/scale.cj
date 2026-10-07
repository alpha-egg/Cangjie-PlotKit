package plotkit.core

import std.math.*
import std.collection.*

/**
 * 线性坐标映射: 把数据域 [domainStart, domainEnd] 线性映射到绘图区 [rangeStart, rangeEnd].
 */
public class LinearScale {
    public let domainStart: Float64
    public let domainEnd: Float64
    public let rangeStart: Float64
    public let rangeEnd: Float64

    public init(ds: Float64, de: Float64, rs: Float64, re: Float64) {
        this.domainStart = ds
        this.domainEnd = de
        this.rangeStart = rs
        this.rangeEnd = re
    }

    public func map(v: Float64): Float64 {
        let d = this.domainEnd - this.domainStart
        if (d == 0.0) {
            return this.rangeStart
        }
        let t = (v - this.domainStart) / d
        return this.rangeStart + t * (this.rangeEnd - this.rangeStart)
    }
}

/**
 * 自动刻度算法 ("nice numbers").
 * 给定数据范围与期望刻度数, 返回一组间距美观的刻度值.
 */
public func niceTicks(lo: Float64, hi: Float64, target: Int64): Array<Float64> {
    var mn = lo
    var mx = hi
    if (mx - mn < 1e-9) {
        mx = mn + 1.0
    }

    let rawStep = (mx - mn) / Float64(target)
    let mag = pow(10.0, floor(log10(rawStep)))
    let norm = rawStep / mag

    var mult = 10.0
    if (norm <= 1.0) {
        mult = 1.0
    } else if (norm <= 2.0) {
        mult = 2.0
    } else if (norm <= 5.0) {
        mult = 5.0
    }
    let step = mag * mult

    // 用下标推导刻度值, 保证首尾刻度完整覆盖数据范围, 并消掉浮点尾数
    let first = floor(mn / step)
    let last = ceil(mx / step)
    let res = ArrayList<Float64>()
    var k = first
    var guard = 0
    while (k <= last + 1e-9 && guard < 1000) {
        res.add(cleanFloat(k * step))
        k = k + 1.0
        guard = guard + 1
    }
    return res.toArray()
}

/** 抹掉浮点乘法产生的长尾, 例如 0.30000000000000004 -> 0.3 */
private func cleanFloat(v: Float64): Float64 {
    return round(v * 1e9) / 1e9
}

/** 给定数据序列, 返回 [min, max]; 空数组返回 [0, 1] */
public func extent(values: Array<Float64>): Array<Float64> {
    if (values.size == 0) {
        return [0.0, 1.0]
    }
    var mn = values[0]
    var mx = values[0]
    for (v in values) {
        if (v < mn) {
            mn = v
        }
        if (v > mx) {
            mx = v
        }
    }
    return [mn, mx]
}
