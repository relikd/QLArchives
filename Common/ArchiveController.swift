import Foundation
import Cocoa

class ArchiveController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	
	@IBOutlet var cfgViewMode: NSSegmentedControl!
	@IBOutlet var cfgFilter: NSSegmentedControl!
	@IBOutlet var cfgTreeExpand: NSSegmentedControl!
	@IBOutlet var searchField: NSSearchField!
	@IBOutlet var metaInfo: NSTextField!
	
	@IBOutlet var toolbarPlaceholder: NSView!
	@IBOutlet var toolbarListView: NSView!
	@IBOutlet var toolbarTreeView: NSView!
	
	@IBOutlet var outline: NSOutlineView!
	
	@IBOutlet var errorView: NSView!
	@IBOutlet var errorText: NSTextField!
	
	// Restore state when switching between view modes
	// current `sortDescriptors` are loaded via Bindings
	var otherSortDescriptors: [NSSortDescriptor] = []
	var expandedNodes = NSHashTable<TreeNode>.weakObjects()
	
	var viewMode: ViewMode = .list
	/// `true` if user has set user-defaults. Reset on `load(:)`
	var autoExpandOnce: Bool = false
	/// Used for data export
	var fileURL: URL? = nil
	/// Used for List view
	var rows: [Row] = []
	var filteredRows: [Row]? = nil
	/// Used for Tree view `[dir-name: node]`
	var tree: [String: [TreeNode]] = [:]
	var filteredTree: [String: [TreeNode]]? = nil
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	/// Reset all variables to an empty state
	private func trash() {
		fileURL = nil
		rows = []
		filteredRows = nil
		tree = [:]
		filteredTree = nil
		metaInfo.stringValue = ""
		otherSortDescriptors = []
		expandedNodes.removeAllObjects()
		autoExpandOnce = UserDefaults.standard.bool(forKey: "autoExpand")
	}
	
	/// Called (once) before `load(:)`
	override func viewDidLoad() {
		trash()
		initViewMode()
		initCollapsible()
		initExport()
	}
	
	/// Can be called multiple times
	@discardableResult func load(_ url: URL) -> Bool {
		trash()
		do {
			let archive = try LibArchive(url)
			rows = archive.map { Row(entry: $0) }
			metaInfo.stringValue = archive.metaInfo()
			fileURL = url
			initTreeData(isInitial: true) // before sort, depends on `rows`
			applySort()
			applyFilter()
			applySearch()
			performFilterAndReload(restoreCollapsible: true)
			return true
		} catch {
			self.view = errorView
			errorText.stringValue = "ERROR: " + error.localizedDescription
			return false
		}
	}
	
	// MARK: - Key-Value Observer
	
	private var kvo: NSKeyValueObservation?
	
	override func viewWillAppear() {
		kvo = registerViewModeChanges()
	}
	
	override func viewDidDisappear() {
		kvo?.invalidate()
	}
}
