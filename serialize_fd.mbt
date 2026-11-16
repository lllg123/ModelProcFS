///|
/// Computes a stable pseudo-inode number from an fd entry.
fn fd_inode(fd : FileDescriptor) -> Int32 {
  let base = match fd.fd_type {
    RegularFile(_) => 0x100000
    Socket(_, _, _) => 0x200000
    Pipe => 0x300000
    EventFd => 0x400000
    TimerFd => 0x500000
    SignalFd => 0x600000
    Epoll => 0x700000
    Inotify => 0x800000
    AnonymousInode => 0x900000
  }
  base + fd.fd
}

///|
/// Returns the symbolic-link target string for one fd entry,
/// matching the format used in `/proc/[pid]/fd/`.
fn fd_symlink_target(fd : FileDescriptor) -> String {
  match fd.fd_type {
    RegularFile(path) => path
    Socket(_, _, _) => "socket:[\{fd_inode(fd)}]"
    Pipe => "pipe:[\{fd_inode(fd)}]"
    EventFd => "anon_inode:[eventfd]"
    TimerFd => "anon_inode:[timerfd]"
    SignalFd => "anon_inode:[signalfd]"
    Epoll => "anon_inode:[eventpoll]"
    Inotify => "anon_inode:inotify"
    AnonymousInode => "anon_inode:\{fd_inode(fd)}"
  }
}

///|
/// Serializes an `FdTable` into a list of `(fd_number, symlink_target)` pairs,
/// matching the contents of `/proc/[pid]/fd/`.
pub fn serialize_fd_list(table : FdTable) -> Array[(Int32, String)] {
  let result = []
  for i = 0; i < table.entries.length(); i = i + 1 {
    let entry = table.entries[i]
    result.push((entry.fd, fd_symlink_target(entry)))
  }
  result
}
