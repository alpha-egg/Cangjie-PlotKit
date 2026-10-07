package plotkit.cli

import std.collection.*
import std.convert.*

/**
 * 极简命令行参数解析.
 *
 * 支持 `--key value`、`--key=value`、`-o value` 与布尔开关 `--flag`.
 * 键名会忽略连字符与下划线, 因此 `--x-label` 与 `--xlabel` 等价.
 */
public class Flags {
    private let keys: ArrayList<String>
    private let vals: ArrayList<String>
    private let rest: ArrayList<String>

    public init(argv: Array<String>) {
        this.keys = ArrayList<String>()
        this.vals = ArrayList<String>()
        this.rest = ArrayList<String>()

        var i = 0
        while (i < argv.size) {
            let tok = argv[i]
            if (isFlag(tok)) {
                var body = tok
                // 去掉前导的 '-' 或 '--'
                while (body.size > 0 && body[0] == b'-') {
                    body = body[1..body.size]
                }
                // 支持 --key=value
                match (body.indexOf("=")) {
                    case Some(eq) =>
                        let k = body[0..eq]
                        let v = body[(eq + 1)..body.size]
                        this.put(k, v)
                        i = i + 1
                    case None =>
                        if (i + 1 < argv.size && !isFlag(argv[i + 1])) {
                            this.put(body, argv[i + 1])
                            i = i + 2
                        } else {
                            this.put(body, "true")
                            i = i + 1
                        }
                }
            } else {
                this.rest.add(tok)
                i = i + 1
            }
        }
    }

    private func put(k: String, v: String): Unit {
        this.keys.add(normalize(k))
        this.vals.add(v)
    }

    /** 位置参数 (不含选项) */
    public func positional(): Array<String> {
        return this.rest.toArray()
    }

    public func has(name: String): Bool {
        let n = normalize(name)
        var i = 0
        while (i < this.keys.size) {
            if (this.keys[i] == n) {
                return true
            }
            i = i + 1
        }
        return false
    }

    public func get(name: String, fallback: String): String {
        let n = normalize(name)
        var i = 0
        while (i < this.keys.size) {
            if (this.keys[i] == n) {
                return this.vals[i]
            }
            i = i + 1
        }
        return fallback
    }

    public func getInt(name: String, fallback: Int64): Int64 {
        if (!this.has(name)) {
            return fallback
        }
        let raw = this.get(name, "")
        if (raw.size == 0) {
            return fallback
        }
        return Int64.parse(raw)
    }

    public func getFloat(name: String, fallback: Float64): Float64 {
        if (!this.has(name)) {
            return fallback
        }
        let raw = this.get(name, "")
        if (raw.size == 0) {
            return fallback
        }
        return Float64.parse(raw)
    }

    /** 布尔开关: 出现即为 true, 也接受 --flag=false 形式 */
    public func flag(name: String): Bool {
        if (!this.has(name)) {
            return false
        }
        let v = this.get(name, "true")
        return v != "false" && v != "0" && v != "no"
    }
}

private func isFlag(tok: String): Bool {
    return tok.size >= 2 && tok[0] == b'-'
}

/** 去掉键名中的 '-' 与 '_', 使两种写法等价 */
private func normalize(s: String): String {
    var out = ""
    var i = 0
    while (i < s.size) {
        let c = s[i]
        if (c != b'-' && c != b'_') {
            out = out + s[i..(i + 1)]
        }
        i = i + 1
    }
    return out
}
