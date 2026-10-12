#!/usr/bin/env python3
"""plotkit 大规模 CSV 基准: 整表加载 vs 流式聚合.

在进程外测量, 因为这两件事都得从外面看才准:
  - 墙钟: 子进程从启动到退出的总时间;
  - 峰值内存: 轮询系统 API 取进程的 PeakWorkingSetSize. 这是操作系统记录的
    水位线, 读得晚也不会偏低, 因此不需要在热点循环里插桩, 也就不会干扰被测程序.

每条配置跑 REPEATS 次取中位数, 避免单次抖动.

两个阶段:
  ramp   行数从 50 万到 500 万, 两条路径各跑一遍 (默认)
  small  默认堆上限下的小规模爬坡, 用来定位整表加载的内存不足边界
  sweep  固定最大规模, 把运行时堆上限从 32MB 一路放宽到 8GB, 看两条路径各在哪一档失灵

用法:
    python -I bench/run_bench.py                          # ramp, 默认堆上限
    python -I bench/run_bench.py --heap 8gb               # ramp, 放宽堆上限
    python -I bench/run_bench.py --phase small            # 默认堆下的小规模爬坡
    python -I bench/run_bench.py --phase sweep            # 堆上限扫描
    python -I bench/run_bench.py --quick                  # 只跑最小两档

需要先 cjpm build -o plotkit; CSV 不存在时会调用 plotkit gen 生成.
"""

import argparse
import ctypes
import json
import os
import statistics
import subprocess
import sys
import time
from ctypes import wintypes

# ---------- Windows: 读进程峰值工作集 ----------

psapi = ctypes.WinDLL("psapi", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

PROCESS_QUERY_LIMITED_INFORMATION = 0x1000


class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]


def peak_working_set(pid):
    """进程峰值工作集字节数; 取不到时返回 None."""
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return None
    try:
        c = PROCESS_MEMORY_COUNTERS()
        c.cb = ctypes.sizeof(c)
        if not psapi.GetProcessMemoryInfo(h, ctypes.byref(c), c.cb):
            return None
        return int(c.PeakWorkingSetSize)
    finally:
        kernel32.CloseHandle(h)


# ---------- 单次运行 ----------

def run_once(exe, args, heap_env, poll=0.005):
    """跑一次子进程, 返回 (耗时秒, 峰值工作集字节, 退出码, 标准输出)."""
    env = dict(os.environ)
    if heap_env:
        env["cjHeapSize"] = heap_env
    else:
        env.pop("cjHeapSize", None)

    t0 = time.perf_counter()
    p = subprocess.Popen(
        [exe] + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        env=env, text=True, errors="replace",
    )
    peak = 0
    while p.poll() is None:
        ws = peak_working_set(p.pid)
        if ws is not None and ws > peak:
            peak = ws
        time.sleep(poll)
    out = p.stdout.read() if p.stdout else ""
    p.stdout.close()
    return time.perf_counter() - t0, peak, p.returncode, out.strip()


def summarize(runs):
    ok = [r for r in runs if r[2] == 0]
    if not ok:
        return {"ok": False, "peak_mb": max(r[1] for r in runs) / 1048576.0,
                "output": runs[-1][3]}
    return {"ok": True,
            "sec": statistics.median(r[0] for r in ok),
            "peak_mb": statistics.median(r[1] for r in ok) / 1048576.0,
            "output": ok[0][3]}


# ---------- 主流程 ----------

def ensure_csv(exe, path, rows):
    if not os.path.exists(path):
        r = subprocess.run([exe, "gen", path, "--rows", str(rows)],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if r.returncode != 0:
            sys.exit("生成 %s 失败: %s" % (path, r.stdout))
    return os.path.getsize(path)


def measure(exe, csv, size, rows, mode, heap, args, repeats):
    extra = ["--stream"] if mode == "stream" else []
    run_args = ["bench", csv, "--x", args.key, "--y", args.val, "--agg", args.agg] + extra
    runs = [run_once(exe, run_args, heap) for _ in range(repeats)]
    s = summarize(runs)
    rec = {"rows": rows, "csv_mb": round(size / 1048576.0, 1), "mode": mode,
           "heap": heap or "default", "ok": s["ok"]}
    if s["ok"]:
        rec["sec"] = round(s["sec"], 3)
        rec["peak_mb"] = round(s["peak_mb"], 1)
        rec["throughput_mb_s"] = round(size / 1048576.0 / s["sec"], 1)
        rec["result"] = s["output"]
        print("heap=%-8s rows=%-8d %-6s %7.2fs %8.1f MB  %s"
              % (heap or "default", rows, mode, rec["sec"], rec["peak_mb"], s["output"]))
    else:
        rec["peak_mb_at_failure"] = round(s["peak_mb"], 1)
        rec["error"] = s["output"].splitlines()[-1] if s["output"] else ""
        print("heap=%-8s rows=%-8d %-6s FAILED   %8.1f MB  %s"
              % (heap or "default", rows, mode, rec["peak_mb_at_failure"], rec.get("error", "")))
    sys.stdout.flush()
    return rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", default=os.path.join("target", "release", "bin", "plotkit.exe"))
    ap.add_argument("--key", default="month")
    ap.add_argument("--val", default="amount")
    ap.add_argument("--agg", default="sum")
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--heap", default="", help="ramp 阶段的 cjHeapSize, 如 8gb")
    ap.add_argument("--phase", choices=["ramp", "small", "sweep"], default="ramp")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    exe = os.path.abspath(args.exe)
    if not os.path.exists(exe):
        sys.exit("找不到 %s, 先跑 cjpm build -o plotkit" % exe)
    os.makedirs("bench", exist_ok=True)

    records = []
    if args.phase in ("ramp", "small"):
        if args.phase == "small":
            rows_list = [100000, 200000, 300000, 400000, 500000]
            heap = ""          # 小规模爬坡看的就是默认堆上限下的边界
        elif args.quick:
            rows_list, heap = [500000, 1000000], args.heap
        else:
            rows_list, heap = [500000, 1000000, 2000000, 3000000, 4000000,
                               5000000], args.heap
        for rows in rows_list:
            csv = os.path.join("bench", "gen_%d.csv" % rows)
            size = ensure_csv(exe, csv, rows)
            for mode in ("table", "stream"):
                records.append(measure(exe, csv, size, rows, mode, heap, args,
                                       args.repeats))
    else:
        rows = 500000 if args.quick else 5000000
        csv = os.path.join("bench", "gen_%d.csv" % rows)
        size = ensure_csv(exe, csv, rows)
        for heap in ("32mb", "64mb", "128mb", "256mb", "1gb", "8gb"):
            for mode in ("table", "stream"):
                records.append(measure(exe, csv, size, rows, mode, heap, args, args.repeats))

    out = args.out or os.path.join("bench", "result_%s%s.json"
                                   % (args.phase, "_" + args.heap if args.heap else ""))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(records, f, ensure_ascii=False, indent=2)
    print("\n结果写入 %s" % out)


if __name__ == "__main__":
    main()
