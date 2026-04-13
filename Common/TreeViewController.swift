import AppKit

class TreeViewController: NSObject, DataSource {
	private var tree: [String: [TreeNode]] = [:]
	private var filteredTree: [String: [TreeNode]]? = nil
	
	// MARK: - Init
	
	init(_ data: [ArchiveEntry]) {
		var rv: [String: [TreeNode]] = ["": []]
		// Copy actual entries
		for entry in data {
			let newNode = TreeNode(entry)
			if rv[newNode.dirname] == nil {
				rv[newNode.dirname] = []
			}
			rv[newNode.dirname]!.append(newNode)
		}
		// Create fake entries (directory nodes which arent present in the archive)
		for path in Array(rv.keys) {
			guard !path.isEmpty else {
				continue
			}
			let fakeEntry = rv[path]!.first!.entry
			var fakeNode = TreeNode(fakeEntry, fakePath: path)
			// no parent exists, create all intermediate
			while rv[fakeNode.dirname] == nil {
				rv[fakeNode.dirname] = [fakeNode]
				fakeNode = TreeNode(fakeEntry, fakePath: fakeNode.dirname)
			}
			// a parent exists, insert into existing list
			if !rv[fakeNode.dirname]!.contains(where: { $0.fullpath == fakeNode.fullpath }) {
				rv[fakeNode.dirname]!.insertSorted(fakeNode, by: \.entry.index)
			}
		}
		// remove duplicates (e.g. `tar --append`)
//		let dirsOnly = Set(rv.keys)
		var dups = Set<String>()
		rv.keys.forEach { k in
			dups.removeAll(keepingCapacity: true)
			// reversed because latter ones overwrite earlier ones
			for (i, node) in rv[k]!.enumerated().reversed() {
				// TODO: should we show duplicate files?
//				guard dirsOnly.contains(node.fullpath) else {
//					continue // skip files, only de-dup dirs
//				}
				if dups.contains(node.fullpath) {
					rv[k]!.remove(at: i)
				} else {
					dups.insert(node.fullpath)
				}
			}
		}
		tree = rv
	}
	
	// MARK: - Data Source
	
	func rowEntry(_ item: Any) -> ArchiveEntry {
		(item as! TreeNode).entry
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		(filteredTree ?? tree)[(item as? TreeNode)?.fullpath ?? ""]?.count ?? 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		(filteredTree ?? tree)[(item as? TreeNode)?.fullpath ?? ""]![index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		tree[(item as? TreeNode)?.fullpath ?? ""]?.isEmpty == false // expandable doesnt depend on filter
	}
	
	// MARK: - Sort
	
	var sortDescriptors: [NSSortDescriptor] = [] {
		willSet { tree.keys.forEach { tree[$0]!.sort(with: newValue) } }
	}
	
	// MARK: - Search
	
	var searchFilter: String = "" {
		willSet {
			if newValue != searchFilter, !newValue.isEmpty {
				tree.values.forEach { list in list.forEach { node in
					node.matchSearch = node.name.contains(newValue)
				}}
			}
		}
	}
	
	// MARK: - Filter
	
	var filetypeFilter: TypeFilter? = nil // ignored
	
	/// Sets `filteredChildren` for all nodes where some child has `matchSearch` flag set.
	func performFilter() {
		guard isSearchActive else {
			filteredTree = nil
			return
		}
		// Reverse order to populate children first (so they exist for later parents).
		// Parents must be enabled, if at least one child is active.
		filteredTree = [:]
		for path in tree.keys.sorted().reversed() {
			filteredTree![path] = tree[path]?.filter {
				$0.matchSearch || filteredTree![$0.fullpath]?.isEmpty == false
			}
		}
	}
}


// MARK: - Data Entry

class TreeNode: HasArchiveEntry, CustomDebugStringConvertible {
	var debugDescription: String { "TreeNode('\(fullpath)')" }
	
	/// Reference to an `LibArchive` entry (unless `isFake == true`).
	let entry: ArchiveEntry
	/// Normalized path without trailing slash. In most cases equivalent to `entry.path`.
	let fullpath: String
	/// Last path compenent. Filename or directory name.
	/// Top-most entries with absolute paths start with a slash.
	let name: String
	/// Directory path of the item.
	let dirname: String
	
	/// `true`if `entry` was generated on the fly to create a directory structure
	let isFake: Bool
	/// `true` if search string matches this entry (parents may still be `false`).
	var matchSearch: Bool = false
	
	init(_ entry: ArchiveEntry, fakePath: String? = nil) {
		let path = ((fakePath ?? entry.path) as NSString)
		let dir = path.deletingLastPathComponent
		// absolute paths
		if dir == "/" {
			self.name = "/" + path.lastPathComponent
			self.dirname = ""
		} else {
			self.name = path.lastPathComponent
			self.dirname = dir
		}
		self.fullpath = dirname.isEmpty ? name : (dirname + "/" + name)
		self.isFake = fakePath != nil
		self.entry = isFake ? ArchiveEntry(index: entry.index, path: fullpath, size: 0, perm: Perm.init(raw: 0), filetype: .Directory, modified: 0) : entry
	}
}

extension RangeReplaceableCollection {
	/// Binary search insert in already sorted collection.
	mutating func insertSorted<T: Comparable>(_ value: Element, by predicate: KeyPath<Element, T>) {
		let needle = value[keyPath: predicate]
		var slice : SubSequence = self[...]
		while !slice.isEmpty {
			let middle = slice.index(
				slice.startIndex,
				offsetBy: slice.count / 2
			)
			if needle > slice[middle][keyPath: predicate] {
				slice = slice[index(after: middle)...]
			} else {
				slice = slice[..<middle]
			}
		}
		self.insert(value, at: slice.startIndex)
	}
}
