# Cangjie PlotKit

> 纯仓颉实现的轻量数据可视化库与命令行工具：读入 CSV，输出 SVG 图表。

PlotKit 用仓颉标准库从零构建了一条完整的数据→图形流水线：CSV 解析、列式表格、
分组聚合与透视、nice-number 自动刻度、坐标映射、SVG 文档生成、命令行参数解析。
不依赖任何第三方包，只使用 `std`（`std.collection` / `std.fs` / `std.math` /
`std.convert`）。

**为什么是 SVG**：SVG 是纯文本矢量格式，无需字体栅格化、无需位图编码库，
用字符串即可精确控制每一个图元。这使得整套渲染逻辑可以在纯仓颉中自洽地实现，
输出可直接用于网页、文档与打印，无限缩放不失真。

---

## 目录

- [特性](#特性)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [命令行用法](#命令行用法)
- [数据格式](#数据格式)
- [输出示例](#输出示例)
- [作为库使用](#作为库使用)
- [项目结构](#项目结构)
- [设计说明](#设计说明)
- [测试](#测试)
- [已知限制](#已知限制)
- [路线图](#路线图)
- [许可证](#许可证)

---

## 特性

| 能力 | 说明 |
| --- | --- |
| 三种图表 | 柱状图（含分组）、折线图（含多序列）、散点图（含趋势线） |
| CSV 解析 | 支持引号字段、字段内逗号、`""` 转义、CRLF、UTF-8 BOM、空行 |
| 数据聚合 | `mean` / `sum` / `count` / `min` / `max`，按首次出现顺序排列分类 |
| 二维透视 | `--group` / `--series` 把长表直接转成多序列图，无需预处理 |
| 自动刻度 | nice-number 算法（1/2/5×10ⁿ），刻度必定完整覆盖数据范围 |
| 排序 | `--sort asc|desc` 按数值重排分类 |
| 主题 | 内置 light / dark 两套配色，各含 8 色分类色板 |
| 线性拟合 | 散点图叠加最小二乘趋势线，并在终端输出斜率、截距与 R² |
| 零依赖 | 只用仓颉标准库 `std` |

---

## 环境要求

- 仓颉工具链 **1.0.5**（`cjc` / `cjpm`）
- 无需额外依赖

> ⚠️ **构建路径必须是纯 ASCII。** `cjpm` 在包含中文字符的路径下会报
> `Invalid unicode scalar value` 并中断编译。请把仓库克隆到例如
> `D:\cangjie-plotkit` 后再构建。

---

## 快速开始

```bash
git clone https://github.com/alpha-egg/Cangjie-PlotKit.git
cd Cangjie-PlotKit

# 构建，并把可执行文件命名为 plotkit
cjpm build -o plotkit

# 画一张分组柱状图
./target/release/bin/plotkit.exe bar data/sales.csv \
    --x month --y amount --group region --agg sum \
    -o examples/bar_grouped.svg --title "2026 H1 Sales by Region"
```

生成的 `examples/bar_grouped.svg` 可以直接用浏览器打开。

也可以不指定输出名，此时可执行文件叫 `main.exe`：

```bash
cjpm build
cjpm run --run-args "bar data/sales.csv --x month --y amount --agg sum -o out/a.svg"
```

---

## 命令行用法

```
plotkit bar     <data.csv> --x <列> --y <列> [--group <列>] [--agg mean|sum|count|min|max] [--sort asc|desc]
plotkit line    <data.csv> --x <列> --y <列> [--series <列>] [--agg ...] [--sort asc|desc]
plotkit scatter <data.csv> --x <列> --y <列> [--group <列>] [--trend]
plotkit version
```

### 通用选项

| 选项 | 说明 |
| --- | --- |
| `-o`, `--out <文件>` | 输出 SVG 路径，默认 `<命令>.svg`；目录不存在时会自动创建 |
| `--title <文字>` | 图表标题 |
| `--xlabel <文字>` | x 轴标题 |
| `--ylabel <文字>` | y 轴标题，默认取 `--y` 的列名 |
| `--theme light\|dark` | 配色主题，默认 `light` |
| `--width` / `--height` | 画布尺寸，默认 `800x500` |
| `--values` | 在图形上标注数值 |
| `--no-grid` | 关闭网格线 |
| `--no-from-zero` | y 轴不从 0 开始（柱状图 / 折线图） |
| `--from-zero` | 散点图 y 轴从 0 开始（默认贴合数据范围） |
| `--yticks` / `--xticks` | 期望的刻度数量，默认 5 |

选项名忽略连字符与下划线，`--x-label` 与 `--xlabel` 等价；同时支持 `--key=value` 写法。

### 命令专有选项

| 命令 | 选项 | 说明 |
| --- | --- | --- |
| `bar` | `--group <列>` | 按该列并排分组，形成分组柱状图 |
| `bar` | `--agg` | 同一分类下的聚合方式，默认 `mean` |
| `bar` | `--sort asc\|desc` | 按合计值重排分类 |
| `line` | `--series <列>` | 按该列拆成多条折线 |
| `line` | `--agg` `--sort` | 同上 |
| `scatter` | `--group <列>` | 按该列用不同颜色区分点集 |
| `scatter` | `--trend` | 叠加最小二乘趋势虚线，并打印拟合结果 |

### 常见调用

```bash
# 分组柱状图：每月 × 各区域 的销售额合计
plotkit bar data/sales.csv --x month --y amount --group region --agg sum -o out/a.svg

# 单序列柱状图 + 数值标注 + 降序
plotkit bar data/sales.csv --x region --y amount --agg sum --sort desc --values -o out/b.svg

# 多序列折线图
plotkit line data/sales.csv --x month --y amount --series region --agg sum -o out/c.svg

# 散点图 + 趋势线
plotkit scatter data/measure.csv --x height --y weight --trend -o out/d.svg

# 深色主题
plotkit bar data/sales.csv --x region --y amount --agg sum --theme dark -o out/e.svg
```

---

## 数据格式

输入是一个带表头的 CSV，第一行必须是列名。数值列中的非法或空白单元格按 `0` 处理。

```csv
month,region,amount,orders
1月,华东,182.5,1240
1月,华北,143.2,980
2月,华东,165.0,1120
```

- 含逗号或引号的字段用双引号包裹：`"Eve, Jr.",2,95`
- 字段内的双引号用两个双引号表示：`"say ""hi"""`
- 支持 UTF-8 BOM 与 CRLF 换行

仓库自带两份演示数据：

| 文件 | 内容 |
| --- | --- |
| `data/sales.csv` | 6 个月 × 3 个区域的销售额与订单数（18 行） |
| `data/measure.csv` | 15 组身高 / 体重 / 温度 / 气压测量值 |
| `data/students.csv` | 学生姓名 / 班级 / 成绩（含带引号的姓名） |

---

## 输出示例

`examples/` 目录下的 SVG 全部由本工具生成，可直接在浏览器中查看：

| 文件 | 命令要点 |
| --- | --- |
| [bar_grouped.svg](examples/bar_grouped.svg) | 分组柱状图，3 个区域 × 6 个月 |
| [bar_sorted_dark.svg](examples/bar_sorted_dark.svg) | 深色主题 + 降序排序 + 数值标注 |
| [bar_students.svg](examples/bar_students.svg) | 班级平均分 |
| [line_multi.svg](examples/line_multi.svg) | 多序列折线图 |
| [line_single.svg](examples/line_single.svg) | 单序列折线图 |
| [scatter_trend.svg](examples/scatter_trend.svg) | 散点图 + 最小二乘趋势线 |

---

## 作为库使用

PlotKit 同时是一个可被 `import` 的仓颉库，按职责分成四个包：

```
plotkit.core    数值格式化、线性比例尺、nice-number 刻度、最小二乘拟合
plotkit.svg     XML 转义与 SVG 文档构建器
plotkit.data    CSV 解析、列式表、分组聚合、透视
plotkit.chart   主题、图表配置、绘图框架、柱/折/散三类图表
```

```cangjie
package demo

import plotkit.chart.*
import plotkit.data.*

main(): Int64 {
    // 1. 读数据并聚合
    let t = readCsv("data/sales.csv")
    let g = groupAgg(t.strColumn("month"), t.numColumn("amount"), "sum")

    // 2. 配置外观
    let opts = ChartOptions()
    opts.title = "月度销售额"
    opts.yLabel = "万元"
    opts.theme = darkTheme()
    opts.showValues = true

    // 3. 画图并保存
    let frame = barChart(g.keys, g.values, opts)
    frame.save("out/bar.svg")

    // 也可以只拿 SVG 字符串
    println(frame.render())
    return 0
}
```

主要 API：

| 签名 | 作用 |
| --- | --- |
| `readCsv(path)` / `parseCsv(text)` | 读取 / 解析 CSV，返回 `Table` |
| `Table.strColumn(name)` / `.numColumn(name)` | 取字符串列 / 数值列 |
| `groupAgg(keys, values, how)` | 分组聚合，返回 `Grouped` |
| `pivot(xCol, seriesCol, values, how)` | 二维透视，返回 `Pivot` |
| `linearFit(xs, ys)` | 最小二乘拟合，返回 `[slope, intercept, r2]` |
| `niceTicks(lo, hi, target)` | 生成美观刻度 |
| `barChart` / `barChartGrouped` | 柱状图 |
| `lineChart` / `lineChartMulti` | 折线图 |
| `scatterChart` / `scatterChartMulti` | 散点图 |
| `PlotFrame.doc` | 底层 `SvgDoc`，可继续手动添加图元 |

---

## 项目结构

```
cangjie-plotkit/
├── cjpm.toml                  项目配置
├── README.md
├── LICENSE
├── data/                      演示数据集
│   ├── sales.csv
│   ├── measure.csv
│   └── students.csv
├── examples/                  由本工具生成的示例图表 (SVG)
└── src/
    ├── main.cj                命令行入口: 参数解析 -> 取数 -> 画图 -> 落盘
    ├── plotkit_test.cj        单元测试 (23 条)
    ├── cli/
    │   └── args.cj            命令行参数解析
    ├── core/
    │   ├── num.cj             数值格式化、字符串拼接
    │   ├── scale.cj           线性比例尺、nice-number 刻度
    │   └── fit.cj             最小二乘线性拟合
    ├── svg/
    │   └── builder.cj         SVG 文档构建器
    ├── data/
    │   ├── csv.cj             CSV 词法解析
    │   └── table.cj           列式表、统计、分组聚合、透视
    └── chart/
        ├── config.cj          主题、数据序列类型、图表配置
        ├── frame.cj           绘图区框架: 边距、坐标轴、网格、标题、图例
        ├── bar.cj             柱状图
        ├── line.cj            折线图
        └── scatter.cj         散点图
```

---

## 设计说明

**分层与依赖方向。** 依赖是单向的：`cli` / `main` → `chart` → `data` / `svg` → `core`。
`core` 不认识图表，只提供数值与刻度工具；`svg` 不认识业务语义，只提供图元；
`chart` 通过 `PlotFrame` 承担全部布局计算（边距、绘图区、坐标映射、刻度与网格），
各类图表只负责把数据换算成图元写进 `PlotFrame.doc`。新增一种图表只需实现一个
绘图函数，无需改动布局代码。

**整数下标推导刻度。** nice-number 刻度不是靠浮点累加生成的，而是先求出
`floor(min/step)` 与 `ceil(max/step)` 两个整数下标，再逐下标乘回 `step`。
这样既保证刻度完整覆盖数据范围（首尾刻度一定包住极值），也避免
`0.1 + 0.2` 之类的浮点尾数污染坐标文本。

**按字节切分的 XML 转义。** 转义函数只在 ASCII 特殊字符处切开字符串，
其余部分整段拷贝。逐字节拼接会把多字节 UTF-8 字符拆坏，导致运行期
`Invalid utf8 byte sequence`。

**先删后建写文件。** `File.create` 在目标已存在时会抛异常，因此
`SvgDoc.save` 会先 `exists` + `remove` 再创建，保证重复生成同一张图不会失败。

---

## 测试

```bash
cjpm test
```

23 条单元测试覆盖：

- 数值格式化与标签取值
- 线性比例尺映射、nice-number 刻度的覆盖性与等距性
- CSV 解析：引号字段、字段内逗号、`""` 转义、BOM、CRLF、空行
- 分组聚合（五种聚合函数、分类顺序）与透视（缺失组合补 0）
- 最小二乘拟合（精确直线、退化输入）
- 多字节文本的 XML 转义
- 三类图表的端到端渲染断言

---

## 已知限制

- **仅支持数值 y 轴。** x 轴可以是分类或数值，y 轴必须是数值列。
- **散点图按行读取 x/y 两列**，不支持带误差线、气泡大小等扩展编码。
- **图例固定绘制在绘图区右上角**，与 matplotlib 的默认行为一致；
  当最右侧数据很高时可能轻微遮挡。
- **大文件一次性读入内存**，未做流式解析。
- `cjpm` 不支持在非 ASCII 路径下构建（见[环境要求](#环境要求)）。

---

## 路线图

- [ ] 横向柱状图与堆叠柱状图
- [ ] 面积图与带置信区间的折线
- [ ] 直方图（自动分箱）
- [ ] 箱线图
- [ ] 多子图（subplot）布局
- [ ] PNG 输出（需要位图编码与字体栅格化）
- [ ] 直接从 stdin 读取数据

---

## 许可证

[MIT](LICENSE)
