///|
test "construct regular file fd" {
  let fd = @modelprocfs.FileDescriptor::new(
    fd=3,
    fd_type=@modelprocfs.FdType::RegularFile("/var/log/app.log"),
    flags=0,
  )
  assert_eq(fd.fd, 3)
  assert_eq(fd.flags, 0)
  assert_true(fd.is_reg())
  assert_false(fd.is_socket())
}

///|
test "construct socket fd" {
  let fd = @modelprocfs.FileDescriptor::new(
    fd=4,
    fd_type=@modelprocfs.FdType::Socket("TCP", "10.0.0.1:54321", "10.0.0.2:80"),
    flags=0,
  )
  assert_eq(fd.fd, 4)
  assert_true(fd.is_socket())
  assert_false(fd.is_reg())
}

///|
test "construct pipe fd" {
  let fd = @modelprocfs.FileDescriptor::new(
    fd=5,
    fd_type=@modelprocfs.FdType::Pipe,
    flags=0,
  )
  assert_eq(fd.fd, 5)
  assert_false(fd.is_reg())
  assert_false(fd.is_socket())
}

///|
test "reject negative fd number" {
  try {
    let _ = @modelprocfs.FileDescriptor::new(
      fd=-1,
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidFdNumber(-1) => ()
    _ => abort("expected InvalidFdNumber(-1)")
  }
}

///|
test "empty table has zero count" {
  let t = @modelprocfs.FdTable::new()
  assert_eq(t.count(), 0)
}

///|
test "add and find descriptors" {
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
      fd_type=@modelprocfs.FdType::RegularFile("/tmp/out.log"),
      flags=0,
    ),
  )
  assert_eq(t.count(), 2)
  let found = t.find(1)
  assert_true(found is Some(_))
  match found {
    Some(f) => assert_eq(f.fd, 1)
    _ => abort("unreach")
  }
}

///|
test "find returns None for absent fd" {
  let t = @modelprocfs.FdTable::new()
  assert_eq(t.find(42), None)
}

///|
test "remove existing fd reduces count" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=3,
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=7,
      fd_type=@modelprocfs.FdType::EventFd,
      flags=0,
    ),
  )
  assert_eq(t.count(), 2)
  t.remove(3)
  assert_eq(t.count(), 1)
  assert_eq(t.find(3), None)
  assert_true(t.find(7) is Some(_))
}

///|
test "remove absent fd is no-op" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=0,
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    ),
  )
  assert_eq(t.count(), 1)
  t.remove(99)
  assert_eq(t.count(), 1)
}

///|
test "reject duplicate fd number" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=3,
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    ),
  )
  try {
    t.add(
      @modelprocfs.FileDescriptor::new(
        fd=3,
        fd_type=@modelprocfs.FdType::RegularFile("/x"),
        flags=0,
      ),
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::FdAlreadyExists(3) => ()
    _ => abort("expected FdAlreadyExists(3)")
  }
}

///|
test "list_by_type filters correctly" {
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
      fd_type=@modelprocfs.FdType::Pipe,
      flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=3,
      fd_type=@modelprocfs.FdType::RegularFile("/a"),
      flags=0,
    ),
  )
  let pipes = t.list_by_type(@modelprocfs.FdType::Pipe)
  assert_eq(pipes.length(), 2)
  for p in pipes {
    assert_eq(p.fd_type, @modelprocfs.FdType::Pipe)
  }
  let files = t.list_by_type(@modelprocfs.FdType::RegularFile("/a"))
  assert_eq(files.length(), 1)
  assert_eq(files[0].fd, 3)
}

///|
test "all fd type variants constructible" {
  let types = [
    @modelprocfs.FdType::RegularFile("/f"),
    @modelprocfs.FdType::Socket("TCP", "a", "b"),
    @modelprocfs.FdType::Pipe,
    @modelprocfs.FdType::EventFd,
    @modelprocfs.FdType::TimerFd,
    @modelprocfs.FdType::SignalFd,
    @modelprocfs.FdType::Epoll,
    @modelprocfs.FdType::Inotify,
    @modelprocfs.FdType::AnonymousInode,
  ]
  for ty in types {
    let fd = @modelprocfs.FileDescriptor::new(fd=1, fd_type=ty, flags=0)
    assert_eq(fd.fd, 1)
  }
}

///|
test "fd zero is valid (stdin)" {
  let fd = @modelprocfs.FileDescriptor::new(
    fd=0,
    fd_type=@modelprocfs.FdType::Pipe,
    flags=0,
  )
  assert_eq(fd.fd, 0)
}
