import Foundation
import Cocoa

class ArchiveController: NSViewController, NSOutlineViewDelegate {
	// Action toolbar
	@IBOutlet var cfgViewMode: NSSegmentedControl!
	@IBOutlet var cfgFilter: NSSegmentedControl!
	@IBOutlet var cfgTreeExpand: NSSegmentedControl!
	@IBOutlet var searchField: NSSearchField!
	
	// Action button menu
	@IBOutlet var menuExtractAll: NSMenuItem!
	@IBOutlet var menuResolveSymlinks: NSMenuItem!
	
	// Settings popup
	@IBOutlet var btnSettings: NSButton!
	@IBOutlet var settingsContainer: NSView!
	@IBOutlet var settingsDefaultView: NSSegmentedControl!
	@IBOutlet var settingsAutoExpand: NSSwitch!
	@IBOutlet var settingsResolveSymlink: NSSwitch!
	
	// Progress bar
	@IBOutlet var progressBar: NSProgressIndicator!
	
	// Main content
	@IBOutlet var outline: NSOutlineView!
	
	// Meta info
	@IBOutlet var metaInfoLeft: NSTextField!
	@IBOutlet var metaInfoRight: NSTextField!
	
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
		expandedNodes.removeAllObjects()
		progressBar.isHidden = true
		metaInfoLeft.stringValue = ""
		metaInfoRight.stringValue = ""
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
			prepareMetaInfo(archive)
			progressBar.maxValue = Double(archive.count)
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
	
	// Dont focus search field (initially)
	
	override func viewWillAppear() {
		searchField.refusesFirstResponder = true
	}
	
	override func viewDidAppear() {
		searchField.refusesFirstResponder = false
	}
	
	// MARK: - Meta info
	
	/// Generate info text for archive meta data (entry count, compression ratio, etc.)
	///
	/// Must be called after all entries have been processed.
	func prepareMetaInfo(_ archive: LibArchive) {
		let counts = rawData.reduce(into: (0, 0, 0)) {
			switch $1.filetype {
			case .Directory: $0.1 += 1
			case .SymbolicLink:  $0.2 += 1
			default:  $0.0 += 1
			}
		}
		metaInfoLeft.stringValue = "\(rawData.count) items (dirs: \(counts.1), files: \(counts.0), links: \(counts.2))"
		metaInfoRight.stringValue = "\(Formatter.bytes(archive.compressedSize)) on disk | \(Formatter.bytes(archive.uncompressedSize)) in archive"
		if archive.uncompressedSize > 0 {
			let ratio = 1 - Float(archive.compressedSize) / Float(archive.uncompressedSize)
			let percent = Int(ratio * 1000) / 10
			metaInfoRight.stringValue += " | \(percent)%"
		}
	}
}
