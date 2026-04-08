# memhook 研究计划

> 由 autoresearch-init 从 memhook 项目提取 | 2026-04-08

## 研究目标

降低 memhook（C/C++ 内存泄漏检测 LD_PRELOAD 工具）的运行时开销。

**核心指标**：mixed_load ns/op（有 hook），越低越好，目标 < 120 ns/op

## 评估方法

| 步骤 | 命令 | 说明 |
|------|------|------|
| 构建 | `make clean && make` | 编译 memhook.so |
| 评估 | `make autoperf` | 采集性能数据（3 次取中位数） |
| 测试 | `make test` | 全量测试（单元 + 功能 + 多线程） |
| 稳定性 | `bash scripts/stability_test.sh 300` | 5 分钟稳定性（RSS 不超 2x） |

**指标解析**：从 `make autoperf` 输出中提取 `mixed_load` 行的 `ns/op` 字段（有 hook 列）。

历史数据存储在 `docs/perf/results.tsv`。

## 文件规则

| 文件 | 可修改？ | 说明 |
|------|---------|------|
| `memhook.cpp` | ✅ | 唯一优化目标 |
| `test/test_unit.cpp` | ✅ | 可添加回归测试 |
| `test/test_stress_baseline.cpp` | ❌ | 固定评估基准 |
| `scripts/*.sh` | ❌ | 自动化脚本 |
| `Makefile` | ❌ | 构建系统 |

## QA 门禁

每次实验**必须**通过以下检查才能保留：

1. `make test` — 全量测试通过（单元 + 功能 + 多线程）
2. `make autoperf` — 性能数据正常采集
3. `bash scripts/stability_test.sh 300` — 5 分钟稳定性（RSS 不超 2x）
4. mixed_load ns/op 不高于当前最优值（可在噪声范围内波动 ±10%）

## 迭代参数

- **最大迭代次数**：10
- **提前结束条件**：连续 3 次无改善

## 实验记录

| # | 实验 | 结果 | 决策 | mixed_load ns/op |
|---|------|------|------|------------------|
| 1 | TLS AllocEntry 自由链表 | -21.5% | ✅ 保留 | - |
| 2 | 分片锁 256→1024 | 2.0x overhead | ✅ 保留 | - |
| ... | *（完整历史见 docs/perf/results.tsv）* | | | |
| 50 | fast_unwind rbp chain | depth=8 零额外开销 | ✅ 保留 | ~100-115 |

## 待探索方向

*（Agent 根据代码分析和实验结果自主维护此列表）*

1. 无锁哈希表（Lock-Free Ring） — 消除 alloc_table 所有锁
2. 采样统计（1/N 采样率） — 减少统计路径执行频率
3. 预分配内存池（mmap） — 消除 AllocEntry 的 real_malloc
4. per-thread 独立追踪 — 完全消除跨线程同步
5. 条件编译轻量模式 — 只记录计数不存 entry

## 当前最优

- **指标值**：mixed_load ~100-115 ns/op（有 hook），overhead ~0.3-0.4x
- **commit**：49d95e8
