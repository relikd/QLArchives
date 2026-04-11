import AppKit

// Data loading – NSOutlineView data source

extension ArchiveController {
	/// This postpones tree data creation until TreeView is in use.
	///
	/// Safe to call multiple times (no-op after `tree` is populated).
	/// - Depends on `rows` and `viewMode`.
	/// - Called from `load()` and `changeViewMode()`.
	func initTreeData(isInitial: Bool = false) {
		guard tree == nil && viewMode == .tree else {
			return
		}
		if isInitial {
			tree = TreeNode(rows: rows) // row order unchanged
		} else {
			// sorting needed in case an archive entry overrides a previous entry
			tree = TreeNode(rows: rows.sorted(by: { $0.entry.index < $1.entry.index }))
		}
	}
	
	/// Recompute `filteredRows` and reload outline view
	func performFilterAndReload() {
		switch (searchActive, filterActive) {
		case (true, true): filteredRows = rows.filter { $0.matchSearch && $0.matchFilter }
		case (true, _): filteredRows = rows.filter { $0.matchSearch }
		case (_, true): filteredRows = rows.filter { $0.matchFilter }
		case (_, _): filteredRows = nil
		}
		// TODO: filter tree
		outline.reloadData()
	}
	
	func rowEntry(_ item: Any) -> ArchiveEntry? {
		switch viewMode {
		case .list: (item as? Row)?.entry
		case .tree: (item as? TreeNode)?.row?.entry
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		switch viewMode {
		case .list: filteredRows?.count ?? rows.count
		case .tree: (item as? TreeNode ?? tree)?.children.count ?? 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		switch viewMode {
		case .list: filteredRows?[index] ?? rows[index]
		case .tree: (item as? TreeNode ?? tree).children[index]
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		switch viewMode {
		case .list: false
		case .tree: !(item as? TreeNode ?? tree).children.isEmpty
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

class TreeNode: HasArchiveEntry {
	let name: String
	weak var row: Row? // not ArchiveEntry, to reuse the search filter
	var children: [TreeNode] = []
	weak var parent: TreeNode?
	
	var entry: ArchiveEntry { row?.entry ?? ArchiveEntry(index: 0, path: name, size: 0, perm: Perm.init(raw: 0), filetype: .Directory, modified: 0) }
	
	init(name: String = "", parent: TreeNode) {
		self.name = name
		self.parent = parent
	}
	
	/// Convert `Row` data structure into `TreeNode` structure while keeping references to `Row`
	init(rows: [Row]) {
		self.name = ""
		for row in rows {
			var node = self
			for part in row.entry.path.split(separator: "/") {
				if let child = node.children.first(where: { $0.name == part }) {
					node = child
				} else {
					let newNode = TreeNode(name: String(part), parent: node)
					node.children.append(newNode)
					node = newNode
				}
			}
			node.row = row // auto-updated because referenced
		}
	}
	
	/// All parents (including `self`) in reverse order (inner-most child first).
	func allParents() -> [TreeNode] {
		var rv: [TreeNode] = [self]
		while let par = rv.last!.parent {
			rv.append(par)
		}
		return rv
	}
	
	/// Depth-first and last-to-first.
	func iterAll() -> TreeNodeIterator {
		return TreeNodeIterator(self)
	}
}

/// Reuse pattern for TreeNode iteration.
struct TreeNodeIterator: IteratorProtocol, Sequence {
	typealias Element = TreeNode
	
	private var queue: [TreeNode]
	
	init(_ root: TreeNode) {
		self.queue = [root]
	}
	
	mutating func next() -> TreeNode? {
		guard let node = queue.popLast() else {
			return nil
		}
		queue.append(contentsOf: node.children)
		return node
	}
}
