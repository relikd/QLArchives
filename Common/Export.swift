import AppKit

// Allow user to export individual files via drag & drop

extension ArchiveController: NSFilePromiseProviderDelegate {
	/// Enable drag & drop operation on outline view.
	///
	/// Called in `viewDidLoad`.
	func initExport() {
		outline.setDraggingSourceOperationMask(.copy, forLocal: false)
	}
	
	/// Called whenever user starts to drag some selected rows.
	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
		guard let entry = dataSource.rowEntry(item), entry.filetype != .Directory else {
			// Fake TreeNode entries have `.Directory`.
			// If that were not the case, we would need to exclude `node.isFake` here
			return nil
		}
		let provider = NSFilePromiseProvider(fileType: "public.data", delegate: self)
		provider.userInfo = entry
		return provider
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
			let alert = NSAlert()
			alert.alertStyle = .critical
			alert.messageText = error.localizedDescription
			alert.runModal()
			return
		}
	}
}
