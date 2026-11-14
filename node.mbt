///|
/// The content carried by a leaf node in the `/proc` tree.
#derive(Debug, Eq)
pub(all) enum ProcEntry {
  Text(String)
  KeyValue(Map[String, String])
  Table(Array[Array[String]])
}

///|
/// A node in the virtual `/proc` filesystem.
///
/// `Directory` children are stored in insertion order. `Symlink` carries a
/// target path as a string; resolution is handled by `ProcTree`.
#derive(Debug, Eq)
pub(all) enum ProcNode {
  File(name~ : String, content~ : ProcEntry)
  Directory(name~ : String, children~ : Array[ProcNode])
  Symlink(name~ : String, target~ : String)
}

///|
/// Returns the basename of this node.
pub fn ProcNode::name(self : ProcNode) -> String {
  match self {
    File(name~, ..) => name
    Directory(name~, ..) => name
    Symlink(name~, ..) => name
  }
}

///|
pub fn ProcNode::is_directory(self : ProcNode) -> Bool {
  self is Directory(..)
}

///|
pub fn ProcNode::is_file(self : ProcNode) -> Bool {
  self is File(..)
}

///|
pub fn ProcNode::is_symlink(self : ProcNode) -> Bool {
  self is Symlink(..)
}

///|
/// Looks up a direct child by name. Returns `None` for non-directory nodes
/// or when the named child is absent.
pub fn ProcNode::find_child(self : ProcNode, name : String) -> ProcNode? {
  match self {
    Directory(children~, ..) => {
      for child in children {
        if child.name() == name {
          return Some(child)
        }
      }
      None
    }
    _ => None
  }
}

///|
pub fn ProcEntry::is_text(self : ProcEntry) -> Bool {
  self is Text(_)
}

///|
pub fn ProcEntry::text_value(self : ProcEntry) -> String? {
  match self {
    Text(s) => Some(s)
    _ => None
  }
}

///|
/// Returns `None` when the entry is not key-value, or when the key is absent.
pub fn ProcEntry::lookup(self : ProcEntry, key : String) -> String? {
  match self {
    KeyValue(map) => map.get(key)
    _ => None
  }
}

///|
/// Delegates to the inner `ProcEntry::text_value` when this is a `File`.
pub fn ProcNode::text_value(self : ProcNode) -> String? {
  match self {
    File(content~, ..) => content.text_value()
    _ => None
  }
}

///|
/// Delegates to the inner `ProcEntry::lookup` when this is a `File`.
pub fn ProcNode::lookup(self : ProcNode, key : String) -> String? {
  match self {
    File(content~, ..) => content.lookup(key)
    _ => None
  }
}

///|
pub fn ProcNode::child_names(self : ProcNode) -> Array[String] {
  match self {
    Directory(children~, ..) => {
      let names = []
      for child in children {
        names.push(child.name())
      }
      names
    }
    _ => []
  }
}

///|
/// Appends a child node into a directory. No-op for non-directories.
pub fn ProcNode::add_child(self : ProcNode, child : ProcNode) -> Unit {
  match self {
    Directory(children~, ..) => children.push(child)
    _ => ()
  }
}

///|
/// Removes a direct child by name. Idempotent when the child is absent
/// or when called on a non-directory.
pub fn ProcNode::remove_child(self : ProcNode, name : String) -> Unit {
  match self {
    Directory(children~, ..) => {
      let mut index = -1
      for i, child in children {
        if child.name() == name {
          index = i
        }
      }
      if index >= 0 {
        ignore(children.remove(index))
      }
    }
    _ => ()
  }
}

///|
pub extend ProcEntry with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcEntry with Eq::{not_equal, equal}

///|
pub extend ProcNode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ProcNode with Eq::{not_equal, equal}