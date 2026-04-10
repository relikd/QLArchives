import AppKit

// Allow user to filter rows by selecting specific types (directory, file, link)

extension ArchiveController {
	/// Called when user clicks on any of the type toggles.
	@IBAction func toggleFilter(_ sender: NSSegmentedControl) {
		applyFilter()
	}
	
	/// Triggered on: load, filter, search, sort
	func applyFilter() {
		switch (searchField.stringValue, cfgFilter.selectedTypeFilter.asFiletype()) {
		case ("", nil): filter = nil
		case ("", let filtr): filter = data.filter { filtr!.contains($0.filetype) }
		case (let search, nil): filter = data.filter { $0.path.contains(search) }
		case (let search, let filtr): filter = data.filter { $0.path.contains(search) && filtr!.contains($0.filetype) }
		}
		outline.reloadData()
	}
}

struct TypeFilter: OptionSet {
	let rawValue: Int
	
	static let folder = Self(rawValue: 1)
	static let file   = Self(rawValue: 2)
	static let link   = Self(rawValue: 4)
	
	func asFiletype() ->  Set<Filetype>? {
		// no need to filter if all types are selected
		if rawValue == 7 {
			return nil
		}
		var rv = Set<Filetype>()
		if self.contains(.folder) { rv.formUnion(Filetype.dirs) }
		if self.contains(.file) { rv.formUnion(Filetype.files) }
		if self.contains(.link) { rv.formUnion(Filetype.links) }
		return rv.isEmpty ? nil : rv // also no filter if none is selected
	}
}

// All components must have tag > 0 + tags must be bitwise exclusive
extension NSSegmentedControl {
	var selectedTypeFilter: TypeFilter {
		get {
			TypeFilter(rawValue: (0..<self.segmentCount).reduce(0) {
				$0 + (self.isSelected(forSegment: $1) ? self.tag(forSegment: $1) : 0)
			})
		}
		set {
			for i in 0..<self.segmentCount {
				self.setSelected((self.tag(forSegment: i) & newValue.rawValue) != 0, forSegment: i)
			}
		}
	}
}
