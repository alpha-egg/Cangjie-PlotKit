package plotkit.data

import std.collection.*
import std.fs.*

/**
 * CSV 词法解析 (遵循 RFC 4180 的主要规则):
 *   - 逗号分隔, 支持 \n 与 \r\n 换行
 *   - 双引号包裹字段, 字段内可含逗号与换行
 *   - 引号内连续两个 "" 表示一个字面双引号
 * 以字节为单位扫描, UTF-8 多字节字符不受影响.
 */
public func splitCsv(text: String): Array<Array<String>> {
    let rows = ArrayList<Array<String>>()
    var cur = ArrayList<String>()
    var field = ArrayList<UInt8>()
    var inQuotes = false
    var i = 0
    let n = text.size

    while (i < n) {
        let c = text[i]
        if (inQuotes) {
            if (c == b'"') {
                if (i + 1 < n && text[i + 1] == b'"') {
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
        } else {
            if (c == b'"') {
                inQuotes = true
                i = i + 1
            } else if (c == b',') {
                cur.add(String.fromUtf8(field.toArray()))
                field = ArrayList<UInt8>()
                i = i + 1
            } else if (c == b'\n') {
                cur.add(String.fromUtf8(field.toArray()))
                field = ArrayList<UInt8>()
                rows.add(cur.toArray())
                cur = ArrayList<String>()
                i = i + 1
            } else if (c == b'\r') {
                i = i + 1
            } else {
                field.add(c)
                i = i + 1
            }
        }
    }

    // 收尾: 若最后一行没有换行符结尾
    if (field.size > 0 || cur.size > 0) {
        cur.add(String.fromUtf8(field.toArray()))
        rows.add(cur.toArray())
    }
    return rows.toArray()
}

/** 去掉 UTF-8 BOM (Excel 导出的 CSV 常带 BOM) */
func stripBom(s: String): String {
    if (s.size >= 3 && s[0] == 0xEF && s[1] == 0xBB && s[2] == 0xBF) {
        return s[3..s.size]
    }
    return s
}

/** 判断是否为需要跳过的空行 */
func isBlankRow(r: Array<String>): Bool {
    if (r.size == 0) {
        return true
    }
    if (r.size == 1 && r[0].trimAscii().size == 0) {
        return true
    }
    return false
}

/** 从已读入的文本构建 Table: 首行为表头 */
public func parseCsv(text: String): Table {
    let raw = splitCsv(stripBom(text))

    var first = 0
    while (first < raw.size && isBlankRow(raw[first])) {
        first = first + 1
    }
    if (first >= raw.size) {
        throw IllegalArgumentException("CSV is empty")
    }

    var header = raw[first]
    // 表头去空白
    let hdr = ArrayList<String>()
    for (h in header) {
        hdr.add(stripBom(h).trimAscii())
    }

    let table = Table(hdr.toArray())
    var i = first + 1
    while (i < raw.size) {
        if (!isBlankRow(raw[i])) {
            table.addRow(raw[i])
        }
        i = i + 1
    }
    return table
}

/** 读取 CSV 文件 */
public func readCsv(path: String): Table {
    let bytes = File.readFrom(path)
    return parseCsv(String.fromUtf8(bytes))
}
