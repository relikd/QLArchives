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

extension ArchiveController {
	/// View starts with all entries collapsed, so this disables the collapse action (initially).
	///
	/// Called in `viewDidLoad`.
	func initCollapsible() {
		cfgTreeExpand.set(.collapse, enabled: false)
	}
	
	// enable the opposite action when at least one row is collapsed
	// we could perform a search over all items to see if all are collapsed to disable the collapse button
	// but that would eat unnecessary resources for each click
	func outlineViewItemDidCollapse(_ notification: Notification) {
		cfgTreeExpand.set(.expand, enabled: true)
		expandedNodes.remove(notification.userInfo?["NSObject"] as? TreeNode)
	}
	
	// ... same for the other action
	func outlineViewItemDidExpand(_ notification: Notification) {
		cfgTreeExpand.set(.collapse, enabled: true)
		expandedNodes.add(notification.userInfo?["NSObject"] as? TreeNode)
	}
	
	/// Restore state when switching between view modes.
	func restoreCollapsibleState() {
		guard viewMode == .tree else {
			return
		}
		// alternatively we could keep the order of expand clicks,
		// but then the remove operation above would be more complex
		for node in expandedNodes.allObjects {
			if outline.isItemExpanded(node) {
				// if already expanded below, we can assume all parents already expanded
				continue
			}
			// NSOutlineView cannot expand items if the parent isnt expanded.
			var nodeList: [TreeNode] = [node]
			while let par = nodeList.last!.parent {
				nodeList.append(par)
			}
			for node in nodeList.reversed() {
				outline.expandItem(node)
			}
		}
	}
	
	/// Triggers when user clicks expand / collapse button in tree view mode
	@IBAction func performTreeExpand(_ sender: NSSegmentedControl) {
		let action = sender.expandAction
		switch action {
		case .expand: outline.expandItem(nil, expandChildren: true)
		case .collapse: outline.collapseItem(nil, collapseChildren: true)
		}
		sender.set(.expand, enabled: action == .collapse)
		sender.set(.collapse, enabled: action == .expand)
		// interestingly, expand & collapse children does not trigger new display
		outline.needsDisplay = true
	}
}
