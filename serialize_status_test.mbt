///|
test "serialize status for typical process" {
  let p = @modelprocfs.Process::new(
    pid=1,
    ppid=0,
    name="systemd",
    state=@modelprocfs.ProcessState::Sleeping,
    threads=1,
    vm_size_kb=102400,
    vm_rss_kb=8192,
  )
  let s = @modelprocfs.serialize_status(p)
  assert_true(s.has_prefix("Name:\tsystemd\n"))
  assert_true(s.contains("State:\tS (systemd)"))
  assert_true(s.contains("Pid:\t1"))
  assert_true(s.contains("PPid:\t0"))
  assert_true(s.contains("Threads:\t1"))
  assert_true(s.contains("VmSize:\t  102400 kB"))
  assert_true(s.contains("VmRSS:\t  8192 kB"))
}

///|
test "serialize status for running process with threads" {
  let p = @modelprocfs.Process::new(
    pid=4242,
    ppid=1,
    name="my-daemon",
    state=@modelprocfs.ProcessState::Running,
    threads=8,
    vm_size_kb=256000,
    vm_rss_kb=32768,
  )
  let s = @modelprocfs.serialize_status(p)
  assert_true(s.contains("Pid:\t4242"))
  assert_true(s.contains("PPid:\t1"))
  assert_true(s.contains("State:\tR (my-daemon)"))
  assert_true(s.contains("Threads:\t8"))
}

///|
test "serialize status for zombie process" {
  let p = @modelprocfs.Process::new(
    pid=99,
    ppid=1,
    name="defunct",
    state=@modelprocfs.ProcessState::Zombie,
    threads=0,
    vm_size_kb=0,
    vm_rss_kb=0,
  )
  let s = @modelprocfs.serialize_status(p)
  assert_true(s.contains("State:\tZ (defunct)"))
  assert_true(s.contains("Threads:\t0"))
  assert_true(s.contains("VmSize:\t  0 kB"))
  assert_true(s.contains("VmRSS:\t  0 kB"))
}

///|
test "serialize status includes tgid equal to pid" {
  let p = @modelprocfs.Process::new(
    pid=7,
    ppid=1,
    name="worker",
    state=@modelprocfs.ProcessState::Sleeping,
    threads=2,
    vm_size_kb=65536,
    vm_rss_kb=16384,
  )
  let s = @modelprocfs.serialize_status(p)
  assert_true(s.contains("Tgid:\t7"))
  assert_true(s.contains("Pid:\t7"))
}
