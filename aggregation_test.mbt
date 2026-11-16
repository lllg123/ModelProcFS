///|
test "stats on empty tree" {
  let tree = @modelprocfs.ProcTree::new()
  let stats = @modelprocfs.compute_stats(tree)
  assert_eq(stats.total_processes, 0)
  assert_eq(stats.total_threads, 0)
  assert_eq(stats.total_vm_kb, 0)
  assert_eq(stats.total_rss_kb, 0)
}

///|
test "stats on single process" {
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
  let stats = @modelprocfs.compute_stats(tree)
  assert_eq(stats.total_processes, 1)
  assert_eq(stats.total_threads, 1)
  assert_eq(stats.total_vm_kb, 4096)
  assert_eq(stats.total_rss_kb, 1024)
}

///|
test "stats accumulates across multiple processes" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="a",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=2,
      vm_size_kb=1000,
      vm_rss_kb=500,
    ),
  )
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=0,
      name="b",
      state=@modelprocfs.ProcessState::Running,
      threads=4,
      vm_size_kb=2000,
      vm_rss_kb=1000,
    ),
  )
  let stats = @modelprocfs.compute_stats(tree)
  assert_eq(stats.total_processes, 2)
  assert_eq(stats.total_threads, 6)
  assert_eq(stats.total_vm_kb, 3000)
  assert_eq(stats.total_rss_kb, 1500)
  assert_eq(stats.count_for(@modelprocfs.ProcessState::Sleeping), 1)
  assert_eq(stats.count_for(@modelprocfs.ProcessState::Running), 1)
}

///|
test "stats with fd tables" {
  let tree = @modelprocfs.ProcTree::new()
  tree.add_process(
    @modelprocfs.Process::new(
      pid=1,
      ppid=0,
      name="init",
      state=@modelprocfs.ProcessState::Sleeping,
      threads=1,
      vm_size_kb=100,
      vm_rss_kb=100,
    ),
  )
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=0,
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=1,
      fd_type=@modelprocfs.FdType::RegularFile("/log"),
      flags=0,
    ),
  )
  let tables = Map([(1, t)])
  let stats = @modelprocfs.compute_stats(tree, fd_tables=Some(tables))
  assert_eq(stats.total_fds, 2)
}
