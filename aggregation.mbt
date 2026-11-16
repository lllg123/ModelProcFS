///|
/// Per-state counter used inside aggregate statistics.
#derive(Debug, Eq)
pub(all) struct StateCount {
  state : ProcessState
  count : Int32
}

///|
/// Aggregate statistics computed from a `ProcTree`.
#derive(Debug, Eq)
pub(all) struct SystemStats {
  total_processes : Int32
  total_threads : Int32
  total_vm_kb : Int32
  total_rss_kb : Int32
  total_fds : Int32
  state_counts : Array[StateCount]
}

///|
/// Increments the counter for `st`, appending a new entry when absent.
fn inc_state(counts : Array[StateCount], st : ProcessState) -> Unit {
  let mut found = false
  for i = 0; i < counts.length(); i = i + 1 {
    if counts[i].state == st {
      counts[i] = { state: st, count: counts[i].count + 1, }
      found = true
    }
  }
  if !found {
    counts.push({ state: st, count: 1, })
  }
}

///|
/// Looks up the count for a given state.
pub fn SystemStats::count_for(self : SystemStats, st : ProcessState) -> Int32 {
  for i = 0; i < self.state_counts.length(); i = i + 1 {
    if self.state_counts[i].state == st {
      return self.state_counts[i].count
    }
  }
  0
}

///|
/// Computes aggregate statistics from every process in the tree.
///
/// Processes are reconstructed from their `/proc/<pid>/status` nodes.
/// Missing or malformed processes are silently skipped.
pub fn compute_stats(tree : ProcTree, fd_tables~ : Map[Int32, FdTable]? = None) -> SystemStats {
  let pids = tree.list_pids()
  let mut total = 0
  let mut total_threads = 0
  let mut total_vm_kb = 0
  let mut total_rss_kb = 0
  let mut total_fds = 0
  let counts = []
  for i = 0; i < pids.length(); i = i + 1 {
    let pid = pids[i]
    match tree.get_process_node(pid) {
      None => ()
      Some(node) => match node.find_child("status") {
        None => ()
        Some(status) => match status.lookup("Pid") {
          None => ()
          Some(_) => match status.lookup("State") {
            None => ()
            Some(sc) => match ProcessState::from_code(sc[:1].to_owned()) {
              None => ()
              Some(st) => {
                total = total + 1
                let tc = parse_int_field(status, "Threads")
                total_threads = total_threads + tc
                let vs = parse_kb_field(status, "VmSize")
                total_vm_kb = total_vm_kb + vs
                let rs = parse_kb_field(status, "VmRSS")
                total_rss_kb = total_rss_kb + rs
                inc_state(counts, st)
              }
            }
          }
        }
      }
    }
    match fd_tables {
      None => ()
      Some(tables) => match tables.get(pid) {
        None => ()
        Some(t) => total_fds = total_fds + t.entries.length()
      }
    }
  }
  {
    total_processes: total,
    total_threads,
    total_vm_kb,
    total_rss_kb,
    total_fds,
    state_counts: counts,
  }
}

///|
pub extend StateCount with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend StateCount with Eq::{not_equal, equal}

///|
pub extend SystemStats with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SystemStats with Eq::{not_equal, equal}