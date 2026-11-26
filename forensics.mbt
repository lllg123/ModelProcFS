///|
/// A single event in a causal chain.
#derive(Debug, Eq)
pub(all) struct ProcessEvent {
  identity : ProcessIdentity
  pid : Int32
  name : String
  ppid : Int32
  from_state : ProcessState
  to_state : ProcessState
  exited : Bool
  became_zombie : Bool
  orphaned : Bool
}

///|
/// A causal link: `parent` failed, causing `children` to cascade.
#derive(Debug, Eq)
pub(all) struct CausalLink {
  parent : ProcessEvent
  children : Array[ProcessEvent]
  depth : Int32
}

///|
/// Result of causal backtracking across two snapshots.
#derive(Debug, Eq)
pub(all) struct CausalReport {
  before : String
  after : String
  root_causes : Array[CausalLink]
  cascading : Array[ProcessEvent]
}

///|
/// Given a parent identity, returns all child identities in the snapshot.
fn find_children(
  snapshot : ProcFSSnapshot,
  parent_identity : ProcessIdentity,
) -> Array[ProcessIdentity] {
  let result = []
  for i = 0; i < snapshot.processes.length(); i = i + 1 {
    let p = snapshot.processes[i]
    // Find the parent of this child in the snapshot by ppid
    let parent_in_snap = find_by_pid(snapshot, p.ppid)
    match parent_in_snap {
      Some(parent) =>
        if parent.identity().same_instance(parent_identity) {
          result.push(p.identity())
        }
      None => ()
    }
  }
  result
}

///|
/// Walk up parent chain to find deepest failed ancestor.
fn walk_up(
  identity : ProcessIdentity,
  before : ProcFSSnapshot,
  after : ProcFSSnapshot,
) -> (Int32, ProcessIdentity) {
  let mut current = identity
  let mut depth = 0
  let mut keep_going = true
  while keep_going {
    keep_going = false
    match find_by_identity(before, current) {
      None => ()
      Some(before_proc) => {
        let ppid = before_proc.ppid
        match find_by_pid(before, ppid) {
          None => ()
          Some(parent) => {
            let pid = parent.identity()
            match find_by_identity(after, pid) {
              None => {
                current = pid
                depth = depth + 1
                keep_going = true
              }
              Some(after_parent) =>
                if after_parent.state == Zombie || after_parent.state == Dead {
                  current = pid
                  depth = depth + 1
                  keep_going = true
                } else {
                  ()
                }
            }
          }
        }
      }
    }
  }
  (depth, current)
}

///|
/// Build a ProcessEvent from before/after state of a process.
fn build_event(
  identity : ProcessIdentity,
  before : ProcFSSnapshot,
  after : ProcFSSnapshot,
  default_name : String,
  default_ppid : Int32,
  set_orphaned : Bool,
) -> ProcessEvent {
  let from_proc = find_by_identity(before, identity)
  let to_proc = find_by_identity(after, identity)
  let (name, ppid, from_state, to_state, exited, became_zombie) = match
    (from_proc, to_proc) {
    (Some(b), Some(a)) =>
      (b.name, b.ppid, b.state, a.state, false, a.state == Zombie)
    (Some(b), None) => (b.name, b.ppid, b.state, b.state, true, false)
    (None, Some(a)) =>
      (a.name, a.ppid, a.state, a.state, false, a.state == Zombie)
    (None, None) =>
      (
        default_name,
        default_ppid,
        ProcessState::Dead,
        ProcessState::Dead,
        false,
        false,
      )
  }
  {
    identity,
    pid: identity.pid,
    name,
    ppid,
    from_state,
    to_state,
    exited,
    became_zombie,
    orphaned: set_orphaned,
  }
}

///|
/// Returns true when moving from `from` to `to` violates kernel state rules.
fn illegal_transition(from : ProcessState, to : ProcessState) -> Bool {
  if from == to {
    return false
  }
  // Zombie cannot go anywhere except Dead
  if from == Zombie && to != Dead {
    return true
  }
  // Dead is absorbing
  if from == Dead && to != Dead {
    return true
  }
  // Idle kernel thread should not transition to user states
  if from == Idle && to != Idle && to != Running && to != Sleeping {
    return true
  }
  false
}

///|
/// Returns true when a diff entry represents a failure event.
fn is_failure(d : ProcessDiff) -> Bool {
  if d.removed {
    return true
  }
  match d.to_state {
    Some(s) => if s == Zombie { return true } else { () }
    None => ()
  }
  if d.state_changed {
    match (d.from_state, d.to_state) {
      (Some(f), Some(t)) =>
        if illegal_transition(f, t) {
          return true
        } else {
          ()
        }
      _ => ()
    }
  }
  false
}

///|
/// Performs causal backtracking between two snapshots.
///
/// Algorithm:
/// 1. Build the family tree from `before` snapshot
/// 2. Compute identity-aware diff
/// 3. For each failed process, walk up the parent chain
/// 4. Processes with depth=0 are root causes; depth>0 are cascading
pub fn backtrack(
  before : ProcFSSnapshot,
  after : ProcFSSnapshot,
) -> CausalReport {
  let diff = diff_snapshots(before, after)

  // Collect failed process identities and whether they are root causes
  let failed_ids : Array[(ProcessIdentity, Bool)] = []
  for i = 0; i < diff.diffs.length(); i = i + 1 {
    let d = diff.diffs[i]
    if is_failure(d) {
      let (depth, root_id) = walk_up(d.identity, before, after)
      failed_ids.push((root_id, depth == 0))
      if depth > 0 {
        failed_ids.push((d.identity, false))
      }
    }
  }

  // Deduplicate root ids
  let root_ids : Array[ProcessIdentity] = []
  for i = 0; i < failed_ids.length(); i = i + 1 {
    let (id, is_root) = failed_ids[i]
    if is_root {
      root_ids.push(id)
    }
  }

  // Deduplicate cascade ids
  let cascade_ids : Array[ProcessIdentity] = []
  for i = 0; i < failed_ids.length(); i = i + 1 {
    let (id, is_root) = failed_ids[i]
    if !is_root {
      cascade_ids.push(id)
    }
  }

  // Build root cause links
  let root_causes : Array[CausalLink] = []
  for i = 0; i < root_ids.length(); i = i + 1 {
    let root_id = root_ids[i]
    // Find depth by walking up
    let (depth, _) = walk_up(root_id, before, after)
    let children = find_children(before, root_id)
    let child_events : Array[ProcessEvent] = []
    for j = 0; j < children.length(); j = j + 1 {
      let child_id = children[j]
      let child_event = build_event(child_id, before, after, "?", 0, true)
      child_events.push(child_event)
    }
    // Also add cascading events that have this root
    for j = 0; j < failed_ids.length(); j = j + 1 {
      let (fid, is_root) = failed_ids[j]
      if !is_root {
        let (fdepth, target_root) = walk_up(fid, before, after)
        if target_root.same_instance(root_id) && fdepth > 0 {
          let evt = build_event(fid, before, after, "?", 0, true)
          child_events.push(evt)
        }
      }
    }
    let parent_event = build_event(root_id, before, after, "?", 0, false)
    root_causes.push({ parent: parent_event, children: child_events, depth, })
  }

  // Build cascade events
  let cascading : Array[ProcessEvent] = []
  for i = 0; i < cascade_ids.length(); i = i + 1 {
    let evt = build_event(cascade_ids[i], before, after, "?", 0, true)
    cascading.push(evt)
  }

  {
    before: before.captured_at,
    after: after.captured_at,
    root_causes,
    cascading,
  }
}

///|
/// Produces a human-readable narrative of the causal analysis.
pub fn CausalReport::narrative(self : CausalReport) -> String {
  let lines = []
  lines.push("Causal analysis: \{self.before} → \{self.after}")
  if self.root_causes.length() == 0 && self.cascading.length() == 0 {
    lines.push("  No cascading failures detected.")
    return join_forensics_lines(lines)
  }
  for i = 0; i < self.root_causes.length(); i = i + 1 {
    let link = self.root_causes[i]
    let p = link.parent
    lines.push(
      "  ROOT CAUSE: pid \{p.pid} (\{p.name}) \{p.from_state.label()}→\{p.to_state.label()}",
    )
    for j = 0; j < link.children.length(); j = j + 1 {
      let c = link.children[j]
      lines.push(
        "    ↳ CASCADE: pid \{c.pid} (\{c.name}) \{c.from_state.label()}→\{c.to_state.label()} [orphaned]",
      )
    }
  }
  for i = 0; i < self.cascading.length(); i = i + 1 {
    let c = self.cascading[i]
    let orphan = if c.orphaned { " [orphaned]" } else { "" }
    lines.push(
      "  CASCADE: pid \{c.pid} (\{c.name}) \{c.from_state.label()}→\{c.to_state.label()}\{orphan}",
    )
  }
  join_forensics_lines(lines)
}

///|
fn join_forensics_lines(lines : Array[String]) -> String {
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
pub extend ProcessEvent with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcessEvent with Eq::{not_equal, equal}

///|
pub extend CausalLink with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CausalLink with Eq::{not_equal, equal}

///|
pub extend CausalReport with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CausalReport with Eq::{not_equal, equal}
