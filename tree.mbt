///|
/// An in-memory model of the `/proc` filesystem tree.
///
/// Processes are added and removed as `Process` records; the tree
/// automatically creates the standard `/proc/<pid>/` layout.
#derive(Debug, Eq)
pub(all) struct ProcTree {
  root : ProcNode
}

///|
/// Creates an empty `/proc` tree with only the root directory.
pub fn ProcTree::new() -> ProcTree {
  {
    root: ProcNode::Directory(name="proc", children=[]),
  }
}

///|
/// Inserts a process into the tree under `/proc/<pid>/`.
///
/// Creates a standard layout:
/// - `status`  — key-value file with `Name`, `Pid`, `PPid`, `State`,
///               `Threads`, `VmSize`, `VmRSS`
/// - `fd/`     — empty directory (populated separately)
/// - `maps`    — text placeholder (populated by serializer layer)
pub fn ProcTree::add_process(
  self : ProcTree,
  process : Process,
) -> Unit raise ProcFSError {
  let pid_dir = process.pid.to_string()
  if self.get_process_node(process.pid) is Some(_) {
    raise ProcFSError::ProcessAlreadyExists(process.pid)
  }
  let state_line = process.state.label() + " (" + process.name + ")"
  let status_map = Map([
    ("Name", process.name),
    ("Pid", process.pid.to_string()),
    ("PPid", process.ppid.to_string()),
    ("State", state_line),
    ("Threads", process.threads.to_string()),
    ("VmSize", "\{process.vm_size_kb} kB"),
    ("VmRSS", "\{process.vm_rss_kb} kB"),
  ])
  let status_file = ProcNode::File(
    name="status",
    content=ProcEntry::KeyValue(status_map),
  )
  let fd_dir = ProcNode::Directory(name="fd", children=[])
  let maps_file = ProcNode::File(
    name="maps",
    content=ProcEntry::Text(""),
  )
  let dir = ProcNode::Directory(
    name=pid_dir,
    children=[status_file, fd_dir, maps_file],
  )
  self.root.add_child(dir)
}

///|
/// Removes a process directory by pid. Idempotent.
pub fn ProcTree::remove_process(self : ProcTree, pid : Int) -> Unit {
  self.root.remove_child(pid.to_string())
}

///|
/// Returns the directory node for `pid`, or `None`.
pub fn ProcTree::get_process_node(self : ProcTree, pid : Int) -> ProcNode? {
  self.root.find_child(pid.to_string())
}

///|
/// Lists pid directories currently in the tree.
pub fn ProcTree::list_pids(self : ProcTree) -> Array[Int] {
  let pids = []
  let names = self.root.child_names()
  for name in names {
    try {
      pids.push(@string.parse_int(name))
    } catch {
      _ => ()
    }
  }
  pids
}

///|
/// Walks a `/proc/…` path and returns the node at the end, or `None`.
///
/// Leading `/proc` is stripped before traversal; the remainder is split
/// on `/` and walked segment by segment. Returns `None` when any segment
/// cannot be found or when the path does not start with `/proc`.
pub fn ProcTree::resolve(self : ProcTree, path : String) -> ProcNode? {
  let segments = split_proc_path(path)
  match segments {
    Some(parts) => {
      let mut current = self.root
      for part in parts {
        let child = current.find_child(part)
        match child {
          Some(c) => current = c
          None => return None
        }
      }
      Some(current)
    }
    None => None
  }
}

///|
/// Returns a count of processes currently tracked.
pub fn ProcTree::process_count(self : ProcTree) -> Int {
  self.list_pids().length()
}

///|
/// Strips the `/proc` prefix and splits the remainder into segments.
///
/// Returns `None` when the path does not start with `/proc`.
fn split_proc_path(path : String) -> Option[Array[String]] {
  if !path.has_prefix("/proc") {
    return None
  }
  let tail = path[5:]
  if tail == "" {
    return Some([])
  }
  if tail[0] != '/' {
    return None
  }
  let trimmed = if tail.length() > 1 { tail[1:].to_owned() } else { "" }
  if trimmed == "" {
    return Some([])
  }
  let segments = []
  let mut start = 0
  for i = 0; i < trimmed.length(); i = i + 1 {
    if trimmed[i] == '/' {
      segments.push(trimmed[start:i].to_owned())
      start = i + 1
    }
  }
  segments.push(trimmed[start:].to_owned())
  Some(segments)
}

///|
pub extend ProcTree with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcTree with Eq::{not_equal, equal}