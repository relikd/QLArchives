import AppKit

// Extensions on Segmented Control

// MARK: - View Mode

enum ViewMode {
	case list, tree
}

extension NSSegmentedControl {
	var selectedViewMode: ViewMode {
		self.selectedSegment == 1 ? .tree : .list
	}
	func select(_ viewMode: ViewMode) {
		self.setSelected(true, forSegment: viewMode == .tree ? 1 : 0)
	}
}


// MARK: - Expand Nodes

enum ExpandAction: Int {
	case expand = 0
	case collapse = 1
}

extension NSSegmentedControl {
	func set(_ action: ExpandAction, enabled: Bool) {
		setEnabled(enabled, forSegment: action == .collapse ? 1 : 0)
	}
}


// MARK: - Filetype Filter

struct FiletypeFilter: OptionSet {
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
	var selectedTypeFilter: FiletypeFilter {
		FiletypeFilter(rawValue: (0..<self.segmentCount).reduce(0) {
			$0 + (self.isSelected(forSegment: $1) ? self.tag(forSegment: $1) : 0)
		})
	}
	/// Iterate over all segments and find the one with matching tag. Then toggle its value.
	func multiSelectToggle(_ tag: Int) {
		for i in 0..<self.segmentCount {
			if self.tag(forSegment: i) == tag {
				self.setSelected(!self.isSelected(forSegment: i), forSegment: i)
				return
			}
		}
	}
}
