import AppKit

// Allow user to filter rows by searching for a string

private var debounceTimer: Timer?

extension ArchiveController {
	/// Called whenever user starts typing in the search field.
	@IBAction func didSearch(_ sender: NSSearchField) {
		let debounce = sender.stringValue.isEmpty ? 0.02 : 0.2
		debounceTimer?.invalidate()
		debounceTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
			self?.applyFilter()
		}
	}
	
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
