# ModelProcFS

> Linux `/proc` 虚拟文件系统的 MoonBit 类型化模型

[![CI](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml/badge.svg)](https://github.com/lllg123/modelprocfs/actions/workflows/ci.yml)

ModelProcFS 将 Linux `/proc` 中的进程状态、文件描述符、内存映射抽象为强类型数据结构，提供序列化/反序列化、查询过滤、**基于进程身份的快照差异**和聚合统计能力。核心区分于字段映射的是：**通过 `(pid, start_time_ticks)` 进程身份模型处理 PID 复用**，确保跨时比较的语义正确。

## 安装

```
moon add lllg123/modelprocfs
```

## 快速开始

```moonbit
fn main {
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

  // 解析回 Process（往返不变）
  let parsed = @modelprocfs.parse_status(text)
  assert_eq(parsed.pid, p.pid)
}
```

运行 CLI 演示：

```
moon run cmd/main
```

## 模块概览

| 模块 | 文件 | 功能 |
|------|------|------|
| 核心模型 | `model.mbt` | `Process`（8 种状态）、`ProcessIdentity`、`ProcFSError` |
| 文件描述符 | `fd.mbt` | `FdType`（9 种类型）、`FileDescriptor`、`FdTable` |
| 内存映射 | `memory.mbt` | `MemPerms`、`MemoryRegion`、`MemoryMap` |
| 文件树节点 | `node.mbt` | `ProcEntry`、`ProcNode`（文件/目录/符号链接）|
| 进程树 | `tree.mbt` | `ProcTree`：进程增删、PID 列表、路径解析、查询 |
| 序列化 | `serialize_*.mbt` | `/proc/[pid]/status`、`maps`、`fd` 文本输出 |
| 解析器 | `parser.mbt` | 三种 procfs 格式的反序列化，与序列化器往返 |
| 查询过滤 | `query.mbt` | `ProcessFilter`（8 维 AND 组合）、快捷查找 |
| 快照差异 | `snapshot.mbt` | `ProcFSSnapshot`、身份感知的 `diff_snapshots()` |
| 聚合统计 | `aggregation.mbt` | `SystemStats`：进程/线程/内存/FD 总计 + 状态分布 |

## 核心语义：进程身份与 PID 复用

Linux 内核会回收已退出的 PID。仅靠 PID 比较跨时快照会产生错误结论——例如将 PID 7 的旧进程退出误判为新进程的"状态变更"。

ModelProcFS 通过 `ProcessIdentity = (pid, start_time_ticks)` 解决此问题：

- `start_time_ticks` 来自 `/proc/[pid]/stat` 字段 22（自系统启动以来的时钟滴答数）
- 两个 Process 是**同一内核实例**当且仅当 `pid` 与 `start_time_ticks` 均相等
- `diff_snapshots()` 对 PID 复用的情况标记 `identity_conflict: true`

### 输入/输出案例：PID 复用检测

**输入 — T1 快照：**
```
pid=7, name="worker",  state=Running, start_time_ticks=1500, RSS=16384kB
```

**输入 — T2 快照 (worker 已崩溃，内核将 PID 7 分配给 logger)：**
```
pid=7, name="logger",  state=Sleeping, start_time_ticks=8000, RSS=2048kB
```

**输出 — `diff_snapshots(before, after).summary()`：**
```
Snapshot diff: T1 -> T2
  - pid 7 (process exited) [PID reused by different process]
  + pid 7 (new process) [PID reuse — different start time]
```

### 输入/输出案例：故障检测

**输入 — T1：**
```
pid=42, name="sshd",  state=Sleeping, threads=2, RSS=4096kB
pid=99, name="worker", state=Running, threads=4, RSS=16384kB
```

**输入 — T2（worker 变为僵尸，sshd RSS 增长）：**
```
pid=42, name="sshd",  state=Sleeping, threads=2, RSS=8192kB  ← RSS +4096
pid=99, name="worker", state=Zombie,  threads=1, RSS=0kB     ← 崩溃
```

**输出：**
```
Snapshot diff: T1 -> T2
  ~ pid 42 RSS +4096kB
  ~ pid 99 state R->Z RSS -16384kB threads -3
```

### 输入/输出案例：read/proc/[pid]/status 往返

**输入 (MoonBit 构造)：**
```
Process::new(pid=1, ppid=0, name="systemd", state=Sleeping, threads=1, vm_size_kb=102400, vm_rss_kb=8192)
```

**序列化输出：**
```
Name:	systemd
State:	S (systemd)
Tgid:	1
Pid:	1
PPid:	0
Threads:	1
VmSize:	  102400 kB
VmRSS:	  8192 kB
```

**解析回 Process：**
`parse_status(text)` 返回 `Process{pid=1, name="systemd", state=Sleeping, …}` — 与输入等价。

## 构建与测试

```bash
# 类型检查（全目标）
moon check --target all --deny-warn

# 运行所有测试
moon test --target all --deny-warn

# 格式化
moon fmt
```

## 许可证

Apache-2.0