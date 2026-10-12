package plotkit.data

import std.collection.*
import std.convert.*
import std.fs.*

/** 流式聚合结果: 除分组值外带回扫描到的行数与字节数, 供基准与提示信息使用 */
public class StreamStat {
    public let grouped: Grouped
    public let rows: Int64
    public let bytes: Int64

    public init(grouped: Grouped, rows: Int64, bytes: Int64) {
        this.grouped = grouped
        this.rows = rows
        this.bytes = bytes
    }
}

/**
 * 流式分组聚合.
 *
 * 与 readCsv 的差别在内存模型: 整表加载要先把文件读成一份完整 String, 再按格切出
 * 一个个 String 填进 Table, 解析期间 raw 与 columns 两套容器并存; 这里逐块读文件、
 * 逐行累加, 只保留分组累加器, 内存随分组数增长而与行数无关.
 *
 * 单趟扫出 sum/count/min/max, mean 由 sum 与 count 推出, 因此不同聚合方式的开销相同.
 *
 * keyCol 与 valCol 必须在表头里存在, 否则抛 IllegalArgumentException.
 * 数值单元格解析失败按 0 处理, 与 Table.numColumn 的容错口径一致.
 */
public func streamAggStat(path: String, keyCol: String, valCol: String, how: String): StreamStat {
    if (!isKnownAgg(how)) {
        throw IllegalArgumentException("unknown agg: ${how}")
    }

    let buf = Array<UInt8>(64 * 1024, repeat: 0)

    var keyIdx = -1
    var valIdx = -1
    var headerReady = false

    let hdrCells = ArrayList<String>()
    let keys = ArrayList<String>()
    let index = HashMap<String, Int64>()
    let sums = ArrayList<Float64>()
    let cnts = ArrayList<Int64>()
    let mins = ArrayList<Float64>()
    let maxs = ArrayList<Float64>()

    var field = ArrayList<UInt8>()
    var inQuotes = false
    var col = 0
    var keyVal = ""
    var valVal = ""
    var rowFields = 0
    var rowAllEmpty = true
    var rows = 0
    var total = 0

    let f = File(path, OpenMode.Read)
    try {
        var n = f.read(buf)
        while (n > 0) {
            total = total + n
            var i = 0
            while (i < n) {
                let c = buf[i]
                if (inQuotes) {
                    if (c == b'"') {
                        if (i + 1 < n && buf[i + 1] == b'"') {
                            field.add(b'"')
                            i = i + 2
                        } else {
                            inQuotes = false
                            i = i + 1
                        }
                    } else {
                        field.add(c)
                        i = i + 1
                    }
                } else if (c == b'"') {
                    inQuotes = true
                    i = i + 1
                } else if (c == b',') {
                    // ---- 字段结束 ----
                    rowFields = rowFields + 1
                    if (field.size > 0) {
                        rowAllEmpty = false
                    }
                    if (!headerReady) {
                        hdrCells.add(stripBom(String.fromUtf8(field.toArray())).trimAscii())
                    } else if (col == keyIdx) {
                        keyVal = String.fromUtf8(field.toArray())
                    } else if (col == valIdx) {
                        valVal = String.fromUtf8(field.toArray())
                    }
                    field = ArrayList<UInt8>()
                    col = col + 1
                    i = i + 1
                } else if (c == b'\n') {
                    // ---- 字段结束 + 行结束 ----
                    rowFields = rowFields + 1
                    if (field.size > 0) {
                        rowAllEmpty = false
                    }
                    if (!headerReady) {
                        hdrCells.add(stripBom(String.fromUtf8(field.toArray())).trimAscii())
                    } else if (col == keyIdx) {
                        keyVal = String.fromUtf8(field.toArray())
                    } else if (col == valIdx) {
                        valVal = String.fromUtf8(field.toArray())
                    }
                    field = ArrayList<UInt8>()

                    let blank = rowFields == 0 || (rowFields == 1 && rowAllEmpty)
                    if (!headerReady) {
                        if (!blank) {
                            keyIdx = findIn(hdrCells, keyCol)
                            if (keyIdx < 0) {
                                throw IllegalArgumentException("column not found: ${keyCol}")
                            }
                            valIdx = findIn(hdrCells, valCol)
                            if (valIdx < 0) {
                                throw IllegalArgumentException("column not found: ${valCol}")
                            }
                            headerReady = true
                            hdrCells.clear()
                        }
                    } else if (!blank) {
                        rows = rows + 1
                        accumulate(keys, index, sums, cnts, mins, maxs, keyVal, valVal)
                    }
                    col = 0
                    keyVal = ""
                    valVal = ""
                    rowFields = 0
                    rowAllEmpty = true
                    i = i + 1
                } else if (c == b'\r') {
                    i = i + 1
                } else {
                    field.add(c)
                    i = i + 1
                }
            }
            n = f.read(buf)
        }
    } finally {
        f.close()
    }

    // 收尾: 文件末尾没有换行符时最后一行还没结算
    if (rowFields > 0 || field.size > 0) {
        rowFields = rowFields + 1
        if (field.size > 0) {
            rowAllEmpty = false
        }
        if (!headerReady) {
            hdrCells.add(stripBom(String.fromUtf8(field.toArray())).trimAscii())
        } else if (col == keyIdx) {
            keyVal = String.fromUtf8(field.toArray())
        } else if (col == valIdx) {
            valVal = String.fromUtf8(field.toArray())
        }
        let blank = rowFields == 0 || (rowFields == 1 && rowAllEmpty)
        if (!headerReady) {
            if (!blank) {
                keyIdx = findIn(hdrCells, keyCol)
                if (keyIdx < 0) {
                    throw IllegalArgumentException("column not found: ${keyCol}")
                }
                valIdx = findIn(hdrCells, valCol)
                if (valIdx < 0) {
                    throw IllegalArgumentException("column not found: ${valCol}")
                }
                headerReady = true
            }
        } else if (!blank) {
            rows = rows + 1
            accumulate(keys, index, sums, cnts, mins, maxs, keyVal, valVal)
        }
    }

    if (!headerReady) {
        throw IllegalArgumentException("CSV is empty")
    }

    let out = ArrayList<Float64>()
    var k = 0
    while (k < keys.size) {
        var v = 0.0
        if (how == "sum") {
            v = sums[k]
        } else if (how == "count") {
            v = Float64(cnts[k])
        } else if (how == "min") {
            v = mins[k]
        } else if (how == "max") {
            v = maxs[k]
        } else if (cnts[k] == 0) {
            v = 0.0
        } else {
            v = sums[k] / Float64(cnts[k])
        }
        out.add(v)
        k = k + 1
    }
    return StreamStat(Grouped(keys.toArray(), out.toArray()), rows, total)
}

/** 只要聚合结果时的入口 */
public func streamAgg(path: String, keyCol: String, valCol: String, how: String): Grouped {
    return streamAggStat(path, keyCol, valCol, how).grouped
}

/** 按列名找下标; 不存在时返回 -1 */
func findIn(names: ArrayList<String>, name: String): Int64 {
    var i = 0
    while (i < names.size) {
        if (names[i] == name) {
            return i
        }
        i = i + 1
    }
    return -1
}

/**
 * 把一个键值对并进累加器. 键按首次出现顺序排列, 与 groupAgg 一致,
 * 这样同一份数据走两条路径得到的分类顺序相同.
 */
func accumulate(
    keys: ArrayList<String>,
    index: HashMap<String, Int64>,
    sums: ArrayList<Float64>,
    cnts: ArrayList<Int64>,
    mins: ArrayList<Float64>,
    maxs: ArrayList<Float64>,
    key: String,
    cell: String
): Unit {
    let t = cell.trimAscii()
    var v = 0.0
    if (t.size > 0) {
        try {
            v = Float64.parse(t)
        } catch (e: Exception) {
            v = 0.0
        }
    }

    var slot = -1
    match (index.get(key)) {
        case Some(p) => slot = p
        case None => ()
    }
    if (slot < 0) {
        keys.add(key)
        index.add(key, keys.size - 1)
        sums.add(v)
        cnts.add(1)
        mins.add(v)
        maxs.add(v)
        return
    }

    sums[slot] = sums[slot] + v
    cnts[slot] = cnts[slot] + 1
    if (v < mins[slot]) {
        mins[slot] = v
    }
    if (v > maxs[slot]) {
        maxs[slot] = v
    }
}
