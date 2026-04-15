import AppKit

// Code to display cells and formatted meta info

// TODO: disable Spelling & Grammar menu item on editing path cell (but how??)

extension LibArchive {
	/// Generate info text for archive meta data (entry count, compression ratio, etc.)
	/// @Note Only valid after all entries have been processed.
	func metaInfo() -> String {
		var txt = Formatter.bytes(self.compressedSize) + " / " + Formatter.bytes(self.uncompressedSize)
		if self.uncompressedSize > 0 {
			let ratio = 1 - Float(self.compressedSize) / Float(self.uncompressedSize)
			let percent = Int(ratio * 1000) / 10
			txt += " (\(percent)%)"
		}
		return "\(txt) — \(self.count) items"
	}
}

extension ArchiveController {
	/// Cell display
	func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
		guard let cell = cell as? NSCell else {
			return
		}
		let node = (item as? TreeNode)
		let fake = node?.isFake == true
		// Archive entry fields
		let entry = dataSource.rowEntry(item)
		switch tableColumn?.identifier {
		case NSUserInterfaceItemIdentifier(rawValue: "icon"):
			if fake { break }
			// TODO: should non-archive folders get a folder icon?
			// TODO: should folder icons be shown in TreeView mode?
			switch entry.filetype {
			case .RegularFile:  cell.image = NSImage.file
			case .SymbolicLink: cell.image = NSImage.link
			case .Directory:    cell.image = NSImage(named: NSImage.folderName)
			default:            cell.image = nil
			}
		case NSUserInterfaceItemIdentifier(rawValue: "path"):
			cell.stringValue = node?.name ?? entry.path
			if resolveSymlinks, entry.filetype == .SymbolicLink, let symlink = symlinkMap?[entry.index] {
				cell.stringValue += "  →  " + symlink
			}
		case NSUserInterfaceItemIdentifier(rawValue: "size"):
			if fake { break }
			cell.stringValue = Formatter.bytes(entry.size)
		case NSUserInterfaceItemIdentifier(rawValue: "flag"):
			if fake { break }
			cell.stringValue = entry.perm.str
		case NSUserInterfaceItemIdentifier(rawValue: "date"):
			if fake { break }
			cell.stringValue = Formatter.date(entry.modified)
		default: break
		}
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
		fmtDate.string(from: Date(timeIntervalSince1970: TimeInterval(time)))
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
