///|
test "parse_status round-trip" {
  let original = @modelprocfs.Process::new(
    pid=1, ppid=0, name="systemd",
    state=@modelprocfs.ProcessState::Sleeping,
    threads=1, vm_size_kb=102400, vm_rss_kb=8192,
  )
  let text = @modelprocfs.serialize_status(original)
  let parsed = @modelprocfs.parse_status(text)
  assert_eq(parsed.pid, original.pid)
  assert_eq(parsed.ppid, original.ppid)
  assert_eq(parsed.name, original.name)
  assert_eq(parsed.state, original.state)
  assert_eq(parsed.threads, original.threads)
  assert_eq(parsed.vm_size_kb, original.vm_size_kb)
  assert_eq(parsed.vm_rss_kb, original.vm_rss_kb)
}

///|
test "parse_status running process round-trip" {
  let original = @modelprocfs.Process::new(
    pid=4242, ppid=1, name="my-daemon",
    state=@modelprocfs.ProcessState::Running,
    threads=8, vm_size_kb=256000, vm_rss_kb=32768,
  )
  let text = @modelprocfs.serialize_status(original)
  let parsed = @modelprocfs.parse_status(text)
  assert_eq(parsed.pid, 4242)
  assert_eq(parsed.state, @modelprocfs.ProcessState::Running)
  assert_eq(parsed.threads, 8)
}

///|
test "parse_status zombie process round-trip" {
  let original = @modelprocfs.Process::new(
    pid=99, ppid=1, name="defunct",
    state=@modelprocfs.ProcessState::Zombie,
    threads=0, vm_size_kb=0, vm_rss_kb=0,
  )
  let text = @modelprocfs.serialize_status(original)
  let parsed = @modelprocfs.parse_status(text)
  assert_eq(parsed.pid, 99)
  assert_eq(parsed.state, @modelprocfs.ProcessState::Zombie)
  assert_eq(parsed.threads, 0)
  assert_eq(parsed.vm_size_kb, 0)
}

///|
test "parse_status rejects empty text" {
  try {
    let _ = @modelprocfs.parse_status("")
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::ParseError(_) => ()
    _ => abort("expected ParseError")
  }
}

///|
test "parse_maps round-trip" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=true, shared=false, private=true,
  )
  let original = @modelprocfs.MemoryMap::new()
  original.add(
    @modelprocfs.MemoryRegion::new(
      start=0x7f000000, end=0x7f001000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=12345,
      path=Some("/usr/lib/libc.so"),
    ),
  )
  let text = @modelprocfs.serialize_maps(original)
  let parsed = @modelprocfs.parse_maps(text)
  assert_eq(parsed.count(), 1)
  assert_eq(parsed.regions[0].start, 0x7f000000)
  assert_eq(parsed.regions[0].end, 0x7f001000)
  assert_eq(parsed.regions[0].perms, perms)
  assert_eq(parsed.regions[0].path, Some("/usr/lib/libc.so"))
}

///|
test "parse_maps anonymous region round-trip" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=false, private=true,
  )
  let original = @modelprocfs.MemoryMap::new()
  original.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x2000, perms=perms, offset=0x1000,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  let text = @modelprocfs.serialize_maps(original)
  let parsed = @modelprocfs.parse_maps(text)
  assert_eq(parsed.count(), 1)
  assert_eq(parsed.regions[0].path, None)
}

///|
test "parse_maps empty input" {
  let parsed = @modelprocfs.parse_maps("")
  assert_eq(parsed.count(), 0)
}

///|
test "parse_maps multiple regions round-trip" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=false, shared=false, private=true,
  )
  let original = @modelprocfs.MemoryMap::new()
  original.add(
    @modelprocfs.MemoryRegion::new(
      start=0, end=0x1000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=1, path=Some("/a"),
    ),
  )
  original.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x3000, perms=perms, offset=0,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  let text = @modelprocfs.serialize_maps(original)
  let parsed = @modelprocfs.parse_maps(text)
  assert_eq(parsed.count(), 2)
}

///|
test "parse_fd_symlink regular file" {
  let result = @modelprocfs.parse_fd_symlink("/var/log/app.log")
  assert_eq(result, @modelprocfs.FdType::RegularFile("/var/log/app.log"))
}

///|
test "parse_fd_symlink socket" {
  let result = @modelprocfs.parse_fd_symlink("socket:[1234]")
  assert_eq(result, @modelprocfs.FdType::Socket("", "", ""))
}

///|
test "parse_fd_symlink pipe" {
  let result = @modelprocfs.parse_fd_symlink("pipe:[3145728]")
  assert_eq(result, @modelprocfs.FdType::Pipe)
}

///|
test "parse_fd_symlink special types" {
  assert_eq(
    @modelprocfs.parse_fd_symlink("anon_inode:[eventfd]"),
    @modelprocfs.FdType::EventFd,
  )
  assert_eq(
    @modelprocfs.parse_fd_symlink("anon_inode:[eventpoll]"),
    @modelprocfs.FdType::Epoll,
  )
  assert_eq(
    @modelprocfs.parse_fd_symlink("anon_inode:inotify"),
    @modelprocfs.FdType::Inotify,
  )
}

///|
test "parse_fd_symlink anon_inode fallback" {
  let result = @modelprocfs.parse_fd_symlink("anon_inode:[other]")
  assert_eq(result, @modelprocfs.FdType::AnonymousInode)
}