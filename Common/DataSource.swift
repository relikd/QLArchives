import AppKit

// Data loading – NSOutlineView data source

extension ArchiveController {
	/// This postpones tree data creation until TreeView is in use.
	///
	/// Safe to call multiple times (NO-OP after `tree` is populated).
	/// - Depends on `rows` and `viewMode`.
	/// - Called from `load()` and `changeViewMode()`.
	func initTreeData(isInitial: Bool = false) {
		guard tree.isEmpty && viewMode == .tree else {
			return
		}
		if isInitial {
			tree = TreeNode.fromRows(rows) // row order unchanged
		} else {
			// sorting needed in case an archive entry overrides a previous entry
			tree = TreeNode.fromRows(rows.sorted(by: { $0.entry.index < $1.entry.index }))
		}
	}
	
	func rowEntry(_ item: Any) -> ArchiveEntry? {
		switch viewMode {
		case .list: (item as? Row)?.entry
		case .tree: (item as? TreeNode)?.entry
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		switch viewMode {
		case .list: (filteredRows ?? rows).count
		case .tree: (filteredTree ?? tree)[(item as? TreeNode)?.fullpath ?? ""]?.count ?? 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		switch viewMode {
		case .list: (filteredRows ?? rows)[index]
		case .tree: (filteredTree ?? tree)[(item as? TreeNode)?.fullpath ?? ""]![index]
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		switch viewMode {
		case .list: false
		case .tree: tree[(item as? TreeNode)?.fullpath ?? ""]?.isEmpty == false // expandable doesnt depend on filter
		}
	}
}


// MARK: - Perform Filter

extension ArchiveController {
	/// Recompute filter and reload outline view.
	func performFilterAndReload(restoreCollapsible: Bool = true) {
		switch viewMode {
		case .list: performFilterOnList()
		case .tree: performFilterOnTree()
		}
		outline.reloadData()
		if restoreCollapsible {
			restoreCollapsibleState()
		}
	}
	
	/// Sets `filteredRows`
	func performFilterOnList() {
		switch (searchActive, filterActive) {
		case (true, true): filteredRows = rows.filter { $0.matchSearch && $0.matchFilter }
		case (true, _): filteredRows = rows.filter { $0.matchSearch }
		case (_, true): filteredRows = rows.filter { $0.matchFilter }
		case (_, _): filteredRows = nil
		}
	}
	
	/// Sets `filteredChildren` for all nodes where some child has `matchSearch` flag set.
	func performFilterOnTree() {
		guard searchActive else {
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


protocol HasArchiveEntry {
	var entry: ArchiveEntry { get }
}


// MARK: - List View

class Row: HasArchiveEntry {
	let entry: ArchiveEntry
	var matchSearch = false
	var matchFilter = false
	
	init(entry: ArchiveEntry) {
		self.entry = entry
	}
}


// MARK: - Tree View

class TreeNode: HasArchiveEntry, CustomDebugStringConvertible {
	var debugDescription: String { "TreeNode('\(fullpath)')" }
	
	let fullpath: String
	let name: String
	private let dirname: String
	
	let entry: ArchiveEntry
	let isFake: Bool
	// cant reuse row search filter bebecause some TreeNodes dont have a row reference
	var matchSearch: Bool = false
	
	init(_ path: String, entry: ArchiveEntry, isFake: Bool = false) {
		let path = (path as NSString)
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
		self.isFake = isFake
		self.entry = isFake ? ArchiveEntry(index: entry.index, path: fullpath, size: 0, perm: Perm.init(raw: 0), filetype: .Directory, modified: 0) : entry
	}
	
	/// Convert `Row` data structure into `TreeNode` structure while keeping references to `Row`
	static func fromRows(_ rows: [Row]) -> [String: [TreeNode]] {
		var rv: [String: [TreeNode]] = ["": []]
		// Copy actual entries
		for row in rows {
			let newNode = TreeNode(row.entry.path, entry: row.entry)
			if rv[newNode.dirname] == nil {
				rv[newNode.dirname] = []
			}
			rv[newNode.dirname]!.append(newNode)
		}
		// Create fake entries (directory nodes which arent present in the archive)
		var needsSorting = Set<String>()
		for path in Array(rv.keys) {
			guard !path.isEmpty else {
				continue
			}
			let fakeEntry = rv[path]!.first!.entry
			var fakeNode = TreeNode(path, entry: fakeEntry, isFake: true)
			// no parent exists, create all intermediate
			while rv[fakeNode.dirname] == nil {
				rv[fakeNode.dirname] = [fakeNode]
				fakeNode = TreeNode(fakeNode.dirname, entry: fakeEntry, isFake: true)
			}
			// a parent exists, insert into existing list
			if !rv[fakeNode.dirname]!.contains(where: { $0.fullpath == fakeNode.fullpath }) {
				rv[fakeNode.dirname]!.append(fakeNode)
				needsSorting.insert(fakeNode.dirname)
			}
		}
		// otherwise, fake nodes are always sorted last
		for path in needsSorting {
			rv[path]!.sort { $0.entry.index < $1.entry.index }
		}
		return rv
	}
}
