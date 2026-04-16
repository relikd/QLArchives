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

// MARK: - Extract All

/// Show `NSOpenPanel` and let user select target directory.
/// Libarchive will extract all content to this directory.
/// (actually a subdirectory with the name of the archive)
func showExtractAllDialog(_ archiveFile: URL, progress: NSProgressIndicator? = nil) {
	let panel = NSOpenPanel()
	panel.title = "Extract all"
	panel.canChooseDirectories = true
	panel.canCreateDirectories = true
	panel.treatsFilePackagesAsDirectories = true
	panel.canChooseFiles = false
	panel.allowsMultipleSelection = false
	panel.directoryURL = archiveFile.deletingLastPathComponent()
	panel.prompt = "Extract"
	guard panel.runModal() == .OK, let outdir = panel.url else {
		return
	}
	// show progress
	let callback: ProgressCallback?
	if let progress {
		progress.doubleValue = 0
		progress.isHidden = false
		callback = { step in
			DispatchQueue.main.async {
				progress.doubleValue = Double(step)
			}
		}
	} else {
		callback = nil
	}
	// extract on a background thread
	// (new init instead of `.global`, because latter is not available in QuickLook preview)
	DispatchQueue(label: "de.relikd.alarchives.extract", qos: .utility).async {
		do {
			try extractToPath(archiveFile, outdir, progress: callback)
		} catch {
			NSAlert.error(error)
		}
		if let progress {
			DispatchQueue.main.async {
				progress.doubleValue = progress.maxValue
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
				progress.isHidden = true
			}
		}
	}
}

private func extractToPath(_ infile: URL, _ outdir: URL, progress: ProgressCallback? = nil) throws {
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
	try LibArchive(infile).extractAll(progress: progress)
}
