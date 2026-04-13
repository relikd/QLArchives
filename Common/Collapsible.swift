import AppKit

// Allow user to expand and collapse tree structure

enum ExpandAction {
	case expand, collapse
}

extension NSSegmentedControl {
	var expandAction: ExpandAction {
		self.selectedSegment == 1 ? .collapse : .expand
	}
	func set(_ action: ExpandAction, enabled: Bool) {
		setEnabled(enabled, forSegment: action == .collapse ? 1 : 0)
	}
}

private var debounceTimer: Timer?

extension ArchiveController {
	/// Called in `viewDidLoad`. Later, `load(:)` will call `autoenableAutoExpandButtons`.
	func initCollapsible() {
		cfgTreeExpand.set(.expand, enabled: false)
		cfgTreeExpand.set(.collapse, enabled: false)
	}
	
	/// Enable or disable Expand All / Collapse All buttons based on curently expanded entries
	func autoenableAutoExpandButtons() {
		debounceTimer?.invalidate()
		debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { [weak self] _ in
			let current = self?.expandedNodes.count ?? 0
			self?.cfgTreeExpand.set(.expand, enabled: current < self?.dataSource.collapsibleCount ?? 0)
			self?.cfgTreeExpand.set(.collapse, enabled: current > 0)
		}
	}
	
	// enable the opposite action when at least one row is collapsed
	// we could perform a search over all items to see if all are collapsed to disable the collapse button
	// but that would eat unnecessary resources for each click
	func outlineViewItemDidCollapse(_ notification: Notification) {
		expandedNodes.remove(notification.userInfo?["NSObject"] as? TreeNode)
		autoenableAutoExpandButtons()
	}
	
	// ... same for the other action
	func outlineViewItemDidExpand(_ notification: Notification) {
		expandedNodes.add(notification.userInfo?["NSObject"] as? TreeNode)
		autoenableAutoExpandButtons()
	}
	
	/// Restore state when switching between view modes.
	func restoreCollapsibleState() {
		guard viewMode == .tree else {
			return
		}
		if autoExpandOnce {
			outline.expandItem(nil, expandChildren: true)
			autoExpandOnce = false
			return
		}
		// NSOutlineView cannot expand items if the parent isnt expanded
		// sort assures nested folders appear after their parent folder
		expandedNodes.allObjects.sorted { $0.fullpath < $1.fullpath }.forEach {
			outline.expandItem($0)
		}
	}
	
	/// Triggers when user clicks expand / collapse button in tree view mode
	@IBAction func performTreeExpand(_ sender: NSSegmentedControl) {
		switch sender.expandAction {
		case .expand: outline.expandItem(nil, expandChildren: true)
		case .collapse: outline.collapseItem(nil, collapseChildren: true)
		}
		// interestingly, expand & collapse children does not trigger new display
		outline.needsDisplay = true
	}
}
