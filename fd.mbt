///|
/// The kind of resource a file descriptor references.
///
/// `Socket` carries protocol, local, and remote addresses as strings because
/// the model remains lossless — validation belongs to the ingest layer.
#derive(Debug, Eq)
pub(all) enum FdType {
  RegularFile(String)
  Socket(String, String, String)
  Pipe
  EventFd
  TimerFd
  SignalFd
  Epoll
  Inotify
  AnonymousInode
}

///|
/// A single entry in a process file-descriptor table.
///
/// `flags` holds the raw `O_*` bits from `fcntl(fd, F_GETFD)`.
#derive(Debug, Eq)
pub(all) struct FileDescriptor {
  fd : Int
  fd_type : FdType
  flags : Int
}

///|
pub extend FdType with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FdType with Eq::{not_equal, equal}

///|
/// Creates a validated file descriptor entry.
pub fn FileDescriptor::new(
  fd~ : Int,
  fd_type~ : FdType,
  flags~ : Int,
) -> FileDescriptor raise ProcFSError {
  if fd < 0 {
    raise ProcFSError::InvalidFdNumber(fd)
  }
  { fd, fd_type, flags, }
}

///|
/// Returns true when this descriptor references a regular file.
pub fn FileDescriptor::is_reg(self : FileDescriptor) -> Bool {
  self.fd_type is RegularFile(_)
}

///|
/// Returns true when this descriptor references a socket.
pub fn FileDescriptor::is_socket(self : FileDescriptor) -> Bool {
  self.fd_type is Socket(_, _, _)
}

///|
/// An ordered collection of file descriptors keyed by fd number.
///
/// Insertion order is preserved; an explicit `remove` is provided for
/// head-of-line eviction scenarios found in forensic reconstruction.
#derive(Debug, Eq)
pub(all) struct FdTable {
  entries : Array[FileDescriptor]
}

///|
/// Creates an empty fd table.
pub fn FdTable::new() -> FdTable {
  { entries: [], }
}

///|
/// Number of fds currently in the table.
pub fn FdTable::count(self : FdTable) -> Int {
  self.entries.length()
}

///|
/// Adds a descriptor.  Raises `FdAlreadyExists` when a descriptor with the
/// same fd number is already present.
pub fn FdTable::add(
  self : FdTable,
  fd : FileDescriptor,
) -> Unit raise ProcFSError {
  for existing in self.entries {
    if existing.fd == fd.fd {
      raise ProcFSError::FdAlreadyExists(fd.fd)
    }
  }
  self.entries.push(fd)
}

///|
/// Removes a descriptor by fd number.  Idempotent when the fd is not found.
pub fn FdTable::remove(self : FdTable, fd_number : Int) -> Unit {
  let mut index = -1
  for i, entry in self.entries {
    if entry.fd == fd_number {
      index = i
    }
  }
  if index >= 0 {
    ignore(self.entries.remove(index))
  }
}

///|
/// Finds a descriptor by fd number, or `None` when absent.
pub fn FdTable::find(self : FdTable, fd_number : Int) -> FileDescriptor? {
  for entry in self.entries {
    if entry.fd == fd_number {
      return Some(entry)
    }
  }
  None
}

///|
/// Returns a snapshot of every descriptor of a given kind.
pub fn FdTable::list_by_type(self : FdTable, kind : FdType) -> Array[FileDescriptor] {
  let result = []
  for entry in self.entries {
    if entry.fd_type == kind {
      result.push(entry)
    }
  }
  result
}

///|
pub extend FileDescriptor with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FileDescriptor with Eq::{not_equal, equal}

///|
pub extend FdTable with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend FdTable with Eq::{not_equal, equal}