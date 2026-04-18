import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
	func applicationDidFinishLaunching(_ aNotification: Notification) {}
	
	func applicationWillTerminate(_ aNotification: Notification) {}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
	
	@IBAction func showLibarchiveVersion(_ sender: Any?) {
		let alert = NSAlert()
		alert.messageText = LibArchive.version()
		alert.runModal()
	}
	
	// MARK: Auto-enable menu items
	
	func topMostDocument() -> ArchiveController? {
		NSApplication.shared.orderedDocuments.first?.windowForSheet?.contentViewController as? ArchiveController
	}
	
	func menuNeedsUpdate(_ menu: NSMenu) {
		guard let doc = topMostDocument() else {
			return
		}
		switch menu.identifier {
		case NSUserInterfaceItemIdentifier("view-menu"):
			menu.item(withTag: 304)?.state = doc.resolveSymlinks ? .on : .off
			
		case NSUserInterfaceItemIdentifier("list-view-menu"):
			let isList = doc.viewMode == .list
			let seg = doc.cfgFilter!
			for i in 0..<seg.segmentCount {
				let item = menu.item(withTag: seg.tag(forSegment: i))
				item?.state = seg.isSelected(forSegment: i) ? .on : .off
				item?.isEnabled = isList
			}
			
		case NSUserInterfaceItemIdentifier("tree-view-menu"):
			let isTree = doc.viewMode == .tree
			let seg = doc.cfgTreeExpand!
			for i in 0..<seg.segmentCount {
				let item = menu.item(withTag: seg.tag(forSegment: i))
				item?.isEnabled = isTree && seg.isEnabled(forSegment: i)
			}
		default: return
		}
	}
}

