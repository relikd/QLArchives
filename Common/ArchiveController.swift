import Foundation
import Cocoa

class ArchiveController: NSViewController, NSOutlineViewDelegate {
	// Action toolbar
	@IBOutlet var cfgViewMode: NSSegmentedControl!
	@IBOutlet var cfgFilter: NSSegmentedControl!
	@IBOutlet var cfgTreeExpand: NSSegmentedControl!
	@IBOutlet var searchField: NSSearchField!
	@IBOutlet var metaInfo: NSTextField!
	
	// Action button menu
	@IBOutlet var menuExtractAll: NSMenuItem!
	@IBOutlet var menuResolveSymlinks: NSMenuItem!
	
	// Settings popup
	@IBOutlet var settingsContainer: NSView!
	@IBOutlet var settingsDefaultView: NSSegmentedControl!
	@IBOutlet var settingsAutoExpand: NSSwitch!
	@IBOutlet var settingsResolveSymlink: NSSwitch!
	
	// Main content
	@IBOutlet var outline: NSOutlineView!
	
	// Error view
	@IBOutlet var errorView: NSView!
	@IBOutlet var errorText: NSTextField!
	
	var expandedNodes = NSHashTable<TreeNode>.weakObjects()
	
	var viewMode: ViewMode = .list
	/// `true` if user has set user-defaults. Reset on `load(:)`
	var autoExpandOnce: Bool = false
	/// Used for data extract and symlink map
	var fileURL: URL? = nil
	/// Loaded upon first use. Maps `ArchiveEntry.index` to resolved symlink
	var symlinkMap: [UInt : String]? = nil
	/// Symlink resolving is optional and data is only loaded when needed
	var resolveSymlinks: Bool = false
	
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
		symlinkMap = nil
		outline.dataSource = nil
		metaInfo.stringValue = ""
		expandedNodes.removeAllObjects()
		// load user settings
		viewMode = settingsDefaultView.selectedViewMode
		cfgViewMode.select(viewMode)
		autoExpandOnce = settingsAutoExpand.state == .on
		resolveSymlinks = settingsResolveSymlink.state == .on
		menuResolveSymlinks.state = resolveSymlinks ? .on : .off
	}
	
	/// Called (once) before `load(:)`
	override func viewDidLoad() {
		trash()
		initCollapsible()
		initExtract()
	}
	
	/// Can be called multiple times
	@discardableResult func load(_ url: URL) -> Bool {
		trash()
		do {
			let archive = try LibArchive(url)
			rawData = Array(archive)
			metaInfo.stringValue = archive.metaInfo()
			fileURL = url
			if resolveSymlinks {
				setSymlinkResolver(enabled: true)
			}
			changeDataSource(viewMode)
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
			case .list: dataSourceMap[mode] = ListViewController(rawData)
			case .tree: dataSourceMap[mode] = TreeViewController(rawData)
			}
			dataSource = dataSourceMap[mode]!
		}
		// each view has its own, separate sort. Restore to reflect in UI
		outline.sortDescriptors = dataSource.sortDescriptors
		// search is shared for all views
		dataSource.searchFilter = searchField.stringValue
		performFilterAndReload()
		autoenableAutoExpandButtons()
		/// Switch toolbar depending on current view mode
		cfgTreeExpand.isHidden = viewMode != .tree
		cfgFilter.isHidden = viewMode != .list
	}
	
	/// Recompute filter and reload outline view.
	func performFilterAndReload() {
		dataSource.performFilter()
		outline.reloadData()
		restoreCollapsibleState()
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
