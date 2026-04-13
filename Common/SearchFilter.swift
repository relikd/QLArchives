import AppKit

// Allow user to filter rows by searching for a string

private var debounceTimer: Timer?

extension ArchiveController {
	/// Called whenever user starts typing in the search field.
	@IBAction func didSearch(_ sender: NSSearchField) {
		let debounce = sender.stringValue.isEmpty ? 0.02 : 0.2
		debounceTimer?.invalidate()
		debounceTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
			self?.applySearch()
			self?.performFilterAndReload()
		}
	}
	
	/// `true` if search field has content
	var searchActive: Bool { !searchField.stringValue.isEmpty }
	
	/// Does __not__ reload data.
	func applySearch() {
		switch viewMode {
		case .list: applySearchOnList(searchField.stringValue)
		case .tree: applySearchOnTree(searchField.stringValue)
		}
	}
	
	/// Set `matchSearch` flag for all matching rows.
	/// Does __not__ perform the filtering (only prepares for it).
	private func applySearchOnList(_ searchTerm: String) {
		if searchActive {
			rows.forEach { $0.matchSearch = $0.entry.path.contains(searchTerm) }
		}
	}
	
	/// Set `matchSearch` flag for all matching nodes and their parents.
	/// Does __not__ perform the filtering (only prepares for it).
	private func applySearchOnTree(_ searchTerm: String) {
		guard searchActive else {
			return
		}
		tree.values.forEach { list in list.forEach { node in
			node.matchSearch = node.name.contains(searchTerm)
		}}
	}
	
	// MARK: - UI Hotkeys
	
	// allow CMD + F to search
	override func keyDown(with event: NSEvent) {
		if event.characters == "f", event.modifierFlags.contains(.command), !searchField.isHidden {
			searchField.becomeFirstResponder()
		} else {
			super.keyDown(with: event)
		}
	}
	
	// allow ESC inside search field / any NSView
	override func cancelOperation(_ sender: Any?) {
		self.view.window?.performSelector(onMainThread: #selector(NSWindow.makeFirstResponder(_:)), with: self.outline, waitUntilDone: false)
	}
}
