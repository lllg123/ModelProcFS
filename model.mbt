///|
/// Invalid /proc data encountered during construction or parsing.
#derive(Debug, Eq)
pub(all) suberror ProcFSError {
  InvalidPid(Int)
  EmptyProcessName
  InvalidThreadCount(Int)
  InvalidVmSize(Int)
  InvalidVmRSS(Int)
  InvalidFdNumber(Int)
  FdAlreadyExists(Int)
  InvalidMemoryRange(Int, Int)
  InvalidMemoryPerms(String)
}

///|
/// The process state as reported by `/proc/[pid]/status` field `State:`.
#derive(Debug, Eq)
pub(all) enum ProcessState {
  Running      // R  — running or runnable
  Sleeping     // S  — interruptible sleep
  DiskSleep    // D  — uninterruptible disk sleep
  Zombie       // Z  — terminated but not reaped
  Stopped      // T  — stopped by signal
  TracingStop  // t  — stopped by ptrace
  Dead         // X  — dead (rare)
  Idle         // I  — idle kernel thread
}

///|
/// The core process record modelled from `/proc/[pid]/status`.
///
/// All fields are validated on construction. Pid must be positive, name must
/// be non-empty, and numeric fields must be non-negative.
#derive(Debug, Eq)
pub(all) struct Process {
  pid : Int
  ppid : Int
  name : String
  state : ProcessState
  threads : Int
  vm_size_kb : Int
  vm_rss_kb : Int
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
pub extend Process with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Process with Eq::{not_equal, equal}

///|
/// Creates a validated process record.
///
/// Initiates the top-level process with a ppid of 0.
pub fn Process::new(
  pid~ : Int,
  ppid~ : Int,
  name~ : String,
  state~ : ProcessState,
  threads~ : Int,
  vm_size_kb~ : Int,
  vm_rss_kb~ : Int,
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
  { pid, ppid, name, state, threads, vm_size_kb, vm_rss_kb }
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