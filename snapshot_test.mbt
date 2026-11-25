///|
test "snapshot captures all processes" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=42,
      ppid=1,
      name="sshd",
      state=@modelprocfs.ProcessState::Running,
      threads=2,
      vm_size_kb=32768,
      vm_rss_kb=4096,
    ),
  )
  let snap = @modelprocfs.ProcFSSnapshot::new(
    captured_at="2026-01-15T10:00:00Z",
    tree,
  )
  assert_eq(snap.captured_at, "2026-01-15T10:00:00Z")
  assert_eq(snap.processes.length(), 2)
}

///|
test "empty snapshot has no processes" {
  let tree = @modelprocfs.ProcTree::new()
  let snap = @modelprocfs.ProcFSSnapshot::new(captured_at="T0", tree)
  assert_eq(snap.processes.length(), 0)
}

///|
test "diff detects added process" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=42,
      ppid=1,
      name="sshd",
      state=@modelprocfs.ProcessState::Running,
      threads=2,
      vm_size_kb=32768,
      vm_rss_kb=8192,
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  assert_eq(diff.diffs.length(), 1)
  assert_eq(diff.diffs[0].pid, 42)
  assert_true(diff.diffs[0].added)
}

///|
test "diff detects removed process" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(1)
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  assert_eq(diff.diffs.length(), 1)
  assert_eq(diff.diffs[0].pid, 1)
  assert_true(diff.diffs[0].removed)
}

///|
test "diff detects state change" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(1)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Zombie,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  assert_true(diff.diffs.length() >= 1)
  let mut changed = false
  for i = 0; i < diff.diffs.length(); i = i + 1 {
    if diff.diffs[i].state_changed {
      changed = true
    }
  }
  assert_true(changed)
}

///|
test "diff with no changes is empty" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  assert_eq(diff.diffs.length(), 0)
}

///|
test "diff summary for no changes" {
  let summary = "Snapshot diff: T1 -> T1\n  no changes"
  let tree = @modelprocfs.ProcTree::new()
  let s = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  let diff = @modelprocfs.diff_snapshots(s, s)
  assert_eq(diff.summary(), summary)
}

///|
test "diff summary includes added process" {
  let tree = @modelprocfs.ProcTree::new()
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  let sum = diff.summary()
  assert_true(sum.contains("+ pid 1"))
  assert_true(sum.contains("new process"))
}

///|
test "PID reuse is detected with identity conflict" {
  // Simulates: worker (pid=7) crashes and exits between T1 and T2;
  // the kernel reuses PID 7 for a new process "logger".
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=7,
      ppid=1,
      name="worker",
      state=@modelprocfs.ProcessState::Running,
      threads=4,
      vm_size_kb=65536,
      vm_rss_kb=16384,
      start_time_ticks=Some(1500L),
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(7)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=7,
      ppid=1,
      name="logger",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=8192,
      vm_rss_kb=2048,
      start_time_ticks=Some(8000L),
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  // Expect 2 diffs: worker removed, logger added, both with conflict flag
  assert_eq(diff.diffs.length(), 2)
  let mut saw_removed = false
  let mut saw_added = false
  for i = 0; i < diff.diffs.length(); i = i + 1 {
    let d = diff.diffs[i]
    assert_true(d.identity_conflict)
    if d.removed {
      saw_removed = true
      assert_eq(d.pid, 7)
      assert_eq(d.from_state, Some(@modelprocfs.ProcessState::Running))
    }
    if d.added {
      saw_added = true
      assert_eq(d.pid, 7)
      assert_eq(d.to_state, Some(@modelprocfs.ProcessState::Sleeping))
    }
  }
  assert_true(saw_removed)
  assert_true(saw_added)
}

///|
test "process diff vm_rss_delta tracks changes" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=10000,
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(1)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=15000,
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let diff = @modelprocfs.diff_snapshots(before, after)
  let mut delta_is_5000 = false
  for i = 0; i < diff.diffs.length(); i = i + 1 {
    if diff.diffs[i].vm_rss_delta_kb == 5000 {
      delta_is_5000 = true
    }
  }
  assert_true(delta_is_5000)
}
