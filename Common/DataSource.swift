import AppKit

// Data loading – NSOutlineView data source

extension ArchiveController {
	/// This postpones tree data creation until TreeView is in use.
	///
	/// Safe to call multiple times (NO-OP after `tree` is populated).
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
	
	func rowEntry(_ item: Any) -> ArchiveEntry? {
		switch viewMode {
		case .list: (item as? Row)?.entry
		case .tree: (item as? TreeNode)?.row?.entry
		}
	}
	
	@inline(__always)
	private func _dataSource(_ item: Any?) -> [Any] {
		switch viewMode {
		case .list:
			return filteredRows ?? rows
		case .tree:
			let node = (item as? TreeNode ?? tree)
			return node?.filteredChildren ?? node?.children ?? []
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		_dataSource(item).count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		_dataSource(item)[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		switch viewMode {
		case .list: false
		case .tree: !(item as! TreeNode).children.isEmpty // expandable doesnt depend on filter
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
		if searchActive {
			tree.iterAll().forEach { $0.filteredChildren = $0.children.filter(\.matchSearch) }
		} else if tree.filteredChildren != nil { // sufficient to check root node filter
			tree.iterAll().forEach { $0.filteredChildren = nil }
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
	weak var row: Row? // we could store ArchiveEntry, but that would duplicate data in memory
	var children: [TreeNode] = []
	weak var parent: TreeNode?
	
	// cant reuse row search filter bebecause some TreeNodes dont have a row reference
	var matchSearch: Bool = false
	var filteredChildren: [TreeNode]? = nil
	
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
