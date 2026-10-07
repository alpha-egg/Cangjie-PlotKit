package plotkit.core

/**
 * 将浮点数格式化为指定小数位数, 并去掉多余的尾随零.
 *
 * fmtNum(480.0, 2)  -> "480"
 * fmtNum(88.5, 2)   -> "88.5"
 * fmtNum(0.333, 2)  -> "0.33"
 */
public func fmtNum(v: Float64, digits: Int64): String {
    var s = v.toString()
    if (digits < 0) {
        return s
    }
    match (s.indexOf(".")) {
        case Some(d) =>
            var end = d + 1 + digits
            if (end > s.size) {
                end = s.size
            }
            var t = s[0..end]
            while (t.size > 0 && t[t.size - 1] == b'0') {
                t = t[0..(t.size - 1)]
            }
            if (t.size > 0 && t[t.size - 1] == b'.') {
                t = t[0..(t.size - 1)]
            }
            s = t
        case None => ()
    }
    return s
}

/** 坐标输出统一保留 2 位小数 */
public func coord(v: Float64): String {
    return fmtNum(v, 2)
}

/** Array<String> 没有内置 join, 这里补一个 */
public func joinStrings(parts: Array<String>, sep: String): String {
    var s = ""
    var i = 0
    while (i < parts.size) {
        if (i > 0) {
            s = s + sep
        }
        s = s + parts[i]
        i = i + 1
    }
    return s
}

/** 数值标签: 大数自动保留较少小数位 */
public func label(v: Float64): String {
    let a = if (v < 0.0) { -v } else { v }
    if (a >= 1000.0) {
        return fmtNum(v, 0)
    }
    if (a >= 10.0) {
        return fmtNum(v, 1)
    }
    return fmtNum(v, 2)
}
