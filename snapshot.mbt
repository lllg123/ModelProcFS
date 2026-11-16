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
                        let process = Process::new(
                          pid~,
                          ppid=parse_pid_field(status, "PPid"),
                          name~,
                          state=s,
                          threads=parse_int_field(status, "Threads"),
                          vm_size_kb=parse_kb_field(status, "VmSize"),
                          vm_rss_kb=parse_kb_field(status, "VmRSS"),
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
fn find_proc(snapshot : ProcFSSnapshot, pid : Int32) -> Process? {
  for i = 0; i < snapshot.processes.length(); i = i + 1 {
    if snapshot.processes[i].pid == pid {
      return Some(snapshot.processes[i])
    }
  }
  None
}

///|
/// Describes what changed for a single PID between two snapshots.
#derive(Debug, Eq)
pub(all) struct ProcessDiff {
  pid : Int32
  added : Bool
  removed : Bool
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
/// Computes the diff between two snapshots.
///
/// Processes present only in `after` are listed as added; those only in
/// `before` as removed.  For processes present in both, the method
/// compares state, RSS, and thread count.
pub fn diff_snapshots(
  before : ProcFSSnapshot,
  after : ProcFSSnapshot,
) -> SnapshotDiff {
  let diffs = []

  // Added processes (in after but not in before)
  for i = 0; i < after.processes.length(); i = i + 1 {
    let p = after.processes[i]
    match find_proc(before, p.pid) {
      Some(_) => ()
      None =>
        diffs.push({
          pid: p.pid,
          added: true,
          removed: false,
          state_changed: false,
          from_state: None,
          to_state: Some(p.state),
          vm_rss_delta_kb: p.vm_rss_kb,
          thread_delta: p.threads,
        })
    }
  }

  // Removed processes (in before but not in after)
  for i = 0; i < before.processes.length(); i = i + 1 {
    let p = before.processes[i]
    match find_proc(after, p.pid) {
      Some(_) => ()
      None =>
        diffs.push({
          pid: p.pid,
          added: false,
          removed: true,
          state_changed: false,
          from_state: Some(p.state),
          to_state: None,
          vm_rss_delta_kb: -p.vm_rss_kb,
          thread_delta: -p.threads,
        })
    }
  }

  // Changed processes (present in both)
  for i = 0; i < after.processes.length(); i = i + 1 {
    let a = after.processes[i]
    match find_proc(before, a.pid) {
      None => ()
      Some(b) =>
        if a.state != b.state ||
          a.vm_rss_kb != b.vm_rss_kb ||
          a.threads != b.threads {
          diffs.push({
            pid: a.pid,
            added: false,
            removed: false,
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
      "  + pid \{d.pid} (new process)"
    } else if d.removed {
      "  - pid \{d.pid} (removed process)"
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
