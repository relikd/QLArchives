import AppKit

// User interaction via actions toolbar / actions menu

private var debounceTimer: Timer?

extension ArchiveController {
	// MARK: - Toolbar Actions
	
	/// Triggers when user changes view mode
	@IBAction func changeViewMode(_ sender: NSSegmentedControl) {
		viewMode = sender.selectedViewMode
		changeDataSource(viewMode)
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
	
	/// Called when user clicks on any of the type toggles.
	@IBAction func toggleFilter(_ sender: NSSegmentedControl) {
		dataSource.filetypeFilter = cfgFilter.selectedTypeFilter
		performFilterAndReload()
	}
	
	/// Called whenever user starts typing in the search field.
	@IBAction func didSearch(_ sender: NSSearchField) {
		let debounce = sender.stringValue.isEmpty ? 0.02 : 0.2
		debounceTimer?.invalidate()
		debounceTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
			self?.dataSource.searchFilter = sender.stringValue
			self?.performFilterAndReload()
		}
	}
	
	// MARK: - Action Menu
	
	/// Triggered on action menu or `Cmd + E`
	@IBAction func extractAll(_ sender: NSMenuItem) {
		if let archive_url = self.fileURL {
			showExtractAllDialog(archive_url)
		}
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
	
	// MARK: - Settings Popover
	
	/// Open settings popover under settings button.
	@IBAction func openSettings(_ sender: NSButton) {
		let panel = NSPopover()
		panel.contentViewController = NSViewController()
		panel.contentViewController!.view = settingsContainer
		panel.behavior = .transient
		panel.show(relativeTo: .zero, of: sender, preferredEdge: .maxY)
	}
	
	// MARK: - UI Hotkeys
	
	/// allow `Cmd + F` to search
	override func keyDown(with event: NSEvent) {
		if event.characters == "f", event.modifierFlags.contains(.command), !searchField.isHidden {
			searchField.becomeFirstResponder()
		} else {
			super.keyDown(with: event)
		}
	}
	
	/// allow `ESC` inside search field / any NSView
	override func cancelOperation(_ sender: Any?) {
		self.view.window?.performSelector(onMainThread: #selector(NSWindow.makeFirstResponder(_:)), with: self.outline, waitUntilDone: false)
	}
}

