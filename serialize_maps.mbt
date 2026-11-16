///|
/// Formats an integer as lowercase hexadecimal without the `0x` prefix.
fn format_hex(value : Int32) -> String {
  if value == 0 {
    return "0"
  }
  let nibbles = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f",
  ]
  let mut result = ""
  let mut n = value
  while n > 0 {
    result = nibbles[n & 0xF] + result
    n = n >> 4
  }
  result
}

///|
/// Serializes one memory region as a line matching `/proc/[pid]/maps` output.
fn serialize_region_line(region : MemoryRegion) -> String {
  let start_str = format_hex(region.start)
  let end_str = format_hex(region.end)
  let perms_str = region.perms.to_string()
  let offset_str = format_hex(region.offset)
  let dev_str = "\{format_hex(region.dev_major)}:\{format_hex(region.dev_minor)}"
  let s = "\{start_str}-\{end_str} \{perms_str} \{offset_str} \{dev_str} \{region.inode}"
  match region.path {
    Some(p) => s + "          " + p
    None => s
  }
}

///|
/// Serializes a `MemoryMap` into the multi-line format of `/proc/[pid]/maps`.
///
/// Each region is one line. Regions are joined with `\n`.  An empty map
/// produces an empty string.
pub fn serialize_maps(map : MemoryMap) -> String {
  if map.count() == 0 {
    return ""
  }
  let lines = []
  for i = 0; i < map.regions.length(); i = i + 1 {
    lines.push(serialize_region_line(map.regions[i]))
  }
  let mut result = ""
  for i = 0; i < lines.length(); i = i + 1 {
    result = result + lines[i]
    if i < lines.length() - 1 {
      result = result + "\n"
    }
  }
  result
}
