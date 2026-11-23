# ModelProcFS

> Linux `/proc` 虚拟文件系统的 MoonBit 类型化模型

[![CI](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml/badge.svg)](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml)

ModelProcFS 是一个纯 MoonBit 领域建模库，将 Linux `/proc` 文件系统中的进程状态、文件描述符、内存映射等内核数据抽象为强类型、可验证的数据结构，并提供序列化/反序列化、查询过滤、快照差异等取证分析能力。

## 安装

```
moon add lllg123/modelprocfs
```

## 快速开始

```moonbit
fn main {
  // 构建进程树
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1, ppid=0, name="systemd",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1, vm_size_kb=102400, vm_rss_kb=8192,
    ),
  )

  // 序列化为 /proc/[pid]/status 格式
  let p = tree.query(@modelprocfs.ProcessFilter::new())[0]
  let text = @modelprocfs.serialize_status(p)

  // 解析回 Process
  let parsed = @modelprocfs.parse_status(text)
}
```

运行 CLI 演示：

```
moon run cmd/main
```

## 模块概览

| 模块 | 文件 | 功能 |
|------|------|------|
| 核心模型 | `model.mbt` | `Process`（8 种状态）、`ProcessState`、`ProcFSError` |
| 文件描述符 | `fd.mbt` | `FdType`（9 种类型）、`FileDescriptor`、`FdTable` |
| 内存映射 | `memory.mbt` | `MemPerms`、`MemoryRegion`、`MemoryMap` |
| 文件树节点 | `node.mbt` | `ProcEntry`、`ProcNode`（文件/目录/符号链接）|
| 进程树 | `tree.mbt` | `ProcTree`：进程增删、PID 列表、路径解析 |
| 序列化 | `serialize_*.mbt` | `/proc/[pid]/status`、`maps`、`fd` 文本输出 |
| 解析器 | `parser.mbt` | 三种 procfs 格式的反序列化，与序列化器往返 |
| 查询过滤 | `query.mbt` | `ProcessFilter`（8 维 AND 组合）、快捷查找 |
| 快照差异 | `snapshot.mbt` | `ProcFSSnapshot`、`diff_snapshots()`、人类可读摘要 |
| 聚合统计 | `aggregation.mbt` | `SystemStats`：进程/线程/内存/FD 总计 + 状态分布 |

## 示例场景

### 1. 取证分析：检测进程变化

```moonbit
let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
tree.remove_process(7)
let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
let diff = @modelprocfs.diff_snapshots(before, after)
println(diff.summary())
// Snapshot diff: T1 -> T2
//   - pid 7 (removed process)
```

### 2. 过滤查询：按状态和内存筛选

```moonbit
let filter = @modelprocfs.ProcessFilter::new()
  .with_state(@modelprocfs.ProcessState::Running)
  .with_min_rss_kb(10000)
let matches = tree.query(filter)
for p in matches {
  println("\{p.name} (pid=\{p.pid}) RSS=\{p.vm_rss_kb}kB")
}
```

### 3. 聚合统计

```moonbit
let stats = @modelprocfs.compute_stats(tree)
println("Total: \{stats.total_processes} procs, \{stats.total_threads} threads")
println("Sleeping: \{stats.count_for(@modelprocfs.ProcessState::Sleeping)}")
```

## 构建与测试

```bash
# 类型检查（全目标）
moon check --target all --deny-warn

# 运行所有测试（87+ 测试用例）
moon test --target all --deny-warn

# 格式化
moon fmt
```

## 许可证

Copyright 2026 lllg123.

ModelProcFS 按 Apache License 2.0（SPDX：`Apache-2.0`）开源，适用于本仓库的原创代码与文档。项目级许可证全文见根目录 [LICENSE](LICENSE)，与 `moon.mod` 中的许可声明一致。第三方组件仍遵循其各自的许可证。
