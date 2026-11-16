///|
/// Parses a hexadecimal string (without `0x` prefix) into an `Int`.
fn parse_hex(s : String) -> Int32 raise ProcFSError {
  if s == "" {
    raise ProcFSError::ParseError("empty hex string")
  }
  let mut n = 0
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    let digit = match ch {
      '0' => 0
      '1' => 1
      '2' => 2
      '3' => 3
      '4' => 4
      '5' => 5
      '6' => 6
      '7' => 7
      '8' => 8
      '9' => 9
      'a' => 10
      'b' => 11
      'c' => 12
      'd' => 13
      'e' => 14
      'f' => 15
      'A' => 10
      'B' => 11
      'C' => 12
      'D' => 13
      'E' => 14
      'F' => 15
      _ => raise ProcFSError::ParseError("invalid hex char: \{ch}")
    }
    n = n * 16 + digit
  }
  n
}

///|
/// Parses the output of `serialize_status` back into a `Process`.
///
/// Expects tab-separated key-value lines matching `/proc/[pid]/status` format.
pub fn parse_status(text : String) -> Process raise ProcFSError {
  if text == "" {
    raise ProcFSError::ParseError("empty status text")
  }
  let lines = split_lines(text)
  let mut pid = 0
  let mut ppid = 0
  let mut name = ""
  let mut state = ProcessState::Sleeping
  let mut threads = 0
  let mut vm_size_kb = 0
  let mut vm_rss_kb = 0
  let mut found_name = false
  let mut found_pid = false
  for i = 0; i < lines.length(); i = i + 1 {
    let kv = split_field(lines[i])
    match kv {
      Some((key, value)) =>
        match key {
          "Name" => {
            name = value
            found_name = true
          }
          "Pid" => {
            pid = parse_int_or_raise(value, "Pid")
            found_pid = true
          }
          "PPid" => ppid = parse_int_or_raise(value, "PPid")
          "State" =>
            match parse_state_value(value) {
              Some(s) => state = s
              None => raise ProcFSError::ParseError("invalid State: \{value}")
            }
          "Threads" => threads = parse_int_or_raise(value, "Threads")
          "VmSize" => vm_size_kb = parse_kb_or_raise(value, "VmSize")
          "VmRSS" => vm_rss_kb = parse_kb_or_raise(value, "VmRSS")
          _ => ()
        }
      None => ()
    }
  }
  if !found_name || !found_pid {
    raise ProcFSError::ParseError("missing required fields in status")
  }
  Process::new(pid~, ppid~, name~, state~, threads~, vm_size_kb~, vm_rss_kb~)
}

///|
/// Parses the output of `serialize_maps` back into a `MemoryMap`.
pub fn parse_maps(text : String) -> MemoryMap raise ProcFSError {
  let map = MemoryMap::new()
  if text == "" {
    return map
  }
  let lines = split_lines(text)
  for i = 0; i < lines.length(); i = i + 1 {
    let region = parse_maps_line(lines[i])
    map.add(region)
  }
  map
}

///|
/// Parses a single `/proc/[pid]/fd/` symlink target into an `FdType`.
pub fn parse_fd_symlink(target : String) -> FdType {
  if target.has_prefix("socket:[") {
    Socket("", "", "")
  } else if target.has_prefix("pipe:[") {
    Pipe
  } else if target == "anon_inode:[eventfd]" {
    EventFd
  } else if target == "anon_inode:[timerfd]" {
    TimerFd
  } else if target == "anon_inode:[signalfd]" {
    SignalFd
  } else if target == "anon_inode:[eventpoll]" {
    Epoll
  } else if target == "anon_inode:inotify" {
    Inotify
  } else if target.has_prefix("anon_inode:") {
    AnonymousInode
  } else {
    RegularFile(target)
  }
}

///|
/// Splits text into lines on `\n`.
fn split_lines(text : String) -> Array[String] {
  let lines = []
  let mut start = 0
  for i = 0; i < text.length(); i = i + 1 {
    if text[i] == '\n' {
      lines.push(text[start:i].to_owned())
      start = i + 1
    }
  }
  if start < text.length() {
    lines.push(text[start:].to_owned())
  }
  lines
}

///|
/// Splits a `Key:\tValue` line into `(key, value)`.
fn split_field(line : String) -> (String, String)? {
  let colon = find_char(line, ':')
  match colon {
    Some(idx) => {
      let raw = line[idx + 1:].to_owned()
      if raw == "" {
        Some((line[:idx].to_owned(), ""))
      } else if raw[0] == '\t' {
        Some((line[:idx].to_owned(), raw[1:].to_owned()))
      } else {
        Some((line[:idx].to_owned(), raw))
      }
    }
    None => None
  }
}

///|
/// Extracts the state char from `S (name)`.
fn parse_state_value(value : String) -> ProcessState? {
  if value.length() >= 1 {
    ProcessState::from_code(value[:1].to_owned())
  } else {
    None
  }
}

///|
/// Parses `  NNN kB` or `NNN kB` and returns NNN.  On failure raises.
fn parse_kb_or_raise(value : String, field : String) -> Int32 raise ProcFSError {
  let trimmed = trim_left(value)
  let kb_idx = find_str(trimmed, " kB")
  let num = match kb_idx {
    Some(n) => trimmed[:n].to_owned()
    None => trimmed
  }
  @string.parse_int(num) catch {
    _ => raise ProcFSError::ParseError("invalid \{field}: \{value}")
  }
}

///|
fn parse_int_or_raise(
  value : String,
  field : String,
) -> Int32 raise ProcFSError {
  @string.parse_int(value) catch {
    _ => raise ProcFSError::ParseError("invalid \{field}: \{value}")
  }
}

///|
/// Strips leading spaces and tabs.
fn trim_left(s : String) -> String {
  let mut i = 0
  while i < s.length() && (s[i] == ' ' || s[i] == '\t') {
    i = i + 1
  }
  if i >= s.length() {
    ""
  } else {
    s[i:].to_owned()
  }
}

///|
/// Finds the first occurrence of a character, or None.
fn find_char(s : String, ch : Char) -> Int32? {
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int() == ch.to_int() {
      return Some(i)
    }
  }
  None
}

///|
/// Finds the first occurrence of a substring, or None.
fn find_str(s : String, needle : String) -> Int32? {
  if needle.length() > s.length() {
    return None
  }
  for i = 0; i <= s.length() - needle.length(); i = i + 1 {
    let mut matched = true
    for j = 0; j < needle.length(); j = j + 1 {
      if s[i + j] != needle[j] {
        matched = false
      }
    }
    if matched {
      return Some(i)
    }
  }
  None
}

///|
/// Parses one line of `/proc/[pid]/maps` into a `MemoryRegion`.
fn parse_maps_line(line : String) -> MemoryRegion raise ProcFSError {
  let parts = split_space(line)
  let part_count = parts.length()
  if part_count < 5 {
    raise ProcFSError::ParseError("invalid maps line: \{line}")
  }
  let addr_parts = split_on_char(parts[0], '-')
  if addr_parts.length() != 2 {
    raise ProcFSError::ParseError("invalid address range: \{parts[0]}")
  }
  let start = parse_hex(addr_parts[0])
  let end = parse_hex(addr_parts[1])
  let perms = match MemPerms::from_string(parts[1]) {
    Some(p) => p
    None => raise ProcFSError::ParseError("invalid perms: \{parts[1]}")
  }
  let offset = parse_hex(parts[2])
  let dev_parts = split_on_char(parts[3], ':')
  if dev_parts.length() != 2 {
    raise ProcFSError::ParseError("invalid dev: \{parts[3]}")
  }
  let dev_major = parse_hex(dev_parts[0])
  let dev_minor = parse_hex(dev_parts[1])
  let inode = @string.parse_int(parts[4]) catch {
    _ => raise ProcFSError::ParseError("invalid inode: \{parts[4]}")
  }
  let path = if part_count >= 6 { Some(rejoin_path(parts, 5)) } else { None }
  MemoryRegion::new(
    start~,
    end~,
    perms~,
    offset~,
    dev_major~,
    dev_minor~,
    inode~,
    path~,
  )
}

///|
/// Splits a string on a single character delimiter, returning owned Strings.
fn split_on_char(s : String, delimiter : Char) -> Array[String] {
  let parts = []
  let mut start = 0
  for i = 0; i < s.length(); i = i + 1 {
    if s[i].to_int() == delimiter.to_int() {
      parts.push(s[start:i].to_owned())
      start = i + 1
    }
  }
  parts.push(s[start:].to_owned())
  parts
}

///|
/// Splits a string on one or more spaces/tabs.
fn split_space(s : String) -> Array[String] {
  let parts = []
  let mut i = 0
  while i < s.length() && (s[i] == ' ' || s[i] == '\t') {
    i = i + 1
  }
  while i < s.length() {
    let mut j = i
    while j < s.length() && s[j] != ' ' && s[j] != '\t' {
      j = j + 1
    }
    parts.push(s[i:j].to_owned())
    i = j
    while i < s.length() && (s[i] == ' ' || s[i] == '\t') {
      i = i + 1
    }
  }
  parts
}

///|
/// Rejoins parts from `start` index with spaces.
fn rejoin_path(parts : Array[String], start : Int32) -> String {
  let mut result = ""
  for i = start; i < parts.length(); i = i + 1 {
    if i > start {
      result = result + " "
    }
    result = result + parts[i]
  }
  result
}
