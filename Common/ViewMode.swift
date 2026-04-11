import AppKit

// Allow user to switch between view modes List View and Tree View

enum ViewMode {
	case list, tree
}

extension NSSegmentedControl {
	var selectedViewMode: ViewMode {
		self.selectedSegment == 1 ? .tree : .list
	}
}

extension ArchiveController {
	/// Set view mode to previously stored config value + load appropriate toolbar.
	///
	/// Called in `viewDidLoad`.
	func initViewMode() {
		viewMode = cfgViewMode.selectedViewMode
		setViewModeDependentToolbar()
	}
	
	/// Triggered by mode changes in another document window
	func registerViewModeChanges() -> NSKeyValueObservation {
		cfgViewMode.observe(\.selectedSegment) { [weak self] control, _ in
			self?.changeViewMode(control)
		}
	}
	
	/// Triggers when user changes view mode
	@IBAction func changeViewMode(_ sender: NSSegmentedControl) {
		viewMode = sender.selectedViewMode
		setViewModeDependentToolbar()
		initTreeData(isInitial: true) // depends on `viewMode`
		reload()
	}
	
	/// Switch toolbar depending on current view mode (also called during `viewDidLoad`)
	/// Removes old view and inserts new view.
	/// @Note depends on `self.viewMode`
	func setViewModeDependentToolbar() {
		toolbarPlaceholder.subviews.forEach { $0.removeFromSuperview() }
		switch viewMode {
		case .list: toolbarPlaceholder.addSubview(toolbarListView)
		case .tree: toolbarPlaceholder.addSubview(toolbarTreeView)
		}
		let newToolbar = toolbarPlaceholder.subviews.first!
		newToolbar.frame.size.height = toolbarPlaceholder.bounds.height
		toolbarPlaceholder.widthAnchor.constraint(equalTo: newToolbar.widthAnchor).isActive = true
	}
}
