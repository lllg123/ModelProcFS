///|
test "backtrack detects parent-zombie cascades child" {
  // T1: init(1) → worker(99) → helper(100), all Running
  // T2: worker Zombie, helper Zombie, init still Running
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
      start_time_ticks=Some(100L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=99,
      ppid=1,
      name="worker",
      state=@modelprocfs.ProcessState::Running,
      threads=4,
      vm_size_kb=65536,
      vm_rss_kb=16384,
      start_time_ticks=Some(1000L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=100,
      ppid=99,
      name="helper",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=8192,
      vm_rss_kb=2048,
      start_time_ticks=Some(2000L),
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  // T2
  tree.remove_process(99)
  tree.remove_process(100)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=99,
      ppid=1,
      name="worker",
      state=@modelprocfs.ProcessState::Zombie,
      threads=0,
      vm_size_kb=65536,
      vm_rss_kb=0,
      start_time_ticks=Some(1000L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=100,
      ppid=99,
      name="helper",
      state=@modelprocfs.ProcessState::Zombie,
      threads=0,
      vm_size_kb=8192,
      vm_rss_kb=0,
      start_time_ticks=Some(2000L),
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let report = @modelprocfs.backtrack(before, after)
  assert_true(report.root_causes.length() > 0)
  assert_eq(report.root_causes[0].parent.pid, 99)
  assert_eq(report.root_causes[0].parent.name, "worker")
}

///|
test "backtrack narrative contains causal chain" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
      start_time_ticks=Some(100L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=42,
      ppid=1,
      name="broker",
      state=@modelprocfs.ProcessState::Running,
      threads=2,
      vm_size_kb=32768,
      vm_rss_kb=8192,
      start_time_ticks=Some(500L),
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(42)
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let report = @modelprocfs.backtrack(before, after)
  let text = report.narrative()
  assert_true(text.contains("ROOT CAUSE"))
  assert_true(text.contains("broker"))
}

///|
test "no failures yields empty report" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  let snap = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  let report = @modelprocfs.backtrack(snap, snap)
  assert_eq(report.root_causes.length(), 0)
  assert_eq(report.cascading.length(), 0)
}

///|
test "root cause walk stops at healthy ancestor" {
  // T1: init → worker → child (all Running)
  // T2: init R, worker R (healthy!), child Zombie → child is root cause
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
      start_time_ticks=Some(100L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=50,
      ppid=1,
      name="worker",
      state=@modelprocfs.ProcessState::Running,
      threads=2,
      vm_size_kb=8192,
      vm_rss_kb=4096,
      start_time_ticks=Some(300L),
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=51,
      ppid=50,
      name="child",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
      start_time_ticks=Some(500L),
    ),
  )
  let before = @modelprocfs.ProcFSSnapshot::new(captured_at="T1", tree)
  tree.remove_process(51)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=51,
      ppid=50,
      name="child",
      state=@modelprocfs.ProcessState::Zombie,
      threads=0,
      vm_size_kb=4096,
      vm_rss_kb=0,
      start_time_ticks=Some(500L),
    ),
  )
  let after = @modelprocfs.ProcFSSnapshot::new(captured_at="T2", tree)
  let report = @modelprocfs.backtrack(before, after)
  assert_eq(report.root_causes.length(), 1)
  assert_eq(report.root_causes[0].parent.pid, 51)
  assert_eq(report.root_causes[0].parent.name, "child")
}
