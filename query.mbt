///|
/// Optional criteria for filtering processes in a `ProcTree`.
///
/// Every optional field is `None` by default (ignored).  When multiple
/// fields are set they are combined with logical AND.
#derive(Debug, Eq)
pub(all) struct ProcessFilter {
  name_contains : String?
  state : ProcessState?
  min_rss_kb : Int32?
  max_rss_kb : Int32?
  min_threads : Int32?
  max_threads : Int32?
  min_fds : Int32?
  has_fd_type : FdType?
}

///|
/// Creates an empty filter that matches every process.
pub fn ProcessFilter::new() -> ProcessFilter {
  {
    name_contains: None,
    state: None,
    min_rss_kb: None,
    max_rss_kb: None,
    min_threads: None,
    max_threads: None,
    min_fds: None,
    has_fd_type: None,
  }
}

///|
/// Sets the substring to match against `process.name`.
pub fn ProcessFilter::with_name_contains(
  self : ProcessFilter,
  sub : String,
) -> ProcessFilter {
  { ..self, name_contains: Some(sub), }
}

///|
/// Restricts to processes in the given state.
pub fn ProcessFilter::with_state(
  self : ProcessFilter,
  st : ProcessState,
) -> ProcessFilter {
  { ..self, state: Some(st), }
}

///|
/// Sets a minimum RSS threshold (inclusive).
pub fn ProcessFilter::with_min_rss_kb(
  self : ProcessFilter,
  kb : Int32,
) -> ProcessFilter {
  { ..self, min_rss_kb: Some(kb), }
}

///|
/// Sets a maximum RSS threshold (inclusive).
pub fn ProcessFilter::with_max_rss_kb(
  self : ProcessFilter,
  kb : Int32,
) -> ProcessFilter {
  { ..self, max_rss_kb: Some(kb), }
}

///|
/// Sets a minimum thread-count threshold (inclusive).
pub fn ProcessFilter::with_min_threads(
  self : ProcessFilter,
  n : Int32,
) -> ProcessFilter {
  { ..self, min_threads: Some(n), }
}

///|
/// Sets a maximum thread-count threshold (inclusive).
pub fn ProcessFilter::with_max_threads(
  self : ProcessFilter,
  n : Int32,
) -> ProcessFilter {
  { ..self, max_threads: Some(n), }
}

///|
/// Sets a minimum number of open file descriptors (inclusive).
///
/// Only effective when the `ProcTree` is populated with fd-table data.
pub fn ProcessFilter::with_min_fds(
  self : ProcessFilter,
  n : Int32,
) -> ProcessFilter {
  { ..self, min_fds: Some(n), }
}

///|
/// Requires that at least one fd of the given kind be open.
///
/// Only effective when the `ProcTree` is populated with fd-table data.
pub fn ProcessFilter::with_fd_type(
  self : ProcessFilter,
  ty : FdType,
) -> ProcessFilter {
  { ..self, has_fd_type: Some(ty), }
}

///|
/// Returns `true` when the process satisfies every set criterion.
///
/// When `fd_table` is `None`, fd-related filters are ignored silently.
pub fn ProcessFilter::matches(
  self : ProcessFilter,
  process : Process,
  fd_table : FdTable?,
) -> Bool {
  // name_contains
  match self.name_contains {
    Some(sub) => if !process.name.contains(sub) { return false } else { () }
    None => ()
  }
  // state
  match self.state {
    Some(st) => if process.state != st { return false } else { () }
    None => ()
  }
  // min_rss_kb
  match self.min_rss_kb {
    Some(min) => if process.vm_rss_kb < min { return false } else { () }
    None => ()
  }
  // max_rss_kb
  match self.max_rss_kb {
    Some(max) => if process.vm_rss_kb > max { return false } else { () }
    None => ()
  }
  // min_threads
  match self.min_threads {
    Some(min) => if process.threads < min { return false } else { () }
    None => ()
  }
  // max_threads
  match self.max_threads {
    Some(max) => if process.threads > max { return false } else { () }
    None => ()
  }
  // fd-aware fields
  match fd_table {
    Some(t) => {
      match self.min_fds {
        Some(min) => if t.entries.length() < min { return false } else { () }
        None => ()
      }
      match self.has_fd_type {
        Some(ty) => if t.list_by_type(ty).length() == 0 { return false } else { () }
        None => ()
      }
    }
    None => ()
  }
  true
}

///|
pub extend ProcessFilter with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcessFilter with Eq::{not_equal, equal}