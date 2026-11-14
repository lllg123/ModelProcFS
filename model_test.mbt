///|
test "construct valid process" {
  let p = @modelprocfs.Process::new(
    pid=1,
    ppid=0,
    name="systemd",
    state=@modelprocfs.ProcessState::Sleeping,
    threads=1,
    vm_size_kb=102400,
    vm_rss_kb=8192,
  )
  assert_eq(p.pid, 1)
  assert_eq(p.ppid, 0)
  assert_eq(p.name, "systemd")
  assert_eq(p.state, @modelprocfs.ProcessState::Sleeping)
  assert_eq(p.threads, 1)
  assert_eq(p.vm_size_kb, 102400)
  assert_eq(p.vm_rss_kb, 8192)
}

///|
test "construct user process with positive ppid" {
  let p = @modelprocfs.Process::new(
    pid=4242,
    ppid=1,
    name="my-daemon",
    state=@modelprocfs.ProcessState::Running,
    threads=4,
    vm_size_kb=256000,
    vm_rss_kb=16384,
  )
  assert_eq(p.pid, 4242)
  assert_eq(p.ppid, 1)
  assert_eq(p.name, "my-daemon")
  assert_eq(p.state, @modelprocfs.ProcessState::Running)
  assert_eq(p.threads, 4)
}

///|
test "zero vm fields are valid for idle kernel threads" {
  let p = @modelprocfs.Process::new(
    pid=2,
    ppid=0,
    name="kthreadd",
    state=@modelprocfs.ProcessState::Idle,
    threads=1,
    vm_size_kb=0,
    vm_rss_kb=0,
  )
  assert_eq(p.vm_size_kb, 0)
  assert_eq(p.vm_rss_kb, 0)
}

///|
test "reject pid zero" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=0, ppid=0, name="test",
      state=@modelprocfs.ProcessState::Running,
      threads=1, vm_size_kb=1024, vm_rss_kb=512,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidPid(0) => ()
    _ => abort("expected InvalidPid(0)")
  }
}

///|
test "reject negative pid" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=-1, ppid=0, name="test",
      state=@modelprocfs.ProcessState::Running,
      threads=1, vm_size_kb=1024, vm_rss_kb=512,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidPid(-1) => ()
    _ => abort("expected InvalidPid(-1)")
  }
}

///|
test "reject empty process name" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=1, ppid=0, name="",
      state=@modelprocfs.ProcessState::Running,
      threads=1, vm_size_kb=1024, vm_rss_kb=512,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::EmptyProcessName => ()
    _ => abort("expected EmptyProcessName")
  }
}

///|
test "reject negative thread count" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=1, ppid=0, name="test",
      state=@modelprocfs.ProcessState::Running,
      threads=-1, vm_size_kb=1024, vm_rss_kb=512,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidThreadCount(-1) => ()
    _ => abort("expected InvalidThreadCount(-1)")
  }
}

///|
test "reject negative vm size" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=1, ppid=0, name="test",
      state=@modelprocfs.ProcessState::Running,
      threads=1, vm_size_kb=-1, vm_rss_kb=512,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidVmSize(-1) => ()
    _ => abort("expected InvalidVmSize(-1)")
  }
}

///|
test "reject negative vm rss" {
  try {
    let _ = @modelprocfs.Process::new(
      pid=1, ppid=0, name="test",
      state=@modelprocfs.ProcessState::Running,
      threads=1, vm_size_kb=1024, vm_rss_kb=-1,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidVmRSS(-1) => ()
    _ => abort("expected InvalidVmRSS(-1)")
  }
}

///|
test "process state labels" {
  assert_eq(@modelprocfs.ProcessState::Running.label(), "R")
  assert_eq(@modelprocfs.ProcessState::Sleeping.label(), "S")
  assert_eq(@modelprocfs.ProcessState::DiskSleep.label(), "D")
  assert_eq(@modelprocfs.ProcessState::Zombie.label(), "Z")
  assert_eq(@modelprocfs.ProcessState::Stopped.label(), "T")
  assert_eq(@modelprocfs.ProcessState::TracingStop.label(), "t")
  assert_eq(@modelprocfs.ProcessState::Dead.label(), "X")
  assert_eq(@modelprocfs.ProcessState::Idle.label(), "I")
}

///|
test "process state from_code round-trip" {
  let codes = ["R", "S", "D", "Z", "T", "t", "X", "I"]
  for code in codes {
    let state = @modelprocfs.ProcessState::from_code(code)
    assert_eq(state.unwrap().label(), code)
  }
}

///|
test "from_code returns None for invalid code" {
  assert_eq(@modelprocfs.ProcessState::from_code("?"), None)
  assert_eq(@modelprocfs.ProcessState::from_code(""), None)
  assert_eq(@modelprocfs.ProcessState::from_code("r"), None)
  assert_eq(@modelprocfs.ProcessState::from_code("s"), None)
}