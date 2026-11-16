///|
/// ModelProcFS CLI — demonstrates the library by building a sample ProcTree,
/// running filters, computing aggregate stats, and printing a summary.
fn main {
  let tree = @modelprocfs.ProcTree::new()
  add_sample(tree, 1, 0, "systemd", @modelprocfs.ProcessState::Sleeping, 1, 102400, 8192)
  add_sample(tree, 2, 0, "kthreadd", @modelprocfs.ProcessState::Idle, 1, 0, 0)
  add_sample(tree, 7, 1, "worker", @modelprocfs.ProcessState::Running, 4, 65536, 16384)
  add_sample(tree, 42, 1, "sshd", @modelprocfs.ProcessState::Sleeping, 2, 32768, 4096)
  add_sample(tree, 99, 7, "worker-crash", @modelprocfs.ProcessState::Zombie, 1, 65536, 0)

  println("=== ModelProcFS Demo ===")
  let stats = @modelprocfs.compute_stats(tree)
  println("Total processes : \{stats.total_processes}")
  println("Total threads   : \{stats.total_threads}")
  println("Total VM (kB)   : \{stats.total_vm_kb}")
  println("Total RSS (kB)  : \{stats.total_rss_kb}")
  println("State breakdown:")

  let states = [
    @modelprocfs.ProcessState::Running,
    @modelprocfs.ProcessState::Sleeping,
    @modelprocfs.ProcessState::Idle,
    @modelprocfs.ProcessState::Zombie,
  ]
  for i = 0; i < states.length(); i = i + 1 {
    let label = states[i].label()
    let count = stats.count_for(states[i])
    if count > 0 {
      println("  \{label} : \{count}")
    }
  }

  println("")
  println("=== Filter: state=S (sleeping) ===")
  let sleeping = tree.find_by_state(@modelprocfs.ProcessState::Sleeping)
  for i = 0; i < sleeping.length(); i = i + 1 {
    let p = sleeping[i]
    println("  pid=\{p.pid} name=\{p.name} rss=\{p.vm_rss_kb}kB")
  }

  println("")
  println("=== Filter: threads >= 2 ===")
  let avg = @modelprocfs.ProcessFilter::new().with_min_threads(2)
  let result = tree.query(avg)
  for i = 0; i < result.length(); i = i + 1 {
    let p = result[i]
    println("  pid=\{p.pid} name=\{p.name} threads=\{p.threads}")
  }

  println("done.")
}

///|
fn add_sample(
  tree : @modelprocfs.ProcTree,
  pid : Int32,
  ppid : Int32,
  name : String,
  state : @modelprocfs.ProcessState,
  threads : Int32,
  vm_size_kb : Int32,
  vm_rss_kb : Int32,
) -> Unit {
  let p = try @modelprocfs.Process::new(
    pid~, ppid~, name~, state~, threads~, vm_size_kb~, vm_rss_kb~,
  ) catch {
    _ => return
  }
  tree.add_process(p) catch {
    _ => ()
  }
}