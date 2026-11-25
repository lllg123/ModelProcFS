///|
/// Invalid /proc data encountered during construction or parsing.
#derive(Debug, Eq)
pub(all) suberror ProcFSError {
  InvalidPid(Int32)
  EmptyProcessName
  InvalidThreadCount(Int32)
  InvalidVmSize(Int32)
  InvalidVmRSS(Int32)
  InvalidFdNumber(Int32)
  FdAlreadyExists(Int32)
  InvalidMemoryRange(Int32, Int32)
  InvalidMemoryPerms(String)
  ProcessNotFound(Int32)
  ProcessAlreadyExists(Int32)
  InvalidProcPath(String)
  ParseError(String)
  IdentityConflict(Int32, Int64, Int64)
}

///|
/// The process state as reported by `/proc/[pid]/status` field `State:`.
#derive(Debug, Eq)
pub(all) enum ProcessState {
  Running // R  — running or runnable
  Sleeping // S  — interruptible sleep
  DiskSleep // D  — uninterruptible disk sleep
  Zombie // Z  — terminated but not reaped
  Stopped // T  — stopped by signal
  TracingStop // t  — stopped by ptrace
  Dead // X  — dead (rare)
  Idle // I  — idle kernel thread
}

///|
/// Uniquely identifies a process instance across its lifetime.
///
/// Linux PID values are recycled by the kernel. Two snapshots that both
/// contain pid=7 may refer to entirely different processes. The kernel
/// exposes `starttime` (clock ticks since boot when the process was created)
/// in `/proc/[pid]/stat` field 22. Together `(pid, start_time_ticks)`
/// forms a stable identity for the lifetime of one `fork`→`exit` cycle.
#derive(Debug, Eq)
pub(all) struct ProcessIdentity {
  pid : Int32
  start_time_ticks : Int64
}

///|
/// Returns the identity key `(pid, start_time_ticks)` for this process.
///
/// When `start_time_ticks` is `None` the identity degrades to `(pid, -1)`
/// — sufficient for single-snapshot use but inadequate for cross-snapshot
/// comparison where PID reuse is possible.
pub fn ProcessIdentity::new(
  pid~ : Int32,
  start_ticks~ : Int64,
) -> ProcessIdentity {
  { pid, start_time_ticks: start_ticks, }
}

///|
/// The core process record modelled from `/proc/[pid]/status`.
///
/// All fields are validated on construction. Pid must be positive, name must
/// be non-empty, and numeric fields must be non-negative.
#derive(Debug, Eq)
pub(all) struct Process {
  pid : Int32
  ppid : Int32
  name : String
  state : ProcessState
  threads : Int32
  vm_size_kb : Int32
  vm_rss_kb : Int32
  start_time_ticks : Int64?
}

///|
pub extend ProcFSError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcFSError with Eq::{not_equal, equal}

///|
pub extend ProcessState with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcessState with Eq::{not_equal, equal}

///|
pub extend ProcessIdentity with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcessIdentity with Eq::{not_equal, equal}

///|
pub extend Process with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Process with Eq::{not_equal, equal}

///|
/// Creates a validated process record.
///
/// `start_time_ticks` is the value from `/proc/[pid]/stat` field 22
/// (clock ticks since boot). When provided, it anchors cross-snapshot
/// identity so that PID reuse is detected correctly.
pub fn Process::new(
  pid~ : Int32,
  ppid~ : Int32,
  name~ : String,
  state~ : ProcessState,
  threads~ : Int32,
  vm_size_kb~ : Int32,
  vm_rss_kb~ : Int32,
  start_time_ticks~ : Int64? = None,
) -> Process raise ProcFSError {
  if pid <= 0 {
    raise ProcFSError::InvalidPid(pid)
  }
  if name == "" {
    raise ProcFSError::EmptyProcessName
  }
  if threads < 0 {
    raise ProcFSError::InvalidThreadCount(threads)
  }
  if vm_size_kb < 0 {
    raise ProcFSError::InvalidVmSize(vm_size_kb)
  }
  if vm_rss_kb < 0 {
    raise ProcFSError::InvalidVmRSS(vm_rss_kb)
  }
  { pid, ppid, name, state, threads, vm_size_kb, vm_rss_kb, start_time_ticks, }
}

///|
/// Returns the `ProcessIdentity` for cross-snapshot matching.
///
/// When `start_time_ticks` is unavailable this falls back to `(pid, -1)`,
/// which the diff engine treats as "identity unavailable — compare by PID
/// only but flag as potentially ambiguous".
pub fn Process::identity(self : Process) -> ProcessIdentity {
  match self.start_time_ticks {
    Some(t) => ProcessIdentity::new(pid=self.pid, start_ticks=t)
    None => ProcessIdentity::new(pid=self.pid, start_ticks=-1L)
  }
}

///|
/// Two processes refer to the *same kernel instance* when both pid and
/// start time match. This is stricter than struct equality (which also
/// compares mutable fields like RSS that change between snapshots).
pub fn ProcessIdentity::same_instance(
  self : ProcessIdentity,
  other : ProcessIdentity,
) -> Bool {
  self.pid == other.pid && self.start_time_ticks == other.start_time_ticks
}

///|
/// Returns a short human-readable label for this process state.
pub fn ProcessState::label(self : ProcessState) -> String {
  match self {
    Running => "R"
    Sleeping => "S"
    DiskSleep => "D"
    Zombie => "Z"
    Stopped => "T"
    TracingStop => "t"
    Dead => "X"
    Idle => "I"
  }
}

///|
/// Parses the single-character state code found in `/proc/[pid]/status`.
pub fn ProcessState::from_code(code : String) -> ProcessState? {
  match code {
    "R" => Some(Running)
    "S" => Some(Sleeping)
    "D" => Some(DiskSleep)
    "Z" => Some(Zombie)
    "T" => Some(Stopped)
    "t" => Some(TracingStop)
    "X" => Some(Dead)
    "I" => Some(Idle)
    _ => None
  }
}
