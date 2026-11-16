///|
test "file node carries text content" {
  let entry = @modelprocfs.ProcEntry::Text("hello")
  let node = @modelprocfs.ProcNode::File(name="status", content=entry)
  assert_eq(node.name(), "status")
  assert_true(node.is_file())
  assert_false(node.is_directory())
  assert_false(node.is_symlink())
  assert_eq(node.text_value(), Some("hello"))
}

///|
test "file node with key-value content" {
  let map = Map([("Name", "bash"), ("Pid", "42")])
  let entry = @modelprocfs.ProcEntry::KeyValue(map)
  let node = @modelprocfs.ProcNode::File(name="status", content=entry)
  assert_eq(node.name(), "status")
  assert_true(node.is_file())
  assert_eq(node.lookup("Pid"), Some("42"))
  assert_eq(node.lookup("Name"), Some("bash"))
  assert_eq(node.lookup("Nope"), None)
}

///|
test "directory node with children" {
  let root = @modelprocfs.ProcNode::Directory(name="proc", children=[])
  assert_eq(root.name(), "proc")
  assert_true(root.is_directory())
  assert_false(root.is_file())
  assert_eq(root.child_names(), [])
  root.add_child(@modelprocfs.ProcNode::Directory(name="1", children=[]))
  root.add_child(
    @modelprocfs.ProcNode::File(
      name="version",
      content=@modelprocfs.ProcEntry::Text("5.15.0"),
    ),
  )
  assert_eq(root.child_names(), ["1", "version"])
  let found = root.find_child("version")
  assert_true(found is Some(_))
  match found {
    Some(n) => {
      assert_eq(n.name(), "version")
      assert_true(n.is_file())
    }
    _ => abort("unreach")
  }
}

///|
test "find_child returns None for absent name" {
  let dir = @modelprocfs.ProcNode::Directory(name="fd", children=[])
  dir.add_child(
    @modelprocfs.ProcNode::File(
      name="0",
      content=@modelprocfs.ProcEntry::Text("socket:[123]"),
    ),
  )
  assert_eq(dir.find_child("0").unwrap().name(), "0")
  assert_eq(dir.find_child("3"), None)
}

///|
test "find_child on file returns None" {
  let f = @modelprocfs.ProcNode::File(
    name="version",
    content=@modelprocfs.ProcEntry::Text("x"),
  )
  assert_eq(f.find_child("anything"), None)
}

///|
test "find_child on symlink returns None" {
  let s = @modelprocfs.ProcNode::Symlink(name="fd", target="/proc/1/fd")
  assert_eq(s.find_child("anything"), None)
}

///|
test "symlink node properties" {
  let s = @modelprocfs.ProcNode::Symlink(name="fd", target="/proc/1/fd")
  assert_eq(s.name(), "fd")
  assert_true(s.is_symlink())
  assert_false(s.is_directory())
  assert_false(s.is_file())
}

///|
test "table entry content" {
  let rows = [["clk", "cpu0", "cpu1"], ["MHZ", "2400", "2400"]]
  let entry = @modelprocfs.ProcEntry::Table(rows)
  let node = @modelprocfs.ProcNode::File(name="cpuinfo", content=entry)
  assert_true(node.is_file())
}

///|
test "text_value and lookup on wrong entry type" {
  let map = Map([("a", "1")])
  let kv = @modelprocfs.ProcEntry::KeyValue(map)
  assert_eq(kv.text_value(), None)
  let txt = @modelprocfs.ProcEntry::Text("x")
  assert_eq(txt.lookup("a"), None)
}

///|
test "add_child on non-directory is no-op" {
  let f = @modelprocfs.ProcNode::File(
    name="f",
    content=@modelprocfs.ProcEntry::Text("x"),
  )
  f.add_child(
    @modelprocfs.ProcNode::File(
      name="nope",
      content=@modelprocfs.ProcEntry::Text("y"),
    ),
  )
  assert_true(f.is_file())
}

///|
test "child_names on non-directory returns empty" {
  let f = @modelprocfs.ProcNode::File(
    name="f",
    content=@modelprocfs.ProcEntry::Text("x"),
  )
  assert_eq(f.child_names(), [])
}

///|
test "text and key-value entries equality" {
  let a = @modelprocfs.ProcEntry::Text("abc")
  let b = @modelprocfs.ProcEntry::Text("abc")
  let c = @modelprocfs.ProcEntry::Text("xyz")
  assert_eq(a, b)
  assert_false(a == c)
}
