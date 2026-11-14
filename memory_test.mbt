///|
test "construct valid memory region" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=true, shared=false, private=true,
  )
  let r = @modelprocfs.MemoryRegion::new(
    start=0x7f000000,
    end=0x7f001000,
    perms=perms,
    offset=0,
    dev_major=8,
    dev_minor=1,
    inode=12345,
    path=Some("/usr/lib/libc.so"),
  )
  assert_eq(r.start, 0x7f000000)
  assert_eq(r.size(), 0x1000)
  assert_eq(r.path, Some("/usr/lib/libc.so"))
  assert_false(r.is_anonymous())
}

///|
test "anonymous region has no path" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=false, private=true,
  )
  let r = @modelprocfs.MemoryRegion::new(
    start=0x7fff0000,
    end=0x7fff2000,
    perms=perms,
    offset=0,
    dev_major=0,
    dev_minor=0,
    inode=0,
    path=None,
  )
  assert_true(r.is_anonymous())
  assert_eq(r.size(), 0x2000)
}

///|
test "reject start >= end" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=false, shared=false, private=true,
  )
  try {
    let _ = @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x1000,
      perms=perms, offset=0,
      dev_major=0, dev_minor=0, inode=0, path=None,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidMemoryRange(0x1000, 0x1000) => ()
    _ => abort("expected InvalidMemoryRange")
  }
}

///|
test "memperms to_string" {
  let p = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=true, shared=false, private=true,
  )
  assert_eq(p.to_string(), "r-xp")
  let p2 = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=true, private=false,
  )
  assert_eq(p2.to_string(), "rw-s")
}

///|
test "memperms from_string round-trip" {
  let codes = ["r--p", "rw-p", "r-xp", "rwxp", "r--s", "rw-s"]
  for code in codes {
    let p = @modelprocfs.MemPerms::from_string(code).unwrap()
    assert_eq(p.to_string(), code)
  }
}

///|
test "memperms from_string returns None for bogus input" {
  assert_eq(@modelprocfs.MemPerms::from_string(""), None)
  assert_eq(@modelprocfs.MemPerms::from_string("r"), None)
  assert_eq(@modelprocfs.MemPerms::from_string("r-x"), None)
  assert_eq(@modelprocfs.MemPerms::from_string("r-xq"), None)
}

///|
test "memperms shared+private raises" {
  try {
    let _ = @modelprocfs.MemPerms::new(
      read=true, write=false, execute=false, shared=true, private=true,
    )
    abort("expected ProcFSError")
  } catch {
    @modelprocfs.ProcFSError::InvalidMemoryPerms(_) => ()
    _ => abort("expected InvalidMemoryPerms")
  }
}

///|
test "memory map total and anonymous size" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=false, shared=false, private=true,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0, end=0x1000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=1, path=Some("/a"),
    ),
  )
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x3000, perms=perms, offset=0,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  assert_eq(map.count(), 2)
  assert_eq(map.total_size(), 0x3000)
  assert_eq(map.anonymous_size(), 0x2000)
}

///|
test "find region by address" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=false, private=true,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x2000, perms=perms, offset=0,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x2000, end=0x3000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=2, path=Some("/lib/x.so"),
    ),
  )
  assert_true(map.find_region(0x1500) is Some(_))
  assert_true(map.find_region(0x2500) is Some(_))
  assert_eq(map.find_region(0x0), None)
  assert_eq(map.find_region(0x3000), None)
}

///|
test "regions_by_path groups matching regions" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=true, shared=false, private=true,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0, end=0x1000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=1, path=Some("/usr/lib/libc.so"),
    ),
  )
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x2000, perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=2, path=Some("/usr/lib/libm.so"),
    ),
  )
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x2000, end=0x3000, perms=perms, offset=0x1000,
      dev_major=8, dev_minor=1, inode=1, path=Some("/usr/lib/libc.so"),
    ),
  )
  let matches = map.regions_by_path("/usr/lib/libc.so")
  assert_eq(matches.length(), 2)
  for r in matches {
    assert_eq(r.path, Some("/usr/lib/libc.so"))
  }
  let empty = map.regions_by_path("/nope")
  assert_eq(empty.length(), 0)
}

///|
test "offset can be zero" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=false, shared=false, private=true,
  )
  let r = @modelprocfs.MemoryRegion::new(
    start=0, end=0x1000, perms=perms, offset=0,
    dev_major=0, dev_minor=0, inode=0, path=None,
  )
  assert_eq(r.offset, 0)
  assert_eq(r.dev_major, 0)
  assert_eq(r.dev_minor, 0)
  assert_eq(r.inode, 0)
}