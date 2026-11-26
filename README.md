# ModelProcFS

> Linux `/proc` 进程快照的因果推理引擎 — MoonBit 实现

[![CI](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml/badge.svg)](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml)

ModelProcFS 的核心区分点是**因果回溯引擎**：从两个跨时 `/proc` 快照中，通过进程家族拓扑（ppid→children）、身份匹配（pid+start_ticks）和状态机规则，**自动推导级联故障链**——区分"根因进程"与"被累及的孤立子进程"。

## 因果回溯示例

```
T1: init(R) ─fork→ worker(R) ─fork→ helper(R)
T2: init(R) ─fork→ worker(Z) ─fork→ helper(Z)   ← 两个 Zombie，谁是根因？
```

简单 diff 输出两个独立事件。`backtrack()` 执行多步推理：

1. 构建 ppid→children 家族树
2. 自底向上：helper→查父进程 worker 是否也失败→是→继续→worker→查 init→init 健康→**停止**
3. 结论：**worker 是根因，helper 是级联受害者**

```moonbit
let report = @modelprocfs.backtrack(t1_snapshot, t2_snapshot)
println(report.narrative())
// ROOT CAUSE: pid 99 (worker) R→Z
//   ↳ CASCADE: pid 100 (helper) R→Z [orphaned]
```

## 安装与快速开始

```
moon add lllg123/modelprocfs
moon run cmd/main
```

## 模块

| 模块 | 功能 |
|------|------|
| `model.mbt` | `Process`（8 状态）、`ProcessIdentity(pid, start_ticks)` |
| `fd.mbt` / `memory.mbt` | `FdType`（9 种）、`FileDescriptor`、`MemPerms`、`MemoryMap` |
| `node.mbt` / `tree.mbt` | ProcFS 文件树、进程增删/路径解析 |
| `serialize_*.mbt` / `parser.mbt` | /proc 文本格式双向转换 |
| `query.mbt` / `snapshot.mbt` | 过滤器、身份感知 diff |
| **`forensics.mbt`** | **因果回溯：ppid 拓扑推导级联故障链** |
| `detect.mbt` | 状态机违规、单调泄漏、僵尸超时 |
| `aggregation.mbt` | `SystemStats` 聚合 |

## 许可证

Apache-2.0