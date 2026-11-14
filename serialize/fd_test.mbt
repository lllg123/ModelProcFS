///|
test "serialize fd list with regular file" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=3,
      fd_type=@modelprocfs.FdType::RegularFile("/var/log/app.log"),
      flags=0,
    ),
  )
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, 3)
  assert_eq(pairs[0].1, "/var/log/app.log")
}

///|
test "serialize fd list with socket" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=4,
      fd_type=@modelprocfs.FdType::Socket(
        "TCP", "10.0.0.1:54321", "10.0.0.2:80",
      ),
      flags=0,
    ),
  )
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].0, 4)
  assert_true(pairs[0].1.has_prefix("socket:["))
}

///|
test "serialize fd list with pipe" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=0, fd_type=@modelprocfs.FdType::Pipe, flags=0,
    ),
  )
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs.length(), 1)
  assert_eq(pairs[0].1, "pipe:[3145728]")
}

///|
test "serialize fd list with special fd types" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=5, fd_type=@modelprocfs.FdType::EventFd, flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=6, fd_type=@modelprocfs.FdType::Epoll, flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=7, fd_type=@modelprocfs.FdType::Inotify, flags=0,
    ),
  )
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs.length(), 3)
  assert_eq(pairs[0].1, "anon_inode:[eventfd]")
  assert_eq(pairs[1].1, "anon_inode:[eventpoll]")
  assert_eq(pairs[2].1, "anon_inode:inotify")
}

///|
test "serialize empty fd table" {
  let t = @modelprocfs.FdTable::new()
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs.length(), 0)
}

///|
test "serialize multiple fds preserves order" {
  let t = @modelprocfs.FdTable::new()
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=3,
      fd_type=@modelprocfs.FdType::RegularFile("/a"),
      flags=0,
    ),
  )
  t.add(
    @modelprocfs.FileDescriptor::new(
      fd=5,
      fd_type=@modelprocfs.FdType::RegularFile("/b"),
      flags=0,
    ),
  )
  let pairs = @modelprocfs.serialize_fd_list(t)
  assert_eq(pairs[0].0, 3)
  assert_eq(pairs[1].0, 5)
  assert_eq(pairs[0].1, "/a")
  assert_eq(pairs[1].1, "/b")
}

///|
test "inode values are stable per fd number and type" {
  let a = @modelprocfs.FileDescriptor::new(
    fd=3,
    fd_type=@modelprocfs.FdType::RegularFile("/x"),
    flags=0,
  )
  let b = @modelprocfs.FileDescriptor::new(
    fd=3,
    fd_type=@modelprocfs.FdType::RegularFile("/y"),
    flags=0,
  )
  let pairs_a = @modelprocfs.FdTable::new()
  pairs_a.add(a)
  let target_a = @modelprocfs.serialize_fd_list(pairs_a)[0].1
  let pairs_b = @modelprocfs.FdTable::new()
  pairs_b.add(b)
  let target_b = @modelprocfs.serialize_fd_list(pairs_b)[0].1
  // Same fd+type produce the same inode, path differs
  assert_eq(target_a, "/x")
  assert_eq(target_b, "/y")
  // Both are regular files, no inode bracket syntax
  assert_false(target_a.has_prefix("socket"))
}