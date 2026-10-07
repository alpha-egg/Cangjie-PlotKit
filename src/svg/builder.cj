package plotkit.svg

import std.collection.*
import std.fs.*
import plotkit.core.*

/**
 * XML 文本转义: 防止标签/属性中的特殊字符破坏文档结构.
 *
 * 只在 ASCII 特殊字符处切分, 其余部分整段拷贝,
 * 这样多字节 UTF-8 字符不会被拆坏.
 */
public func escapeXml(s: String): String {
    var out = ""
    var start = 0
    var i = 0
    while (i < s.size) {
        let c = s[i]
        var rep = ""
        if (c == b'&') {
            rep = "&amp;"
        } else if (c == b'<') {
            rep = "&lt;"
        } else if (c == b'>') {
            rep = "&gt;"
        } else if (c == b'"') {
            rep = "&quot;"
        } else if (c == b'\'') {
            rep = "&apos;"
        }
        if (rep.size > 0) {
            if (start < i) {
                out = out + s[start..i]
            }
            out = out + rep
            start = i + 1
        }
        i = i + 1
    }
    if (start < s.size) {
        out = out + s[start..s.size]
    }
    return out
}

/**
 * SVG 文档构建器. 所有绘制方法返回自身, 支持链式调用.
 */
public class SvgDoc {
    private let parts: ArrayList<String>
    public let width: Float64
    public let height: Float64

    public init(width: Float64, height: Float64, background: String) {
        this.width = width
        this.height = height
        this.parts = ArrayList<String>()
        if (background.size > 0) {
            this.parts.add("<rect width=\"${coord(width)}\" height=\"${coord(height)}\" fill=\"${background}\"/>")
        }
    }

    public func addRaw(s: String): SvgDoc {
        this.parts.add(s)
        return this
    }

    public func rect(x: Float64, y: Float64, w: Float64, h: Float64, fill: String, stroke: String, strokeWidth: Float64): SvgDoc {
        var s = "<rect x=\"${coord(x)}\" y=\"${coord(y)}\" width=\"${coord(w)}\" height=\"${coord(h)}\""
        if (fill.size > 0) {
            s = s + " fill=\"${fill}\""
        } else {
            s = s + " fill=\"none\""
        }
        if (stroke.size > 0) {
            s = s + " stroke=\"${stroke}\" stroke-width=\"${coord(strokeWidth)}\""
        }
        this.parts.add(s + "/>")
        return this
    }

    public func line(x1: Float64, y1: Float64, x2: Float64, y2: Float64, stroke: String, strokeWidth: Float64): SvgDoc {
        let s = "<line x1=\"${coord(x1)}\" y1=\"${coord(y1)}\" x2=\"${coord(x2)}\" y2=\"${coord(y2)}\" stroke=\"${stroke}\" stroke-width=\"${coord(strokeWidth)}\"/>"
        this.parts.add(s)
        return this
    }

    public func dashedLine(x1: Float64, y1: Float64, x2: Float64, y2: Float64, stroke: String, strokeWidth: Float64, dash: String): SvgDoc {
        let s = "<line x1=\"${coord(x1)}\" y1=\"${coord(y1)}\" x2=\"${coord(x2)}\" y2=\"${coord(y2)}\" stroke=\"${stroke}\" stroke-width=\"${coord(strokeWidth)}\" stroke-dasharray=\"${dash}\"/>"
        this.parts.add(s)
        return this
    }

    public func circle(cx: Float64, cy: Float64, r: Float64, fill: String, stroke: String, strokeWidth: Float64, opacity: Float64): SvgDoc {
        var s = "<circle cx=\"${coord(cx)}\" cy=\"${coord(cy)}\" r=\"${coord(r)}\""
        if (fill.size > 0) {
            s = s + " fill=\"${fill}\" fill-opacity=\"${coord(opacity)}\""
        } else {
            s = s + " fill=\"none\""
        }
        if (stroke.size > 0) {
            s = s + " stroke=\"${stroke}\" stroke-width=\"${coord(strokeWidth)}\""
        }
        this.parts.add(s + "/>")
        return this
    }

    /** points 为扁平数组 [x1, y1, x2, y2, ...] */
    public func polyline(points: Array<Float64>, stroke: String, strokeWidth: Float64): SvgDoc {
        if (points.size < 4) {
            return this
        }
        var pl = ""
        var i = 0
        while (i + 1 < points.size) {
            if (i > 0) {
                pl = pl + " "
            }
            pl = pl + "${coord(points[i])},${coord(points[i + 1])}"
            i = i + 2
        }
        this.parts.add("<polyline points=\"${pl}\" fill=\"none\" stroke=\"${stroke}\" stroke-width=\"${coord(strokeWidth)}\"/>")
        return this
    }

    public func text(x: Float64, y: Float64, content: String, anchor: String, fontSize: Float64, fill: String, rotate: Float64): SvgDoc {
        var s = "<text x=\"${coord(x)}\" y=\"${coord(y)}\" text-anchor=\"${anchor}\" font-size=\"${coord(fontSize)}\" fill=\"${fill}\""
        s = s + " font-family=\"sans-serif\""
        if (rotate != 0.0) {
            s = s + " transform=\"rotate(${coord(rotate)} ${coord(x)} ${coord(y)})\""
        }
        s = s + ">${escapeXml(content)}</text>"
        this.parts.add(s)
        return this
    }

    public func render(): String {
        var s = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${coord(this.width)}\" height=\"${coord(this.height)}\" viewBox=\"0 0 ${coord(this.width)} ${coord(this.height)}\">"
        for (p in this.parts) {
            s = s + p
        }
        return s + "</svg>"
    }

    public func save(path: String): Unit {
        // File.create 在目标文件已存在时会抛异常, 因此先删除
        if (exists(path)) {
            remove(path)
        }
        let f = File.create(path)
        f.write(this.render().toArray())
        f.close()
    }
}
