import AppKit

// Data loading – NSOutlineView data source

protocol DataSource: NSOutlineViewDataSource {
	/// Applies the sort (upon assignment)
	var sortDescriptors: [NSSortDescriptor] { get set }
	/// Set `matchSearch` flag for all matching entries (upon assignment).
	var searchFilter: String { get set }
	/// Set `matchFiletype` flag for all matching entries (upon assignment).
	var filetypeFilter: TypeFilter? { get set }
	/// Retrieve actual data from data source structure
	func rowEntry(_ item: Any) -> ArchiveEntry?
	/// Perform actually filter. This create a layer view on the data which hides non-matchig files
	func performFilter()
}

extension DataSource {
	/// `true` if search field has content
	var isSearchActive: Bool { !searchFilter.isEmpty }
	/// `true` if any type filter is active. (also `false` if all are active -> no filter needed).
	var isFiletypeFilterActive: Bool { filetypeFilter?.isOn == true }
}
