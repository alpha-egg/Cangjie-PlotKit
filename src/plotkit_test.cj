package plotkit

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*
import plotkit.chart.*
import plotkit.core.*
import plotkit.data.*
import plotkit.svg.*

// ---------- 数值格式化 ----------

@Test
func testFmtNumDropsTrailingZeros(): Unit {
    @Expect(fmtNum(480.0, 2) == "480")
    @Expect(fmtNum(88.5, 2) == "88.5")
    @Expect(fmtNum(0.5, 2) == "0.5")
}

@Test
func testLabelScaleByMagnitude(): Unit {
    @Expect(label(1234.0) == "1234")
    @Expect(label(88.55) == "88.6" || label(88.55) == "88.5")
    @Expect(label(0.1234) == "0.12")
}

@Test
func testCoordRoundsToTwoDigits(): Unit {
    @Expect(coord(10.0 / 3.0) == "3.33")
}

@Test
func testJoinStrings(): Unit {
    @Expect(joinStrings(["a", "b", "c"], "-") == "a-b-c")
    @Expect(joinStrings(Array<String>(), ",") == "")
}

// ---------- 比例尺与刻度 ----------

@Test
func testLinearScaleMapsDomainToRange(): Unit {
    let s = LinearScale(0.0, 100.0, 200.0, 0.0)
    @Expect(abs(s.map(0.0) - 200.0) < 1e-9)
    @Expect(abs(s.map(100.0) - 0.0) < 1e-9)
    @Expect(abs(s.map(50.0) - 100.0) < 1e-9)
}

@Test
func testNiceTicksCoversData(): Unit {
    let t = niceTicks(0.0, 283.0, 5)
    @Expect(t.size >= 2)
    @Expect(t[0] == 0.0)
    @Expect(t[t.size - 1] >= 283.0)
    // 刻度等距
    let step = t[1] - t[0]
    var i = 1
    while (i + 1 < t.size) {
        @Expect(abs((t[i + 1] - t[i]) - step) < 1e-9)
        i = i + 1
    }
}

@Test
func testNiceTicksHandlesDegenerateRange(): Unit {
    let t = niceTicks(5.0, 5.0, 5)
    @Expect(t.size >= 2)
    @Expect(t[t.size - 1] > t[0])
}

// ---------- CSV ----------

@Test
func testParseCsvBasic(): Unit {
    let t = parseCsv("a,b\n1,2\n3,4\n")
    @Expect(t.ncols() == 2)
    @Expect(t.nrows() == 2)
    @Expect(t.strColumn("a")[1] == "3")
    @Expect(t.numColumn("b")[0] == 2.0)
}

@Test
func testParseCsvQuotedFieldWithComma(): Unit {
    let t = parseCsv("name,score\n\"Eve, Jr.\",95\n")
    @Expect(t.nrows() == 1)
    @Expect(t.strColumn("name")[0] == "Eve, Jr.")
}

@Test
func testParseCsvEscapedQuote(): Unit {
    let t = parseCsv("k\n\"say \"\"hi\"\"\"\n")
    @Expect(t.strColumn("k")[0] == "say \"hi\"")
}

@Test
func testParseCsvStripsBomAndBlankLines(): Unit {
    let t = parseCsv("\u{FEFF}x,y\n1,2\n\n\n3,4\n")
    @Expect(t.ncols() == 2)
    @Expect(t.nrows() == 2)
    @Expect(t.hasColumn("x"))
}

@Test
func testParseCsvHandlesCrlf(): Unit {
    let t = parseCsv("a,b\r\n1,2\r\n")
    @Expect(t.strColumn("b")[0] == "2")
}

// ---------- 聚合与透视 ----------

@Test
func testGroupAggKeepsFirstSeenOrder(): Unit {
    let g = groupAgg(["b", "a", "b", "a"], [1.0, 2.0, 3.0, 4.0], "mean")
    @Expect(g.len() == 2)
    @Expect(g.keys[0] == "b")
    @Expect(g.values[0] == 2.0)
    @Expect(g.keys[1] == "a")
    @Expect(g.values[1] == 3.0)
}

@Test
func testGroupAggAllAggregators(): Unit {
    let k = ["x", "x", "x"]
    let v = [1.0, 2.0, 6.0]
    @Expect(aggOf(v, "sum") == 9.0)
    @Expect(aggOf(v, "min") == 1.0)
    @Expect(aggOf(v, "max") == 6.0)
    @Expect(aggOf(v, "count") == 3.0)
    @Expect(aggOf(v, "mean") == 3.0)
    @Expect(groupAgg(k, v, "max").values[0] == 6.0)
}

@Test
func testPivotBuildsMatrixWithZerosForMissingCells(): Unit {
    let p = pivot(["m1", "m1", "m2"], ["a", "b", "a"], [1.0, 2.0, 3.0], "sum")
    @Expect(p.ncategories() == 2)
    @Expect(p.nseries() == 2)
    @Expect(p.names[0] == "a")
    @Expect(p.names[1] == "b")
    @Expect(p.row(0)[0] == 1.0)
    @Expect(p.row(0)[1] == 3.0)
    // b 在 m2 上没有数据, 补 0
    @Expect(p.row(1)[1] == 0.0)
}

// ---------- 线性拟合 ----------

@Test
func testLinearFitRecoversExactLine(): Unit {
    let fit = linearFit([1.0, 2.0, 3.0, 4.0], [3.0, 5.0, 7.0, 9.0])
    @Expect(abs(fit[0] - 2.0) < 1e-9)
    @Expect(abs(fit[1] - 1.0) < 1e-9)
    @Expect(abs(fit[2] - 1.0) < 1e-9)
}

@Test
func testLinearFitDegenerateInput(): Unit {
    let fit = linearFit([1.0], [7.0])
    @Expect(fit[0] == 0.0)
    @Expect(fit[1] == 7.0)
}

// ---------- SVG 构造 ----------

@Test
func testEscapeXmlPreservesMultibyteText(): Unit {
    @Expect(escapeXml("华东<A>&\"B\"") == "华东&lt;A&gt;&amp;&quot;B&quot;")
}

@Test
func testSvgDocRendersWellFormedDocument(): Unit {
    let d = SvgDoc(100.0, 50.0, "#ffffff")
    d.rect(0.0, 0.0, 10.0, 10.0, "#000000", "", 0.0)
    d.text(5.0, 5.0, "中文", "middle", 12.0, "#111111", 0.0)
    let s = d.render()
    @Expect(s[0..5] == "<svg ")
    @Expect(s[s.size - 6..s.size] == "</svg>")
    @Expect(s.indexOf("中文") != None)
}

// ---------- 图表端到端 ----------

@Test
func testBarChartEmitsOneRectPerBar(): Unit {
    let o = ChartOptions()
    o.showGrid = false
    o.title = ""
    let f = barChartGrouped(["a", "b"], [Series("", [1.0, 2.0])], o)
    let s = f.render()
    @Expect(s.indexOf("<polyline") == None)
    @Expect(countOf(s, "<rect") >= 3) // 背景 + 绘图区 + 2 根柱子
}

@Test
func testLineChartEmitsPolyline(): Unit {
    let o = ChartOptions()
    let f = lineChart(["a", "b", "c"], [1.0, 3.0, 2.0], o)
    @Expect(f.render().indexOf("<polyline") != None)
}

@Test
func testScatterChartNumericAxisDoesNotDrawCategoryLabels(): Unit {
    let o = ChartOptions()
    let f = scatterChart([1.0, 2.0, 3.0], [10.0, 20.0, 30.0], o)
    let s = f.render()
    // 数值轴上不应出现分类轴特有的居中标签渲染
    @Expect(s.indexOf("<circle") != None)
    @Expect(f.numericX)
}

@Test
func testScatterWithTrendAddsDashedLine(): Unit {
    let o = ChartOptions()
    o.showTrend = true
    let s = scatterChart([1.0, 2.0, 3.0, 4.0], [2.0, 4.0, 6.0, 8.0], o).render()
    @Expect(s.indexOf("stroke-dasharray") != None)
}

// ---------- 工具 ----------

func countOf(s: String, sub: String): Int64 {
    var n = 0
    var from = 0
    while (from < s.size) {
        match (s.indexOf(sub, from)) {
            case Some(p) =>
                n = n + 1
                from = p + sub.size
            case None => break
        }
    }
    return n
}

func abs(x: Float64): Float64 {
    if (x < 0.0) {
        return -x
    }
    return x
}
