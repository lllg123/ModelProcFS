///|
test "serialize single region with path" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=false, execute=true, shared=false, private=true,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x7f000000, end=0x7f001000,
      perms=perms, offset=0,
      dev_major=8, dev_minor=1, inode=12345,
      path=Some("/usr/lib/libc.so"),
    ),
  )
  let s = @modelprocfs.serialize_maps(map)
  assert_true(s.has_prefix("7f000000-7f001000 r-xp 0 8:1 12345"))
  assert_true(s.contains("/usr/lib/libc.so"))
}

///|
test "serialize anonymous region omits path" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=false, private=true,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0x1000, end=0x2000,
      perms=perms, offset=0x1000,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  let s = @modelprocfs.serialize_maps(map)
  assert_eq(s, "1000-2000 rw-p 1000 0:0 0")
}

///|
test "serialize multiple regions joined by newline" {
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
  let s = @modelprocfs.serialize_maps(map)
  assert_true(s.contains("\n"))
  assert_eq(s.split("\n").length(), 2)
}

///|
test "serialize empty map returns empty string" {
  let map = @modelprocfs.MemoryMap::new()
  assert_eq(@modelprocfs.serialize_maps(map), "")
}

///|
test "serialize shared region uses s flag" {
  let perms = @modelprocfs.MemPerms::new(
    read=true, write=true, execute=false, shared=true, private=false,
  )
  let map = @modelprocfs.MemoryMap::new()
  map.add(
    @modelprocfs.MemoryRegion::new(
      start=0, end=0x1000, perms=perms, offset=0,
      dev_major=0, dev_minor=0, inode=0, path=None,
    ),
  )
  let s = @modelprocfs.serialize_maps(map)
  assert_true(s.contains("rw-s"))
}