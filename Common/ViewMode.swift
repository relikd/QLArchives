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
	/// Triggered by mode changes in another document window
	func registerViewModeChanges() -> NSKeyValueObservation {
		cfgViewMode.observe(\.selectedSegment) { [weak self] control, _ in
			self?.changeViewMode(control)
		}
	}
	
	/// Triggers when user changes view mode
	@IBAction func changeViewMode(_ sender: NSSegmentedControl) {
		viewMode = sender.selectedViewMode
		changeDataSource(viewMode)
	}
}
