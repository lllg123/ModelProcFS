///|
/// Memory region protection flags modelled from `/proc/[pid]/maps` perms column.
#derive(Debug, Eq)
pub(all) struct MemPerms {
  read : Bool
  write : Bool
  execute : Bool
  shared : Bool
  private : Bool
}

///|
/// Creates perms from individual flags.
pub fn MemPerms::new(
  read~ : Bool,
  write~ : Bool,
  execute~ : Bool,
  shared~ : Bool,
  private~ : Bool,
) -> MemPerms raise ProcFSError {
  if shared && private {
    raise ProcFSError::InvalidMemoryPerms("shared and private cannot both be set")
  }
  { read, write, execute, shared, private, }
}

///|
/// Returns the four-char `r-xp` style string used in `/proc/[pid]/maps`.
pub fn MemPerms::to_string(self : MemPerms) -> String {
  let r = if self.read { "r" } else { "-" }
  let w = if self.write { "w" } else { "-" }
  let x = if self.execute { "x" } else { "-" }
  let ps = if self.private { "p" } else { "s" }
  r + w + x + ps
}

///|
/// Parses the four-char perms column from a maps line.
pub fn MemPerms::from_string(s : String) -> MemPerms? {
  if s.length() < 4 {
    return None
  }
  let read = s[0] == 'r'
  let write = s[1] == 'w'
  let execute = s[2] == 'x'
  let private = match s[3] {
    'p' => Some(true)
    's' => Some(false)
    _ => None
  }
  match private {
    Some(p) => Some(try! MemPerms::new(
      read~, write~, execute~, shared=!p, private=p,
    ))
    None => None
  }
}

///|
/// A single virtual memory area record from `/proc/[pid]/maps`.
///
/// The `path` field is `None` for anonymous mappings and the `[vdso]`/`[stack]`
/// pseudo-names are stored as plain string paths.
#derive(Debug, Eq)
pub(all) struct MemoryRegion {
  start : Int
  end : Int
  perms : MemPerms
  offset : Int
  dev_major : Int
  dev_minor : Int
  inode : Int
  path : String?
}

///|
/// Creates a validated memory region.
///
/// Raises when `start >= end` or any numeric field is negative.
pub fn MemoryRegion::new(
  start~ : Int,
  end~ : Int,
  perms~ : MemPerms,
  offset~ : Int,
  dev_major~ : Int,
  dev_minor~ : Int,
  inode~ : Int,
  path~ : String?,
) -> MemoryRegion raise ProcFSError {
  if start >= end {
    raise ProcFSError::InvalidMemoryRange(start, end)
  }
  if offset < 0 {
    raise ProcFSError::InvalidMemoryRange(start, end)
  }
  { start, end, perms, offset, dev_major, dev_minor, inode, path, }
}

///|
/// Size of this region in bytes.
pub fn MemoryRegion::size(self : MemoryRegion) -> Int {
  self.end - self.start
}

///|
/// True when this region has no backing file ( `path` is `None` ).
pub fn MemoryRegion::is_anonymous(self : MemoryRegion) -> Bool {
  self.path is None
}

///|
/// An ordered snapshot of `/proc/[pid]/maps` for one process.
///
/// Regions are stored in the order they were added, which matches the
/// ascending address sort produced by the kernel.
#derive(Debug, Eq)
pub(all) struct MemoryMap {
  regions : Array[MemoryRegion]
}

///|
/// Creates an empty memory map.
pub fn MemoryMap::new() -> MemoryMap {
  { regions: [], }
}

///|
/// Appends a region. Regions should be added in ascending address order.
pub fn MemoryMap::add(self : MemoryMap, region : MemoryRegion) -> Unit {
  self.regions.push(region)
}

///|
/// Number of mapped regions.
pub fn MemoryMap::count(self : MemoryMap) -> Int {
  self.regions.length()
}

///|
/// Total virtual memory in bytes across all regions.
pub fn MemoryMap::total_size(self : MemoryMap) -> Int {
  let mut total = 0
  for region in self.regions {
    total = total + region.size()
  }
  total
}

///|
/// Total anonymous (heap/stack/mmap) bytes.
pub fn MemoryMap::anonymous_size(self : MemoryMap) -> Int {
  let mut total = 0
  for region in self.regions {
    if region.is_anonymous() {
      total = total + region.size()
    }
  }
  total
}

///|
/// Returns the region that contains `addr`, or `None`.
pub fn MemoryMap::find_region(self : MemoryMap, addr : Int) -> MemoryRegion? {
  for region in self.regions {
    if addr >= region.start && addr < region.end {
      return Some(region)
    }
  }
  None
}

///|
/// Returns every region mapped from the given backing path.
pub fn MemoryMap::regions_by_path(
  self : MemoryMap,
  path : String,
) -> Array[MemoryRegion] {
  let result = []
  for region in self.regions {
    if region.path == Some(path) {
      result.push(region)
    }
  }
  result
}

///|
pub extend MemPerms with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MemPerms with Eq::{not_equal, equal}

///|
pub extend MemoryRegion with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MemoryRegion with Eq::{not_equal, equal}

///|
pub extend MemoryMap with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend MemoryMap with Eq::{not_equal, equal}