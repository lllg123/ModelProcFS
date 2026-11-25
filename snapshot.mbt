///|
/// A point-in-time capture of a `ProcTree`.
///
/// Stores the list of processes present in the tree along with a
/// human-readable timestamp to anchor forensic comparisons.
#derive(Debug, Eq)
pub(all) struct ProcFSSnapshot {
  captured_at : String
  processes : Array[Process]
}

///|
/// Captures every process currently in the tree.
pub fn ProcFSSnapshot::new(
  captured_at~ : String,
  tree : ProcTree,
) -> ProcFSSnapshot {
  let results = []
  let pids = tree.list_pids()
  for i = 0; i < pids.length(); i = i + 1 {
    let pid = pids[i]
    match tree.get_process_node(pid) {
      None => ()
      Some(node) =>
        match node.find_child("status") {
          None => ()
          Some(status) =>
            match status.lookup("Name") {
              None => ()
              Some(name) =>
                match status.lookup("State") {
                  None => ()
                  Some(state_code) =>
                    match ProcessState::from_code(state_code[:1].to_owned()) {
                      None => ()
                      Some(s) => {
                        let ticks = parse_start_ticks(status)
                        let process = Process::new(
                          pid~,
                          ppid=parse_pid_field(status, "PPid"),
                          name~,
                          state=s,
                          threads=parse_int_field(status, "Threads"),
                          vm_size_kb=parse_kb_field(status, "VmSize"),
                          vm_rss_kb=parse_kb_field(status, "VmRSS"),
                          start_time_ticks=ticks,
                        ) catch {
                          _ => continue
                        }
                        results.push(process)
                      }
                    }
                }
            }
        }
    }
  }
  { captured_at, processes: results, }
}

///|
/// Finds a process by its `ProcessIdentity`, not just PID.
fn find_by_identity(
  snapshot : ProcFSSnapshot,
  identity : ProcessIdentity,
) -> Process? {
  for i = 0; i < snapshot.processes.length(); i = i + 1 {
    if snapshot.processes[i].identity().same_instance(identity) {
      return Some(snapshot.processes[i])
    }
  }
  None
}

///|
/// Finds a process by raw PID (fallback when identity data is absent).
fn find_by_pid(snapshot : ProcFSSnapshot, pid : Int32) -> Process? {
  for i = 0; i < snapshot.processes.length(); i = i + 1 {
    if snapshot.processes[i].pid == pid {
      return Some(snapshot.processes[i])
    }
  }
  None
}

///|
/// Describes what changed for a single process between two snapshots.
///
/// `identity_conflict` is set when the same PID appears with a different
/// start time — the PID was reused between snapshots.
#derive(Debug, Eq)
pub(all) struct ProcessDiff {
  pid : Int32
  identity : ProcessIdentity
  added : Bool
  removed : Bool
  identity_conflict : Bool
  state_changed : Bool
  from_state : ProcessState?
  to_state : ProcessState?
  vm_rss_delta_kb : Int32
  thread_delta : Int32
}

///|
/// A collection of per-process diffs between two snapshots.
#derive(Debug, Eq)
pub(all) struct SnapshotDiff {
  before : String
  after : String
  diffs : Array[ProcessDiff]
}

///|
/// Computes the diff between two snapshots, using `(pid, start_time_ticks)`
/// identity for cross-snapshot matching.
///
/// **Input shape:**
/// Each snapshot contains an array of `Process` records. When
/// `start_time_ticks` is populated, the diff engine matches processes by
/// `(pid, start_time_ticks)`; when absent, it falls back to PID-only with
/// a conflict flag.
///
/// **Output shape:**
/// Returns a `SnapshotDiff` containing one `ProcessDiff` per detected
/// change. Three categories:
/// 1. **added** — identity present in `after` but not in `before`
/// 2. **removed** — identity present in `before` but not in `after`
/// 3. **modified** — same identity, different state/RSS/threads
///
/// When the same PID appears with two different start times across
/// snapshots, both entries carry `identity_conflict: true`.
///
/// **Representative example:**
///
/// Before snapshot T1:
///   pid=7 name="worker" start_ticks=1500 state=S RSS=4096kB
///
/// After snapshot T2 (worker crashed, PID 7 reused by "logger"):
///   pid=7 name="logger" start_ticks=8000 state=R RSS=2048kB
///
/// Result:
///   - pid 7 (worker)  start=1500 → removed
///   + pid 7 (logger)  start=8000 → added
///   ! pid 7 identity conflict: same PID, different start times
pub fn diff_snapshots(
  before : ProcFSSnapshot,
  after : ProcFSSnapshot,
) -> SnapshotDiff {
  let diffs = []

  // --- Added: identity in after but not in before ---
  for i = 0; i < after.processes.length(); i = i + 1 {
    let a = after.processes[i]
    let found = find_by_identity(before, a.identity())
    match found {
      Some(_) => ()
      None => {
        // Check for PID reuse: same PID, different start time
        let pid_collision = find_by_pid(before, a.pid)
        let conflict = match pid_collision {
          Some(b) => !b.identity().same_instance(a.identity())
          None => false
        }
        diffs.push({
          pid: a.pid,
          identity: a.identity(),
          added: true,
          removed: false,
          identity_conflict: conflict,
          state_changed: false,
          from_state: None,
          to_state: Some(a.state),
          vm_rss_delta_kb: a.vm_rss_kb,
          thread_delta: a.threads,
        })
      }
    }
  }

  // --- Removed: identity in before but not in after ---
  for i = 0; i < before.processes.length(); i = i + 1 {
    let b = before.processes[i]
    let found = find_by_identity(after, b.identity())
    match found {
      Some(_) => ()
      None => {
        let pid_collision = find_by_pid(after, b.pid)
        let conflict = match pid_collision {
          Some(a) => !a.identity().same_instance(b.identity())
          None => false
        }
        diffs.push({
          pid: b.pid,
          identity: b.identity(),
          added: false,
          removed: true,
          identity_conflict: conflict,
          state_changed: false,
          from_state: Some(b.state),
          to_state: None,
          vm_rss_delta_kb: -b.vm_rss_kb,
          thread_delta: -b.threads,
        })
      }
    }
  }

  // --- Changed: same identity, different attributes ---
  for i = 0; i < after.processes.length(); i = i + 1 {
    let a = after.processes[i]
    match find_by_identity(before, a.identity()) {
      None => ()
      Some(b) =>
        if a.state != b.state ||
          a.vm_rss_kb != b.vm_rss_kb ||
          a.threads != b.threads {
          diffs.push({
            pid: a.pid,
            identity: a.identity(),
            added: false,
            removed: false,
            identity_conflict: false,
            state_changed: a.state != b.state,
            from_state: Some(b.state),
            to_state: Some(a.state),
            vm_rss_delta_kb: a.vm_rss_kb - b.vm_rss_kb,
            thread_delta: a.threads - b.threads,
          })
        } else {
          ()
        }
    }
  }

  { before: before.captured_at, after: after.captured_at, diffs, }
}

///|
/// Returns a stable, human-readable multi-line summary.
pub fn SnapshotDiff::summary(self : SnapshotDiff) -> String {
  let lines = []
  lines.push("Snapshot diff: \{self.before} -> \{self.after}")
  if self.diffs.length() == 0 {
    return "Snapshot diff: \{self.before} -> \{self.after}\n  no changes"
  }
  for i = 0; i < self.diffs.length(); i = i + 1 {
    let d = self.diffs[i]
    let line = if d.added {
      let extra = if d.identity_conflict {
        " [PID reuse — different start time]"
      } else {
        ""
      }
      "  + pid \{d.pid} (new process)\{extra}"
    } else if d.removed {
      let extra = if d.identity_conflict {
        " [PID reused by different process]"
      } else {
        ""
      }
      "  - pid \{d.pid} (process exited)\{extra}"
    } else {
      let parts = []
      parts.push("  ~ pid \{d.pid}")
      if d.state_changed {
        parts.push(
          " state \{d.from_state.unwrap().label()}->\{d.to_state.unwrap().label()}",
        )
      }
      if d.vm_rss_delta_kb != 0 {
        let sign = if d.vm_rss_delta_kb > 0 { "+" } else { "" }
        parts.push(" RSS \{sign}\{d.vm_rss_delta_kb}kB")
      }
      if d.thread_delta != 0 {
        let sign = if d.thread_delta > 0 { "+" } else { "" }
        parts.push(" threads \{sign}\{d.thread_delta}")
      }
      let mut result = ""
      for j = 0; j < parts.length(); j = j + 1 {
        result = result + parts[j]
      }
      result
    }
    lines.push(line)
  }
  let mut result = ""
  for i = 0; i < lines.length(); i = i + 1 {
    result = result + lines[i]
    if i < lines.length() - 1 {
      result = result + "\n"
    }
  }
  result
}

///|
fn parse_start_ticks(status : ProcNode) -> Int64? {
  match status.lookup("StartTime") {
    Some(v) =>
      @string.parse_int(v) catch {
        _ =>
          match status.lookup("starttime") {
            Some(v2) => @string.parse_int(v2) catch { _ => None }
            None => None
          }
      }
    None => None
  }
}

///|
pub extend ProcFSSnapshot with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcFSSnapshot with Eq::{not_equal, equal}

///|
pub extend ProcessDiff with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcessDiff with Eq::{not_equal, equal}

///|
pub extend SnapshotDiff with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SnapshotDiff with Eq::{not_equal, equal}
