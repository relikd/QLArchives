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
	var data: [ArchiveEntry] = []
	var filter: [ArchiveEntry]? = nil
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	override func viewDidLoad() {
		metaInfo.stringValue = ""
		outline.setDraggingSourceOperationMask(.copy, forLocal: false)
	}
	
	@discardableResult func load(_ url: URL) -> Bool {
		fileURL = nil
		data = []
		do {
			let archive = try LibArchive(url)
			for entry in archive {
				data.append(entry)
			}
			fileURL = url
			metaInfo.stringValue = archive.metaInfo()
			outline.reloadData()
			applySort() // apply previous sort & filter
			return true
		} catch {
			self.view = errorView
			errorText.stringValue = "ERROR: " + error.localizedDescription
			return false
		}
	}
	
	// MARK: - Outline View
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		filter?.count ?? data.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		filter?[index] ?? data[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		false
	}
}
