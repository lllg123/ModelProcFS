///|
/// Serializes a `Process` into the format of `/proc/[pid]/status`.
pub fn serialize_status(process : Process) -> String {
  let lines = []
  lines.push("Name:\t\{process.name}")
  lines.push("State:\t\{process.state.label()} (\{process.name})")
  lines.push("Tgid:\t\{process.pid}")
  lines.push("Pid:\t\{process.pid}")
  lines.push("PPid:\t\{process.ppid}")
  lines.push("Threads:\t\{process.threads}")
  lines.push("VmSize:\t  \{process.vm_size_kb} kB")
  lines.push("VmRSS:\t  \{process.vm_rss_kb} kB")
  let mut result = ""
  for i = 0; i < lines.length(); i = i + 1 {
    result = result + lines[i]
    if i < lines.length() - 1 {
      result = result + "\n"
    }
  }
  result
}