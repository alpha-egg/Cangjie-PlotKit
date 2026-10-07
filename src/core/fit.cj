package plotkit.core

/**
 * 最小二乘一元线性拟合.
 *
 * 返回 [slope, intercept, r2]:
 *   slope     - 斜率
 *   intercept - 截距
 *   r2        - 决定系数, 越接近 1 说明线性关系越强
 *
 * 样本不足 2 个或 x 全为同一值时, 返回 [0, y 均值, 0].
 */
public func linearFit(xs: Array<Float64>, ys: Array<Float64>): Array<Float64> {
    var n = 0
    if (xs.size < ys.size) {
        n = xs.size
    } else {
        n = ys.size
    }

    var sx = 0.0
    var sy = 0.0
    var i = 0
    while (i < n) {
        sx = sx + xs[i]
        sy = sy + ys[i]
        i = i + 1
    }

    if (n < 2) {
        return [0.0, if (n == 1) { ys[0] } else { 0.0 }, 0.0]
    }

    let mx = sx / Float64(n)
    let my = sy / Float64(n)

    var sxy = 0.0
    var sxx = 0.0
    var syy = 0.0
    i = 0
    while (i < n) {
        let dx = xs[i] - mx
        let dy = ys[i] - my
        sxy = sxy + dx * dy
        sxx = sxx + dx * dx
        syy = syy + dy * dy
        i = i + 1
    }

    if (sxx == 0.0) {
        return [0.0, my, 0.0]
    }

    let slope = sxy / sxx
    let intercept = my - slope * mx

    var r2 = 0.0
    if (syy > 0.0) {
        r2 = (sxy * sxy) / (sxx * syy)
    }
    return [slope, intercept, r2]
}
