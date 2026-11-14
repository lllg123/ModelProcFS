///|
/// Formats an integer as lowercase hexadecimal without the `0x` prefix.
fn format_hex(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let hex = "0123456789abcdef"
  let chars = []
  let mut n = value
  while n > 0 {
    chars.push(hex[n & 0xF])
    n = n >> 4
  }
  let mut result = ""
  for i = chars.length() - 1; i >= 0; i = i - 1 {
    result = result + chars[i].to_string()
  }
  result
}

///|
/// Serializes one memory region as a line matching `/proc/[pid]/maps` output.
fn serialize_region_line(region : MemoryRegion) -> String {
  let s = "\{format_hex(region.start)}-\{format_hex(region.end)} "
  s = s + "\{region.perms.to_string()} "
  s = s + "\{format_hex(region.offset)} "
  s = s + "\{format_hex(region.dev_major)}:\{format_hex(region.dev_minor)} "
  s = s + "\{region.inode}"
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