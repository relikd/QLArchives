import Foundation
import Cocoa

// TODO: collapsible nested folders

class ArchiveController: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
	
	@IBOutlet var outline: NSOutlineView!
	@IBOutlet var metaInfo: NSTextField!
	
	@IBOutlet var configBackground: NSView!
	@IBOutlet var searchField: NSSearchField!
	@IBOutlet var checkboxDirs: NSButton!
	
	@IBOutlet var errorView: NSView!
	@IBOutlet var errorText: NSTextField!
	
	private var fileURL: URL? = nil
	private var data: [ArchiveEntry] = []
	private var filter: [ArchiveEntry]? = nil
	
	override var nibName: NSNib.Name? {
		return NSNib.Name("ArchiveController")
	}
	
	override func viewDidLoad() {
		metaInfo.stringValue = ""
		// otherwise search field will overlap checkbox after width <0
		searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
		outline.setDraggingSourceOperationMask(.copy, forLocal: false)
	}
	
	// Use these two to disable initial focus of search field
	
//	override func viewWillAppear() {
//		searchField.refusesFirstResponder = true
//	}
	
//	override func viewDidAppear() {
//		searchField.refusesFirstResponder = false
//	}
	
	
	// MARK: - Key-Value Observer
	
	private var kvo: NSKeyValueObservation?
	
	override func viewWillAppear() {
		kvo = checkboxDirs.observe(\.state) { _, _ in
			self.applyFilter()
		}
	}
	
	override func viewDidDisappear() {
		kvo?.invalidate()
	}
	
	
	// MARK: - Load data
	
	@discardableResult func load(_ url: URL) -> Bool {
		fileURL = nil
		data = []
		do {
			let archive = try LibArchive(url)
			for entry in archive {
				data.append(entry)
			}
			fileURL = url
			updateMetaInfo(archive)
			outline.reloadData()
			applySort() // apply previous sort & filter
			return true
		} catch {
			self.view = errorView
			errorText.stringValue = "ERROR: " + error.localizedDescription
			return false
		}
	}
	
	func updateMetaInfo(_ archive: LibArchive) {
		var txt = Formatter.bytes(archive.compressedSize) + " / " + Formatter.bytes(archive.uncompressedSize)
		if archive.uncompressedSize > 0 {
			let ratio = 1 - Float(archive.compressedSize) / Float(archive.uncompressedSize)
			let percent = Int(ratio * 1000) / 10
			txt += " (\(percent)%)"
		}
		metaInfo.stringValue = "\(txt) — \(archive.count) items"
		// fit min size
		var fitted = metaInfo.frame
		fitted.size.width = metaInfo.fittingSize.width
		fitted.origin.x = metaInfo.frame.maxX - fitted.width // right-aligned on previous frame
		metaInfo.frame = fitted
		// use max-width for other elements
		configBackground.frame.size.width = fitted.minX - 8
	}
	
	
	// MARK: - Outline View
	
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		filter?.count ?? data.count
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		filter?[index] ?? data[index]
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		false
	}
	
	func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		applySort()
	}
	
	func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
		guard let cell = cell as? NSCell, let obj = item as? ArchiveEntry  else {
			return
		}
		switch tableColumn?.identifier {
		case NSUserInterfaceItemIdentifier(rawValue: "icon"):
			switch obj.filetype {
			case .RegularFile:
				cell.image = NSImage(named: NSImage.multipleDocumentsName)
			case .SymbolicLink:
				cell.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
			case .Directory:
				cell.image = NSImage(named: NSImage.folderName)
			default:
				cell.image = nil
			}
		case NSUserInterfaceItemIdentifier(rawValue: "path"):
			cell.stringValue = obj.path
		case NSUserInterfaceItemIdentifier(rawValue: "size"):
			cell.stringValue = Formatter.bytes(obj.size)
		case NSUserInterfaceItemIdentifier(rawValue: "flag"):
			cell.stringValue = obj.perm.str
		case NSUserInterfaceItemIdentifier(rawValue: "date"):
			cell.stringValue = Formatter.date(obj.modified)
		default: break
		}
	}
	
	func applySort() {
		data.sort(with: outline.sortDescriptors)
		applyFilter()
	}
	
	
	// MARK: - Search
	
	var searchTimer: Timer?
	
	@IBAction func didSearch(_ sender: NSSearchField) {
		let debounce = sender.stringValue.isEmpty ? 0.02 : 0.2
		searchTimer?.invalidate()
		searchTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
			self?.applyFilter()
		}
	}
	
	// CMD + F to search
	override func keyDown(with event: NSEvent) {
		if event.characters == "f", event.modifierFlags.contains(.command), !searchField.isHidden {
			searchField.becomeFirstResponder()
		} else {
			super.keyDown(with: event)
		}
	}
	
	// ESC inside search field / any NSView
	override func cancelOperation(_ sender: Any?) {
		self.view.window?.performSelector(onMainThread: #selector(NSWindow.makeFirstResponder(_:)), with: self.outline, waitUntilDone: false)
	}
	
	
	// MARK: - Filter
	
	@IBAction func checkboxToggleDirs(_ sender: NSButton) {
		applyFilter()
	}
	
	func applyFilter() {
		switch (searchField.stringValue, checkboxDirs.state == .off) {
		case ("", false): filter = nil
		case ("", true): filter = data.filter { $0.filetype != .Directory }
		case (let term, false): filter = data.filter { $0.path.contains(term) }
		case (let term, true): filter = data.filter { $0.path.contains(term) && $0.filetype != .Directory }
		}
		outline.reloadData()
	}
}


// MARK: - Sorting

extension Array<ArchiveEntry> {
	@discardableResult
	mutating func sort(with sortDescriptors: [NSSortDescriptor]) -> Bool {
		if #available(macOS 12.0, *) {
			let comp = keyPathComperators(from: sortDescriptors)
			if !comp.isEmpty {
				self.sort(using: comp)
			}
			return !comp.isEmpty
		} else {
			return sortUsingFunction(with: sortDescriptors)
		}
	}
	
	@available(macOS 12.0, *)
	private func keyPathComperators(from sortDescriptors: [NSSortDescriptor]) -> [KeyPathComparator<ArchiveEntry>] {
		sortDescriptors.map {
			let order = $0.ascending ? SortOrder.forward : .reverse
			return switch $0.key {
			case "path": KeyPathComparator(\ArchiveEntry.path, order: order)
			case "date": KeyPathComparator(\ArchiveEntry.modified, order: order)
			case "size": KeyPathComparator(\ArchiveEntry.size, order: order)
			case "flag": KeyPathComparator(\ArchiveEntry.perm.raw, order: order)
			default: KeyPathComparator(\ArchiveEntry.index, order: .forward) // always ascending
			}
		}
	}
	
	private mutating func sortUsingFunction(with sortDescriptors: [NSSortDescriptor]) -> Bool {
		let comperators = sortDescriptors.map { ($0.key, $0.ascending) }
		if comperators.isEmpty {
			return false
		}
		self.sort { lhs, rhs in
			for (key, asc) in comperators {
				switch key {
				case "path":
					if lhs.path != rhs.path {
						return asc ? lhs.path < rhs.path : lhs.path > rhs.path
					}
				case "date":
					if lhs.modified != rhs.modified {
						return asc ? lhs.modified < rhs.modified : lhs.modified > rhs.modified
					}
				case "size":
					if lhs.size != rhs.size {
						return asc ? lhs.size < rhs.size : lhs.size > rhs.size
					}
				case "flag":
					if lhs.perm.raw != rhs.perm.raw {
						return asc ? lhs.perm.raw < rhs.perm.raw : lhs.perm.raw > rhs.perm.raw
					}
				default:
					if lhs.index != rhs.index {
						return lhs.index < rhs.index // always ascending
					}
				}
			}
			return false
		}
		return true
	}
}


// MARK: - Drag to extract

extension ArchiveController: NSFilePromiseProviderDelegate {
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
	
	func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
		if (item as? ArchiveEntry)?.filetype == .Directory {
			return nil
		}
		let provider = NSFilePromiseProvider(fileType: "public.data", delegate: self)
		provider.userInfo = item
		return provider
	}
}


// MARK: - Formatter

private struct Formatter {
	private static let fmtDate: DateFormatter = {
		let x = DateFormatter()
		x.dateFormat = "yyyy-MM-dd  HH:mm:ss"
		return x
	}()
	
	/// Human readable date formatter
	static func date(_ time: time_t) -> String {
		Self.fmtDate.string(from: Date(timeIntervalSince1970: TimeInterval(time)))
	}
	
	/// Human readable bytes formatter
	static func bytes(_ size: Int64) -> String {
		if size < 0 {
			"--"
		} else if size < 1024 {
			"\(size) B"
		} else {
			ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
		}
	}
}
