import AppKit

// Allow user to filter rows by selecting specific types (directory, file, link)

struct TypeFilter: OptionSet {
	let rawValue: Int
	
	static let folder = Self(rawValue: 1)
	static let file   = Self(rawValue: 2)
	static let link   = Self(rawValue: 4)
	
	// no need to filter if none or all types are selected
	var isOn: Bool { rawValue > 0 && rawValue < 7 }
	
	/// Convert `TypeFilter` to archive specific `Filetype`
	func asFiletype() ->  Set<Filetype>? {
		guard isOn else {
			return nil
		}
		var rv = Set<Filetype>()
		if contains(.folder) { rv.formUnion(Filetype.dirs) }
		if contains(.file) { rv.formUnion(Filetype.files) }
		if contains(.link) { rv.formUnion(Filetype.links) }
		return rv
	}
}

// All components must have tag > 0 + tags must be bitwise exclusive
extension NSSegmentedControl {
	var selectedTypeFilter: TypeFilter {
		TypeFilter(rawValue: (0..<self.segmentCount).reduce(0) {
			$0 + (self.isSelected(forSegment: $1) ? self.tag(forSegment: $1) : 0)
		})
	}
}

extension ArchiveController {
	/// Called when user clicks on any of the type toggles.
	@IBAction func toggleFilter(_ sender: NSSegmentedControl) {
		applyFilter()
		performFilterAndReload()
	}
	
	/// `true` if search field has content
	var filterActive: Bool { cfgFilter.selectedTypeFilter.isOn }
	
	/// Does __not__ reload data.
	func applyFilter() {
		if let filtr = cfgFilter.selectedTypeFilter.asFiletype() {
			rows.forEach { $0.matchFilter = filtr.contains($0.entry.filetype) }
		}
	}
}
