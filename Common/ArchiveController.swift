import Foundation
import Cocoa

class ArchiveController: NSViewController, NSOutlineViewDelegate {
	
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
	
	var expandedNodes = NSHashTable<TreeNode>.weakObjects()
	
	var viewMode: ViewMode = .list
	/// `true` if user has set user-defaults. Reset on `load(:)`
	var autoExpandOnce: Bool = false
	/// Used for data export
	var fileURL: URL? = nil
	
	// TODO: GUI option to enable resolver
	/// Symlink resolving is optional and data is only loaded when needed
	let resolveSymlinks: Bool = UserDefaults.standard.bool(forKey: "resolveSymlinks")
	/// Loaded upon first use. Maps `ArchiveEntry.index` to resolved symlink
	var symlinkMap: [UInt : String]? = nil
	
	// Populated on `load(:)`
	private var rawData: [ArchiveEntry] = []
	private var dataSourceMap: [ViewMode: DataSource] = [:]
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
		rawData = []
		dataSourceMap = [:]
		outline.dataSource = nil
		metaInfo.stringValue = ""
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
			rawData = Array(archive)
			metaInfo.stringValue = archive.metaInfo()
			fileURL = url
			changeDataSource(viewMode)
			autoenableAutoExpandButtons()
			enableSymlinkResolver()
			return true
		} catch {
			self.view = errorView
			errorText.stringValue = "ERROR: " + error.localizedDescription
			return false
		}
	}
	
	/// Called on `load(:)` and on view mode change
	func changeDataSource(_ mode: ViewMode) {
		if let ds = dataSourceMap[mode] {
			dataSource = ds
		} else {
			switch mode {
			case .list: dataSource = ListViewController(rawData)
			case .tree: dataSource = TreeViewController(rawData)
			}
			dataSourceMap[mode] = dataSource
		}
		// each view has its own, separate sort. Restore to reflect in UI
		outline.sortDescriptors = dataSource.sortDescriptors
		// search is shared for all views
		dataSource.searchFilter = searchField.stringValue
		performFilterAndReload()
	}
	
	/// Recompute filter and reload outline view.
	func performFilterAndReload() {
		dataSource.performFilter()
		outline.reloadData()
		restoreCollapsibleState()
	}
	
	func enableSymlinkResolver() {
		if symlinkMap == nil, resolveSymlinks {
			symlinkMap = try? LibArchive(fileURL!).symlinks()
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
