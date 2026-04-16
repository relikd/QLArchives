import AppKit

// Code to display cells and formatted meta info

// TODO: disable Spelling & Grammar menu item on editing path cell (but how??)

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
