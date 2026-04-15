import AppKit

// Allow user to switch between view modes List View and Tree View

enum ViewMode {
	case list, tree
}

extension NSSegmentedControl {
	var selectedViewMode: ViewMode {
		self.selectedSegment == 1 ? .tree : .list
	}
	func select(_ viewMode: ViewMode) {
		self.setSelected(true, forSegment: viewMode == .tree ? 1 : 0)
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
	
	/// Triggered on action menu as well as default settings toggle.
	@IBAction func toggleSymlinkResolver(_ sender: Any) {
		if let state = (sender as? NSSwitch)?.state {
			setSymlinkResolver(enabled: state == .on)
		} else {
			setSymlinkResolver(enabled: !resolveSymlinks)
		}
		outline.reloadData()
	}
	
	/// Triggered on user action and on `load(:)`.
	func setSymlinkResolver(enabled: Bool) {
		resolveSymlinks = enabled
		menuResolveSymlinks.state = enabled ? .on : .off
		if symlinkMap == nil, enabled {
			do {
				symlinkMap = try LibArchive(fileURL!).symlinks()
			} catch {
				NSAlert.error(error)
			}
		}
	}
	
	/// Open settings popover under settings button.
	@IBAction func openSettings(_ sender: NSButton) {
		let panel = NSPopover()
		panel.contentViewController = NSViewController()
		panel.contentViewController!.view = settingsContainer
		panel.behavior = .transient
		panel.show(relativeTo: .zero, of: sender, preferredEdge: .maxY)
	}
}
