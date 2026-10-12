package plotkit

import std.collection.*
import std.fs.*
import std.runtime.*
import plotkit.cli.*
import plotkit.core.*
import plotkit.data.*

/**
 * 基准辅助命令: 生成大 CSV, 以及分别用两条路径跑一次聚合.
 *
 * 这两条命令只为测量服务, 不参与画图流程. 计时与内存由外部脚本
 * (bench/run_bench.py) 在进程外测量, 这里只负责把活干完并把结果印出来,
 * 便于核对两条路径算出的数是否一致.
 */

/** 合成一份与 data/sales.csv 同结构的 CSV, 用于规模化测试 */
func runGen(pos: Array<String>, fl: Flags): Int64 {
    if (pos.size < 2) {
        println("error: 用法 plotkit gen <out.csv> --rows <行数>")
        return 1
    }
    let out = pos[1]
    var rows = fl.getInt("rows", 5000000)
    if (rows < 1) {
        println("error: --rows 必须是正数")
        return 1
    }

    ensureParent(out)
    try {
        remove(out)
    } catch (e: Exception) {
        // 文件不存在
    }

    let months = ["1月", "2月", "3月", "4月", "5月", "6月",
                  "7月", "8月", "9月", "10月", "11月", "12月"]
    let regions = ["华东", "华北", "华南", "西部", "东北", "华中", "西南", "西北"]

    let f = File.create(out)
    let buf = ArrayList<UInt8>()
    appendLine(buf, "month,region,amount,orders\n")

    var state: Int64 = 20261012
    var i = 0
    while (i < rows) {
        state = nextRand(state)
        let month = months[state % 12]
        state = nextRand(state)
        let region = regions[state % 8]
        state = nextRand(state)
        let whole = 100 + state % 9900
        state = nextRand(state)
        let frac = state % 10
        state = nextRand(state)
        let orders = 500 + state % 2000

        appendLine(buf, "${month},${region},${whole}.${frac},${orders}\n")

        if (buf.size >= 1048576) {
            f.write(buf.toArray())
            buf.clear()
        }
        i = i + 1
    }
    f.write(buf.toArray())
    f.close()
    println("generated ${out}  (${rows} rows)")
    return 0
}

/**
 * 跑一次聚合, 供外部脚本计时与测内存.
 *
 * 不加 --stream 走既有的整表加载路径 (readCsv + 取列 + groupAgg),
 * 加 --stream 走流式路径. 两者输出同一行格式, 结果可以直接比对.
 */
func runBench(pos: Array<String>, fl: Flags): Int64 {
    if (fl.flag("meminfo")) {
        return runMemInfo()
    }
    if (pos.size < 2) {
        println("error: 用法 plotkit bench <data.csv> --x <列> --y <列> [--agg sum] [--stream]")
        return 1
    }
    let path = pos[1]
    let xName = fl.get("x", "")
    let yName = fl.get("y", "")
    if (xName.size == 0 || yName.size == 0) {
        println("error: --x and --y are required")
        return 1
    }
    let how = fl.get("agg", "sum")
    if (!isKnownAgg(how)) {
        println("error: unknown --agg '${how}' (mean|sum|count|min|max)")
        return 1
    }
    if (!exists(path)) {
        println("error: cannot read CSV file '${path}'")
        return 1
    }

    var rows = 0
    var groups = 0
    var total = 0.0
    var mode = "table"

    try {
        if (fl.flag("stream")) {
            mode = "stream"
            let st = streamAggStat(path, xName, yName, how)
            rows = st.rows
            groups = st.grouped.len()
            total = sumOf(st.grouped.values)
        } else {
            let t = readCsv(path)
            let g = groupAgg(t.strColumn(xName), t.numColumn(yName), how)
            rows = t.nrows()
            groups = g.len()
            total = sumOf(g.values)
        }
    } catch (e: Exception) {
        println("error: ${e.message}")
        return 1
    }

    println("mode=${mode} rows=${rows} groups=${groups} agg=${how} total=${fmtNum(total, 6)}")
    return 0
}

/** 打印运行时与机器的内存口径, 用于确认堆上限 */
func runMemInfo(): Int64 {
    println("maxHeapSize        = ${getMaxHeapSize()}")
    println("usedHeapSize       = ${getUsedHeapSize()}")
    println("allocatedHeapSize  = ${getAllocatedHeapSize()}")
    println("processorCount     = ${getProcessorCount()}")
    return 0
}

func nextRand(prev: Int64): Int64 {
    return (prev * 1103515245 + 12345) % 2147483648
}

func appendLine(buf: ArrayList<UInt8>, line: String): Unit {
    var i = 0
    while (i < line.size) {
        buf.add(line[i])
        i = i + 1
    }
}
