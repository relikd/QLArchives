import AppKit

class ListViewController: NSObject, DataSource {
	private var rows: [Row] = []
	private var filteredRows: [Row]? = nil
	
	// MARK: - Init
	
	init(_ data: [ArchiveEntry]) {
		rows = data.map { Row(entry: $0) }
	}
	
	// MARK: - Data Source
	
	func rowEntry(_ item: Any) -> ArchiveEntry? {
		(item as? Row)?.entry
	}
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		(filteredRows ?? rows).count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		(filteredRows ?? rows)[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		false
	}
	
	// MARK: - Sort
	
	var sortDescriptors: [NSSortDescriptor] = [] {
		willSet { rows.sort(with: newValue) }
	}
	
	// MARK: - Search
	
	var searchFilter: String = "" {
		willSet {
			if newValue != searchFilter, !newValue.isEmpty {
				rows.forEach { $0.matchSearch = $0.entry.path.contains(newValue) }
			}
		}
	}
	
	// MARK: - Filter
	
	var filetypeFilter: TypeFilter? = nil {
		willSet {
			if let filtr = newValue?.asFiletype() {
				rows.forEach { $0.matchFiletype = filtr.contains($0.entry.filetype) }
			}
		}
	}
	
	/// Sets `filteredRows`
	func performFilter() {
		switch (isSearchActive, isFiletypeFilterActive) {
		case (true, true): filteredRows = rows.filter { $0.matchSearch && $0.matchFiletype }
		case (true, _): filteredRows = rows.filter { $0.matchSearch }
		case (_, true): filteredRows = rows.filter { $0.matchFiletype }
		case (_, _): filteredRows = nil
		}
	}
}


// MARK: - Data Entry

class Row: HasArchiveEntry {
	/// Reference to an `LibArchive` entry
	let entry: ArchiveEntry
	/// `true` if search string matches this entry.
	var matchSearch = false
	/// `true` if filetype filter matches this entry.
	var matchFiletype = false
	
	init(entry: ArchiveEntry) {
		self.entry = entry
	}
}

