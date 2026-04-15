import AppKit

// Allow user to extract files via drag & drop (and action button)

// MARK: - Extract Individual

extension ArchiveController: NSFilePromiseProviderDelegate {
	/// Enable drag & drop operation on outline view.
	///
	/// Called in `viewDidLoad`.
	func initExtract() {
		outline.setDraggingSourceOperationMask(.copy, forLocal: false)
	}
	
	func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
		let entry = filePromiseProvider.userInfo as! ArchiveEntry
		return String(entry.path.split(separator: "/").last!)
	}
	
	func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
		guard let archive_url = self.fileURL else {
			return
		}
		do {
			let entry = filePromiseProvider.userInfo as! ArchiveEntry
			try LibArchive(archive_url).extract(entry.index, to: url)
			completionHandler(nil)
		} catch {
			completionHandler(error)
			NSAlert.error(error)
			return
		}
	}
}

// Only because `outlineView(_,pasteboardWriterForItem:)` is defined on dataSource

/// Called whenever user starts to drag some selected rows.
private func _extract(_ outlineView: NSOutlineView, _ entry: ArchiveEntry) -> NSFilePromiseProvider? {
	guard entry.filetype != .Directory else {
		// Fake TreeNode entries have `.Directory`.
		// If that were not the case, we would need to exclude `node.isFake` here
		return nil
	}
	let provider = NSFilePromiseProvider(fileType: "public.data", delegate: outlineView.delegate as! NSFilePromiseProviderDelegate)
	provider.userInfo = entry
	return provider
}

extension ListViewController {
	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
		_extract(outlineView, rowEntry(item))
	}
}
extension TreeViewController {
	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
		_extract(outlineView, rowEntry(item))
	}
}


// MARK: - NSAlert

extension NSAlert {
	/// Show modal error popup with style `.critical` and message `.localizedDescription`.
	static func error(_ error: Error) {
		let alert = NSAlert()
		alert.alertStyle = .critical
		alert.messageText = "Error"
		alert.informativeText = error.localizedDescription
		alert.runModal()
	}
}


// MARK: - Extract All

extension ArchiveController: NSOpenSavePanelDelegate {
	@IBAction func extractAll(_ sender: NSMenuItem) {
		guard let archive_url = self.fileURL else {
			return
		}
		let panel = NSOpenPanel()
		panel.title = "Extract all"
		panel.canChooseDirectories = true
		panel.canCreateDirectories = true
		panel.treatsFilePackagesAsDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.directoryURL = archive_url.deletingLastPathComponent()
		panel.prompt = "Extract"
		panel.begin {
			if $0 == .OK {
				do {
					try extractToPath(archive_url, panel.url!)
				} catch {
					NSAlert.error(error)
				}
			}
		}
		// TODO: I'd like to use `runModal()` but that puts Sandbox limitations on subpaths
	}
}

private func extractToPath(_ infile: URL, _ outdir: URL) throws {
	let fm = FileManager.default
	// restore previous CWD in any case
	let prev = fm.currentDirectoryPath
	defer {
		fm.changeCurrentDirectoryPath(prev)
	}
	// set CWD to user selected path
	guard fm.changeCurrentDirectoryPath(outdir.path) else {
		throw LibArchiveError.generic("Could not open directory for extract")
	}
	// find first available dirname
	var filename = infile.deletingPathExtension().lastPathComponent
	if fm.fileExists(atPath: filename),
	   let i = (2...999).first(where: { !fm.fileExists(atPath: filename + " (\($0))") }) {
		filename += " (\(i))"
	}
	// create subdir with name of archive and cd into
	try fm.createDirectory(atPath: filename, withIntermediateDirectories: false)
	guard fm.changeCurrentDirectoryPath(filename) else {
		throw LibArchiveError.generic("Could not open directory for extract")
	}
	// actual export
	try LibArchive(infile).extractAll()
}
