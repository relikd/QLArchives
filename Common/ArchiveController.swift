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
	
	// Populated on `load(:)`
	var dataSourceList: ListViewController!
	var dataSourceTree: TreeViewController!
	var dataSource: DataSource {
		get { outline.dataSource as! DataSource }
		set { outline.dataSource = newValue }
	}
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	/// Reset all variables to an empty state
	private func trash() {
		fileURL = nil
		outline.dataSource = nil
		dataSourceList = nil
		dataSourceTree = nil
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
			dataSourceList = ListViewController(archive: archive)
			dataSourceTree = TreeViewController(rows: dataSourceList.rows)
			updateDataSource(viewMode)
			metaInfo.stringValue = archive.metaInfo()
			fileURL = url
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
