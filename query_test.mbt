///|
test "empty filter matches everything" {
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
  let filter = @modelprocfs.ProcessFilter::new()
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 1)
}

///|
test "filter by name substring" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="systemd",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=102400,
      vm_rss_kb=8192,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=42,
      ppid=1,
      name="sshd",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=2,
      vm_size_kb=32768,
      vm_rss_kb=4096,
    ),
  )
  let filter = @modelprocfs.ProcessFilter::new().with_name_contains("ssh")
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 42)
}

///|
test "filter by state" {
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
      pid=7,
      ppid=1,
      name="worker",
      state=@modelprocfs.ProcessState::Running,
      threads=4,
      vm_size_kb=65536,
      vm_rss_kb=8192,
    ),
  )
  let filter = @modelprocfs.ProcessFilter::new().with_state(
    @modelprocfs.ProcessState::Running,
  )
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 7)
}

///|
test "filter by rss range" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="small",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=4096,
      vm_rss_kb=1024,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=1,
      name="big",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=8,
      vm_size_kb=256000,
      vm_rss_kb=32768,
    ),
  )
  let filter = @modelprocfs.ProcessFilter::new()
    .with_min_rss_kb(10000)
    .with_max_rss_kb(100000)
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 2)
}

///|
test "filter by thread count range" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="a",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=0,
      name="b",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=8,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  let filter = @modelprocfs.ProcessFilter::new().with_min_threads(4)
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 2)
}

///|
test "combined filter ANDs all criteria" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="sshd",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=100,
      vm_rss_kb=100,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=0,
      name="sshd",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=4,
      vm_size_kb=100,
      vm_rss_kb=50000,
    ),
  )
  let filter = @modelprocfs.ProcessFilter::new()
    .with_name_contains("ssh")
    .with_state(@modelprocfs.ProcessState::Sleeping)
    .with_min_rss_kb(10000)
  let results = tree.query(filter)
  assert_eq(results.length(), 1)
  assert_eq(results[0].pid, 2)
}

///|
test "filter returns empty when no match" {
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
  let filter = @modelprocfs.ProcessFilter::new().with_name_contains("nope")
  let results = tree.query(filter)
  assert_eq(results.length(), 0)
}

///|
test "find_by_name returns first exact match" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=10,
      ppid=0,
      name="bash",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=100,
      vm_rss_kb=100,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=20,
      ppid=10,
      name="bash",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=100,
      vm_rss_kb=100,
    ),
  )
  let found = tree.find_by_name("bash").unwrap()
  assert_eq(found.pid, 10)
}

///|
test "find_by_name returns None when absent" {
  let tree = @modelprocfs.ProcTree::new()
  assert_eq(tree.find_by_name("nope"), None)
}

///|
test "find_by_state groups processes" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="a",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=0,
      name="b",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=3,
      ppid=0,
      name="c",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  let running = tree.find_by_state(@modelprocfs.ProcessState::Running)
  assert_eq(running.length(), 2)
  let sleeping = tree.find_by_state(@modelprocfs.ProcessState::Sleeping)
  assert_eq(sleeping.length(), 1)
}
