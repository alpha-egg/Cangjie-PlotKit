# Cangjie PlotKit

用仓颉标准库实现的数据可视化库与命令行工具。读取 CSV，输出 SVG 图表。

只依赖 `std`，不引入任何第三方包。选 SVG 作为输出格式，是因为它是纯文本矢量格式，
不需要位图编码和字体栅格化，整个渲染过程可以用字符串拼装完成，生成的文件可以直接
放进网页或文档，放大不糊。

## 构建

需要仓颉工具链 1.0.5（`cjc` / `cjpm`）。

```bash
git clone https://github.com/alpha-egg/Cangjie-PlotKit.git
cd Cangjie-PlotKit
cjpm build -o plotkit
```

`-o plotkit` 用来指定产物名，不加这个参数可执行文件会叫 `main.exe`。

`cjpm` 无法在包含中文字符的路径下编译，会报 `Invalid unicode scalar value`。
请把仓库克隆到纯 ASCII 路径，例如 `D:\cangjie-plotkit`。

## 命令行

```
plotkit bar     <csv> --x <列> --y <列> [--group <列>] [--agg ...] [--sort ...]
plotkit line    <csv> --x <列> --y <列> [--series <列>] [--agg ...] [--sort ...]
plotkit scatter <csv> --x <列> --y <列> [--group <列>] [--trend]
plotkit version
```

三个命令共用的选项：

- `-o`, `--out <文件>`：输出路径，默认 `<命令>.svg`。上级目录不存在时会自动创建。
- `--title <文字>`：图表标题。
- `--xlabel <文字>`、`--ylabel <文字>`：轴标题。`--ylabel` 默认取 `--y` 指定的列名。
- `--theme light|dark`：配色主题，默认 `light`。
- `--width`、`--height`：画布尺寸，默认 `800x500`。
- `--yticks`、`--xticks`：期望的刻度数量，默认 5。
- `--values`：在图形上标注数值。
- `--no-grid`：关闭网格线。

`bar` 和 `line` 专有：

- `--group <列>` / `--series <列>`：按该列拆成分组柱状图或多条折线。
- `--agg mean|sum|count|min|max`：同一分类下的聚合方式，默认 `mean`。
- `--sort asc|desc`：按各序列合计值重排分类。
- `--no-from-zero`：y 轴不从 0 开始。

`scatter` 专有：

- `--group <列>`：按该列用不同颜色区分点集。
- `--trend`：叠加最小二乘趋势线，并在终端打印斜率、截距和 R²。
- `--from-zero`：y 轴从 0 开始。散点图默认贴合数据范围。

选项名中的连字符和下划线会被忽略，`--x-label` 与 `--xlabel` 等价；同时支持 `--key=value` 写法。

### 例子

```bash
BIN=./target/release/bin/plotkit

# 每个月、每个区域的销售额合计，分组柱状图
$BIN bar data/sales.csv --x month --y amount --group region --agg sum \
     -o out/sales.svg --title "2026 H1 Sales by Region"

# 单序列柱状图，降序排布并标注数值
$BIN bar data/sales.csv --x region --y amount --agg sum --sort desc --values -o out/region.svg

# 三条折线
$BIN line data/sales.csv --x month --y amount --series region --agg sum -o out/trend.svg

# 散点图加趋势线
$BIN scatter data/measure.csv --x height --y weight --trend -o out/hw.svg

# 深色主题
$BIN bar data/sales.csv --x region --y amount --agg sum --theme dark -o out/dark.svg
```

## 作为库使用

代码按职责分成五个包：

- `plotkit.core`：数值格式化、线性比例尺、nice-number 刻度、最小二乘拟合
- `plotkit.svg`：XML 转义与 SVG 文档构建器
- `plotkit.data`：CSV 解析、列式表、分组聚合、二维透视
- `plotkit.chart`：主题、图表配置、绘图框架、柱状图/折线图/散点图
- `plotkit.cli`：命令行参数解析

依赖方向是单向的：`cli` / `main` → `chart` → `data`、`svg` → `core`。`core` 不认识
图表，只提供数值工具；`svg` 不认识业务语义，只提供图元；布局计算集中在 `PlotFrame`，
各类图表只负责把数据换算成图元写进 `PlotFrame.doc`。

```cangjie
package demo

import plotkit.chart.*
import plotkit.data.*

main(): Int64 {
    let t = readCsv("data/sales.csv")
    let g = groupAgg(t.strColumn("month"), t.numColumn("amount"), "sum")

    let opts = ChartOptions()
    opts.title = "月度销售额"
    opts.yLabel = "万元"
    opts.theme = darkTheme()
    opts.showValues = true

    let frame = barChart(g.keys, g.values, opts)
    frame.save("bar.svg")
    // 也可以只取 SVG 字符串，不落盘
    println(frame.render())
    return 0
}
```

常用的入口：

| 函数 | 作用 |
| --- | --- |
| `readCsv(path)` / `parseCsv(text)` | 读取或解析 CSV，返回 `Table` |
| `Table.strColumn(name)` / `.numColumn(name)` | 取字符串列或数值列 |
| `groupAgg(keys, values, how)` | 分组聚合，返回 `Grouped` |
| `pivot(xCol, seriesCol, values, how)` | 二维透视，返回 `Pivot` |
| `linearFit(xs, ys)` | 最小二乘拟合，返回 `[slope, intercept, r2]` |
| `niceTicks(lo, hi, target)` | 生成美观刻度 |
| `barChart` / `barChartGrouped` | 柱状图 |
| `lineChart` / `lineChartMulti` | 折线图 |
| `scatterChart` / `scatterChartMulti` | 散点图 |
| `PlotFrame.doc` | 底层 `SvgDoc`，可以继续手动添加图元 |

## 输入格式

带表头的 CSV，第一行必须是列名。数值列中的空白或无法解析的单元格按 `0` 处理。

```csv
month,region,amount,orders
1月,华东,182.5,1240
1月,华北,143.2,980
2月,华东,165.0,1120
```

解析器支持引号字段和字段内逗号（`"Eve, Jr.",2,95`）、字段内双引号转义
（`"say ""hi"""`）、CRLF 换行、UTF-8 BOM 和空行。

仓库自带三份数据：

- `data/sales.csv`：6 个月 × 3 个区域的销售额与订单数，18 行
- `data/measure.csv`：15 组身高、体重、温度、气压测量值
- `data/students.csv`：学生姓名、班级、成绩，含一个带引号的姓名

## 输出

`examples/` 下的 SVG 全部由本工具生成，直接用浏览器打开即可。

| 文件 | 对应命令 |
| --- | --- |
| `bar_grouped.svg` | 分组柱状图，3 个区域 × 6 个月 |
| `bar_sorted_dark.svg` | 深色主题，降序排序，标注数值 |
| `bar_students.svg` | 班级平均分 |
| `line_multi.svg` | 多序列折线图 |
| `line_single.svg` | 单序列折线图 |
| `scatter_trend.svg` | 散点图与最小二乘趋势线 |

## 目录结构

```
cangjie-plotkit/
├── cjpm.toml
├── data/                      演示数据集
├── examples/                  示例图表
└── src/
    ├── main.cj                命令行入口
    ├── plotkit_test.cj        单元测试
    ├── cli/args.cj
    ├── core/num.cj            数值格式化
    ├── core/scale.cj          比例尺与刻度
    ├── core/fit.cj            线性拟合
    ├── svg/builder.cj         SVG 文档构建器
    ├── data/csv.cj            CSV 解析
    ├── data/table.cj          表格、聚合、透视
    ├── chart/config.cj        主题与配置
    ├── chart/frame.cj         绘图区框架
    ├── chart/bar.cj
    ├── chart/line.cj
    └── chart/scatter.cj
```

## 测试

```bash
cjpm test
```

24 条用例，覆盖：

- 数值格式化与标签取值
- 比例尺映射，刻度的覆盖性与等距性
- CSV 解析：引号字段、字段内逗号、双引号转义、BOM、CRLF、空行
- 分组聚合的五种聚合函数与分类顺序，透视时缺失组合补 0
- 最小二乘拟合，含精确直线和退化输入
- 多字节文本的 XML 转义
- 三类图表的端到端渲染断言
- README 中那段库用法示例本身

## 实现说明

有几处实现细节不太直观，记录在这里。

刻度生成不走浮点累加，而是先算出 `floor(min/step)` 和 `ceil(max/step)` 两个整数下标，
再逐下标乘回 `step`。这样首尾刻度一定包住数据极值，也避免了 `0.1 + 0.2`
这类浮点尾数跑到坐标文本里（`0.30000000000000004` 会显示成 `0.3`）。

XML 转义只在 ASCII 特殊字符处切开字符串，其余部分整段拷贝。逐字节拼接会把多字节
UTF-8 字符拆坏，运行期抛 `Invalid utf8 byte sequence`。

`SvgDoc.save` 先 `remove` 再 `create`。仓颉的 `File.create` 在目标已存在时会抛异常，
不先删掉就没法重复生成同一张图。

散点图的 y 轴默认贴合数据范围而不是从 0 开始，否则点会全部挤在图的上部。

## 已知限制

- y 轴必须是数值列，x 轴可以是分类或数值。
- 图例固定在绘图区右上角，与 matplotlib 的默认行为一致；最右侧数据很高时可能轻微遮挡。
- 整个 CSV 一次性读入内存，没有做流式解析。
- 只支持分组柱状图，没有堆叠柱状图、面积图、直方图、箱线图和多子图。
- 只在 `x86_64-w64-mingw32` 目标上验证过。

## 许可证

[MIT](LICENSE)
