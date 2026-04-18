import AppKit

// User interaction via actions toolbar / actions menu

private var debounceTimer: Timer?

extension ArchiveController {
	// MARK: - Toolbar Actions
	
	/// Triggers on toolbar buttons (`NSSegmentedControl`), or main menu item (`NSMenuItem`).
	@IBAction func changeViewMode(_ sender: Any) {
		if sender is NSMenuItem {
			cfgViewMode.select(viewMode == .list ? .tree : .list)
		}
		viewMode = cfgViewMode.selectedViewMode
		changeDataSource(viewMode)
	}
	
	/// Expand / collapse buttons.
	/// Triggers on toolbar buttons (`NSSegmentedControl`), or main menu item (`NSMenuItem`).
	@IBAction func performTreeExpand(_ sender: Any) {
		let action: ExpandAction
		switch sender {
		case let mi as NSMenuItem: action = .init(rawValue: mi.tag)!
		case let seg as NSSegmentedControl: action = .init(rawValue: seg.selectedSegment)!
		default: return
		}
		switch action {
		case .expand: outline.expandItem(nil, expandChildren: true)
		case .collapse: outline.collapseItem(nil, collapseChildren: true)
		}
		// interestingly, expand & collapse children does not trigger new display
		outline.needsDisplay = true
	}
	
	/// Triggers on toolbar buttons (`NSSegmentedControl`), or main menu item (`NSMenuItem`).
	@IBAction func toggleFiletypeFilter(_ sender: Any) {
		if let mi = sender as? NSMenuItem {
			cfgFilter.multiSelectToggle(mi.tag)
		}
		dataSource.filetypeFilter = cfgFilter.selectedTypeFilter
		performFilterAndReload()
	}
	
	/// Triggers whenever user starts typing in the search field.
	@IBAction func didSearch(_ sender: NSSearchField) {
		let debounce = sender.stringValue.isEmpty ? 0.02 : 0.2
		debounceTimer?.invalidate()
		debounceTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
			self?.dataSource.searchFilter = sender.stringValue
			self?.performFilterAndReload()
		}
	}
	
	/// Hotkey `Cmd + E`.
	/// Triggers on toolbar button (`NSButton`), or main menu item (`NSMenuItem`).
	@IBAction func extractAll(_ sender: Any) {
		if let archive_url = self.fileURL {
			showExtractAllDialog(archive_url, progress: progressBar)
		}
	}
	
	/// Hotkey `Cmd + Y`.
	/// Triggers on toolbar button (`NSButton`), main menu item (`NSMenuItem`), or default settings popover (`NSSwitch`).
	@IBAction func toggleShowSymlinks(_ sender: Any) {
		if let state = (sender as? NSSwitch)?.state {
			// contrary to the else-branch, setting a default config overwrites the current state
			setSymlinkResolver(enabled: state == .on)
		} else {
			setSymlinkResolver(enabled: !resolveSymlinks)
		}
		outline.reloadData()
	}
	
	/// Triggers on user action (see above) and on `load(:)`.
	func setSymlinkResolver(enabled: Bool) {
		resolveSymlinks = enabled
		btnShowSymlinks.state = enabled ? .on : .off
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
		panel.show(relativeTo: .zero, of: btnSettings, preferredEdge: .maxY)
	}
	
	// MARK: - UI Hotkeys
	
	/// Hotkey `Cmd + F`.
	/// Triggers on main menu action (overwrites `performFindPanelAction:` to allow hotkey if focus is on meta info)
	@IBAction func focusOnSearchField(_ sender: NSMenuItem) {
		if !searchField.isHidden {
			searchField.performSelector(onMainThread: #selector(becomeFirstResponder), with: nil, waitUntilDone: false)
		}
	}
	
	/// Allow `ESC` inside search field (or any other NSView)
	override func cancelOperation(_ sender: Any?) {
		self.view.window?.performSelector(onMainThread: #selector(NSWindow.makeFirstResponder(_:)), with: self.outline, waitUntilDone: false)
	}
}

