///|
test "empty tree has no processes" {
  let tree = @modelprocfs.ProcTree::new()
  assert_eq(tree.process_count(), 0)
  assert_eq(tree.list_pids(), [])
}

///|
test "add process creates pid directory with status and fd" {
  let tree = @modelprocfs.ProcTree::new()
  let p = @modelprocfs.Process::new(
    pid=1,
    ppid=0,
    name="systemd",
    state=@modelprocfs.ProcessState::Sleeping,
    threads=1,
    vm_size_kb=102400,
    vm_rss_kb=8192,
  )
  tree.add_process(p)
  assert_eq(tree.process_count(), 1)
  assert_eq(tree.list_pids(), [1])
  let node = tree.get_process_node(1).unwrap()
  assert_true(node.is_directory())
  let status = node.find_child("status").unwrap()
  assert_true(status.is_file())
  assert_eq(status.lookup("Name"), Some("systemd"))
  assert_eq(status.lookup("Pid"), Some("1"))
  assert_eq(status.lookup("PPid"), Some("0"))
  assert_eq(status.lookup("Threads"), Some("1"))
  let fd = node.find_child("fd").unwrap()
  assert_true(fd.is_directory())
  assert_eq(fd.child_names(), [])
}

///|
test "add multiple processes and list pids" {
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
      state=@modelprocfs.ProcessState::Sleeping,
      threads=2,
      vm_size_kb=32768,
      vm_rss_kb=4096,
    ),
  )
  assert_eq(tree.process_count(), 2)
  let pids = tree.list_pids()
  assert_eq(pids.length(), 2)
}

///|
test "remove process by pid" {
  let tree = @modelprocfs.ProcTree::new()
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
  assert_eq(tree.process_count(), 1)
  tree.remove_process(7)
  assert_eq(tree.process_count(), 0)
  assert_eq(tree.get_process_node(7), None)
}

///|
test "remove absent pid is no-op" {
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
  assert_eq(tree.process_count(), 1)
  tree.remove_process(999)
  assert_eq(tree.process_count(), 1)
}

///|
test "reject duplicate pid" {
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
  try {
    tree.add_process(
      @modelprocfs.Process::new(
        pid=1,
        ppid=1,
        name="clone",
        state=@modelprocfs.ProcessState::Running,
        threads=1,
        vm_size_kb=4096,
        vm_rss_kb=1024,
      ),
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::ProcessAlreadyExists(1) => ()
    _ => abort("expected ProcessAlreadyExists(1)")
  }
}

///|
test "resolve path to process status file" {
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
  // resolve pid directory
  let dir = tree.resolve("/proc/1")
  assert_true(dir is Some(_))
  match dir {
    Some(d) => assert_eq(d.name(), "1")
    _ => abort("unreach")
  }
  // resolve status file
  let status = tree.resolve("/proc/1/status")
  assert_true(status is Some(_))
  match status {
    Some(s) => {
      assert_eq(s.name(), "status")
      assert_true(s.is_file())
    }
    _ => abort("unreach")
  }
  // resolve fd directory
  let fd = tree.resolve("/proc/1/fd")
  assert_true(fd is Some(_))
  match fd {
    Some(f) => assert_eq(f.name(), "fd")
    _ => abort("unreach")
  }
}

///|
test "resolve returns None for missing path" {
  let tree = @modelprocfs.ProcTree::new()
  assert_eq(tree.resolve("/proc/1/status"), None)
  assert_eq(tree.resolve("/proc/1/nope"), None)
  assert_eq(tree.resolve("/sys/class"), None)
  assert_true(tree.resolve("/proc") is Some(_))
}

///|
test "list_pids ignores non-numeric children" {
  let tree = @modelprocfs.ProcTree::new()
  // add a non-pid file at /proc level
  tree
  .resolve("/proc")
  .unwrap()
  .add_child(
    @modelprocfs.ProcNode::File(
      name="version",
      content=@modelprocfs.ProcEntry::Text("5.15"),
    ),
  )
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
  assert_eq(tree.list_pids(), [1])
}

///|
test "process count reflects adds and removes" {
  let tree = @modelprocfs.ProcTree::new()
  assert_eq(tree.process_count(), 0)
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
  assert_eq(tree.process_count(), 1)
  tree.add_process(
    @modelprocfs.Process::new(
      pid=2,
      ppid=1,
      name="b",
      state=@modelprocfs.ProcessState::Running,
      threads=1,
      vm_size_kb=1,
      vm_rss_kb=1,
    ),
  )
  assert_eq(tree.process_count(), 2)
  tree.remove_process(1)
  assert_eq(tree.process_count(), 1)
}
