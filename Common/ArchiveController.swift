import Foundation
import Cocoa

// TODO: collapsible nested folders

class ArchiveController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	
	@IBOutlet var cfgFilter: NSSegmentedControl!
	@IBOutlet var searchField: NSSearchField!
	@IBOutlet var metaInfo: NSTextField!
	
	@IBOutlet var outline: NSOutlineView!
	
	@IBOutlet var errorView: NSView!
	@IBOutlet var errorText: NSTextField!
	
	var fileURL: URL? = nil
	var rows: [Row] = []
	var filteredRows: [Row]? = nil
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	override func viewDidLoad() {
		metaInfo.stringValue = ""
		outline.setDraggingSourceOperationMask(.copy, forLocal: false)
	}
	
	@discardableResult func load(_ url: URL) -> Bool {
		fileURL = nil
		rows = []
		do {
			let archive = try LibArchive(url)
			for entry in archive {
				rows.append(Row(entry: entry))
			}
			fileURL = url
			metaInfo.stringValue = archive.metaInfo()
			applySort()
			applyFilter()
			applySearch()
			reload()
			return true
		} catch {
			self.view = errorView
			errorText.stringValue = "ERROR: " + error.localizedDescription
			return false
		}
	}
	
	/// Recompute `filteredRows` and reload outline view
	func reload() {
		switch (searchActive, filterActive) {
		case (true, true): filteredRows = rows.filter { $0.matchSearch && $0.matchFilter }
		case (true, _): filteredRows = rows.filter { $0.matchSearch }
		case (_, true): filteredRows = rows.filter { $0.matchFilter }
		case (_, _): filteredRows = nil
		}
		outline.reloadData()
	}
	
	// MARK: - Outline View
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		filteredRows?.count ?? rows.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		filteredRows?[index] ?? rows[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		false
	}
}


// MARK: - Row Entry

class Row {
	let entry: ArchiveEntry
	var matchSearch = false
	var matchFilter = false
	
	init(entry: ArchiveEntry) {
		self.entry = entry
	}
}
