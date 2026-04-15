import AppKit

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

// MARK: - Sorted insert

extension RangeReplaceableCollection {
	/// Binary search insert in already sorted collection.
	mutating func insertSorted<T: Comparable>(_ value: Element, by predicate: KeyPath<Element, T>) {
		let needle = value[keyPath: predicate]
		var slice : SubSequence = self[...]
		while !slice.isEmpty {
			let middle = slice.index(
				slice.startIndex,
				offsetBy: slice.count / 2
			)
			if needle > slice[middle][keyPath: predicate] {
				slice = slice[index(after: middle)...]
			} else {
				slice = slice[..<middle]
			}
		}
		self.insert(value, at: slice.startIndex)
	}
}
