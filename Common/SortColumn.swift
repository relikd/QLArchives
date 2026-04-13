import AppKit

// Allow user to sort rows by clicking on a column header

extension ArchiveController {
	/// Called when user clicks on a column header.
	func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
		dataSource.sortDescriptors = outline.sortDescriptors
		performFilterAndReload(restoreCollapsible: false) // count doesnt change, only order
	}
}

protocol HasArchiveEntry {
	var entry: ArchiveEntry { get }
}

extension Array where Element: HasArchiveEntry {
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
	private func keyPathComperators(from sortDescriptors: [NSSortDescriptor]) -> [KeyPathComparator<Element>] {
		sortDescriptors.map {
			let order = $0.ascending ? SortOrder.forward : .reverse
			return switch $0.key {
			case "path": KeyPathComparator(\.entry.path, order: order)
			case "date": KeyPathComparator(\.entry.modified, order: order)
			case "size": KeyPathComparator(\.entry.size, order: order)
			case "flag": KeyPathComparator(\.entry.perm.raw, order: order)
			default: KeyPathComparator(\.entry.index, order: .forward) // always ascending
			}
		}
	}
	
	private mutating func sortUsingFunction(with sortDescriptors: [NSSortDescriptor]) -> Bool {
		let comperators = sortDescriptors.map { ($0.key, $0.ascending) }
		if comperators.isEmpty {
			return false
		}
		self.sort {
			let lhs = $0.entry
			let rhs = $1.entry
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
